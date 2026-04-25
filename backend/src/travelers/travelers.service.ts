import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import {
  KycCheckKind,
  KycCheckStatus,
  KycTier,
  ShipmentDirection,
  TravelerStatus,
  TravelerType,
  UserRole,
  UserStatus,
} from '@prisma/client';
import { PrismaService } from '../database/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateTravelerProfileDto } from './dto/create-traveler-profile.dto';
import { RegisterTravelerDto } from './dto/register-traveler.dto';
import { runtimeObservability } from '../common/observability/runtime-observability';

@Injectable()
export class TravelersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

  private readonly workspaceEntityType = 'traveler_workspace';
  private readonly workspaceAction = 'traveler_workspace_updated';
  private readonly routeAnnouncementEntityType = 'traveler_route_announcement';
  private readonly routeAnnouncementAction = 'traveler_route_announcement_published';

  private normalizeDecimal(value: unknown) {
    const parsed = Number(value ?? 0);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  getAllowedDirectionsByType(travelerType: TravelerType) {
    switch (travelerType) {
      case TravelerType.avion_ida_vuelta:
        return [ShipmentDirection.gt_to_us, ShipmentDirection.us_to_gt];
      case TravelerType.avion_tierra:
        return [ShipmentDirection.gt_to_us, ShipmentDirection.us_to_gt];
      case TravelerType.solo_tierra:
        return [ShipmentDirection.us_to_gt];
    }
  }

  private normalizeRoutes(routes: unknown): string[] {
    if (!Array.isArray(routes)) {
      return [];
    }

    return [...new Set(
      routes
        .map((item) => item?.toString().trim())
        .filter((item): item is string => Boolean(item && item.length > 0)),
    )];
  }

  private normalizeTags(value: unknown): string[] {
    if (Array.isArray(value)) {
      return [...new Set(
        value
          .map((item) => item?.toString().trim())
          .filter((item): item is string => Boolean(item && item.length > 0)),
      )];
    }

    if (typeof value === 'string') {
      return [...new Set(
        value
          .split(/[\n,|/]+/)
          .map((item) => item.trim())
          .filter((item) => item.length > 0),
      )];
    }

    return [];
  }

  async getWorkspace(userId: string, requester: { sub: string; role: string }) {
    if (requester.sub !== userId && !['admin', 'support'].includes(requester.role)) {
      throw new ForbiddenException('No tienes acceso a esta configuración de trabajo.');
    }

    const traveler = await this.prisma.travelerProfile.findUnique({
      where: { userId },
      select: { userId: true },
    });

    if (!traveler) {
      throw new NotFoundException('Perfil de viajero no encontrado.');
    }

    const latestWorkspace = await this.prisma.auditLog.findFirst({
      where: {
        entityType: this.workspaceEntityType,
        entityId: userId,
        action: this.workspaceAction,
      },
      orderBy: { createdAt: 'desc' },
    });

    const payload = latestWorkspace?.payload as Record<string, unknown> | null | undefined;
    return {
      isOnline: payload?.isOnline !== false,
      routes: this.normalizeRoutes(payload?.routes),
      updatedAt: latestWorkspace?.createdAt ?? null,
    };
  }

  async updateWorkspace(
    userId: string,
    payload: { isOnline?: boolean; routes?: string[] },
    requester: { sub: string; role: string },
  ) {
    if (requester.sub !== userId && !['admin', 'support'].includes(requester.role)) {
      throw new ForbiddenException('No tienes acceso a esta configuración de trabajo.');
    }

    const current = await this.getWorkspace(userId, requester);
    const next: { isOnline: boolean; routes: string[] } = {
      isOnline: payload.isOnline ?? current.isOnline,
      routes: payload.routes != null ? this.normalizeRoutes(payload.routes) : current.routes,
    };

    await this.prisma.auditLog.create({
      data: {
        actorId: requester.sub,
        entityType: this.workspaceEntityType,
        entityId: userId,
        action: this.workspaceAction,
        payload: next,
      },
    });

    return {
      ...next,
      updatedAt: new Date(),
    };
  }

  async getLatestRouteAnnouncement(userId: string, requester: { sub: string; role: string }) {
    if (requester.sub !== userId && !['admin', 'support'].includes(requester.role)) {
      throw new ForbiddenException('No tienes acceso a este anuncio.');
    }

    const latestAnnouncement = await this.prisma.auditLog.findFirst({
      where: {
        actorId: userId,
        entityType: this.routeAnnouncementEntityType,
        action: this.routeAnnouncementAction,
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!latestAnnouncement) {
      return null;
    }

    const payload = latestAnnouncement.payload as Record<string, unknown> | null | undefined;
    return {
      message: payload?.message?.toString() ?? '',
      allowedProducts: this.normalizeTags(payload?.allowedProducts),
      regions: this.normalizeTags(payload?.regions),
      createdAt: latestAnnouncement.createdAt,
      recipientCount: Number(payload?.recipientCount ?? 0),
    };
  }

  async publishRouteAnnouncement(
    userId: string,
    payload: { message?: string; allowedProducts?: string[] | string; regions?: string[] | string },
    requester: { sub: string; role: string },
  ) {
    if (requester.sub !== userId && !['admin', 'support'].includes(requester.role)) {
      throw new ForbiddenException('No puedes publicar este anuncio.');
    }

    const traveler = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        role: true,
        fullName: true,
      },
    });

    if (!traveler || traveler.role !== UserRole.traveler) {
      throw new NotFoundException('Viajero no encontrado.');
    }

    const message = payload.message?.toString().trim() ?? '';
    const allowedProducts = this.normalizeTags(payload.allowedProducts);
    const regions = this.normalizeTags(payload.regions);

    if (!message) {
      throw new BadRequestException('El mensaje del anuncio es obligatorio.');
    }

    if (allowedProducts.length === 0) {
      throw new BadRequestException('Debes indicar qué productos estás recibiendo.');
    }

    const customers = await this.prisma.user.findMany({
      where: {
        role: UserRole.customer,
        status: UserStatus.active,
        ...(regions.length > 0
          ? {
              OR: regions.flatMap((region) => ([
                { stateRegion: { contains: region, mode: 'insensitive' } },
                { city: { contains: region, mode: 'insensitive' } },
              ])),
            }
          : {}),
      },
      select: { id: true },
    });

    await this.prisma.auditLog.create({
      data: {
        actorId: requester.sub,
        entityType: this.routeAnnouncementEntityType,
        entityId: userId,
        action: this.routeAnnouncementAction,
        payload: {
          message,
          allowedProducts,
          regions,
          recipientCount: customers.length,
        },
      },
    });

    await this.notificationsService.sendPushMany(
      customers.map((customer) => customer.id),
      'Ruta anunciada',
      `${traveler.fullName} viajará pronto: ${message}. ¡Crea tu envío ahora!`,
      'traveler_route_announcement',
    );

    return {
      message,
      allowedProducts,
      regions,
      recipientCount: customers.length,
    };
  }

  async createTravelerProfile(payload: CreateTravelerProfileDto) {
    const directions = this.getAllowedDirectionsByType(payload.travelerType);

    const profile = await this.prisma.travelerProfile.create({
      data: {
        userId: payload.userId,
        travelerType: payload.travelerType,
        status: TravelerStatus.pending,
        dpiOrPassport: payload.documentNumber,
        documentUrl: payload.documentUrl,
        selfieUrl: payload.selfieUrl,
        routes: {
          create: directions.map((direction) => ({ direction })),
        },
      },
      include: {
        routes: true,
      },
    });

    await this.runKycAnalysis(payload.userId, { sub: payload.userId, role: 'traveler' });
    const summary = await this.getVerificationSummary(payload.userId, {
      sub: payload.userId,
      role: 'traveler',
    });

    await this.prisma.travelerProfile.update({
      where: { userId: payload.userId },
      data: {
        verificationScore: summary.score,
        trustScore: summary.trustScore,
        payoutHoldEnabled: summary.payoutHoldRecommended,
        kycTier: summary.suggestedKycTier as KycTier,
      },
    });

    return profile;
  }

  async getVerificationSummary(userId: string, requester: { sub: string; role: string }) {
    if (requester.sub !== userId && !['admin', 'support'].includes(requester.role)) {
      throw new ForbiddenException('No tienes acceso a esta verificación.');
    }

    const traveler = await this.prisma.travelerProfile.findUnique({
      where: { userId },
      include: {
        user: true,
        routes: true,
        kycChecks: {
          orderBy: { createdAt: 'desc' },
          take: 10,
        },
      },
    });

    if (!traveler) {
      throw new NotFoundException('Perfil de viajero no encontrado.');
    }

    const [flags, files, devices] = await Promise.all([
      this.prisma.antiFraudFlag.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
      this.prisma.uploadedFile.findMany({
        where: {
          ownerId: userId,
          purpose: 'identity_verification',
        },
        orderBy: { createdAt: 'desc' },
        take: 10,
      }),
      this.prisma.deviceToken.findMany({
        where: { userId, active: true },
        orderBy: { lastSeenAt: 'desc' },
        take: 20,
      }),
    ]);

    const documentProtected = files.some((file) => file.url === traveler.documentUrl && file.isProtected);
    const selfieProtected = files.some((file) => file.url === traveler.selfieUrl && file.isProtected);
    const latestKycChecks = traveler.kycChecks;
    const passedKycChecks = latestKycChecks.filter((check) => check.status === KycCheckStatus.passed).length;
    const failedKycChecks = latestKycChecks.filter((check) => check.status === KycCheckStatus.failed).length;
    const accountAgeHours = (Date.now() - traveler.user.createdAt.getTime()) / 3600000;
    const averageDeviceTrust = devices.length > 0
      ? Math.round(devices.reduce((acc, item) => acc + (item.trustScore ?? 0), 0) / devices.length)
      : 0;
    const suspiciousDeviceCount = devices.filter((item) => item.suspicious).length;

    let score = 0;
    let trustScore = 0;
    const checks = [
      { key: 'document_uploaded', passed: Boolean(traveler.documentUrl), weight: 16 },
      { key: 'selfie_uploaded', passed: Boolean(traveler.selfieUrl), weight: 14 },
      { key: 'document_protected', passed: documentProtected, weight: 10 },
      { key: 'selfie_protected', passed: selfieProtected, weight: 10 },
      { key: 'document_number_present', passed: Boolean(traveler.dpiOrPassport), weight: 10 },
      { key: 'country_detected', passed: Boolean(traveler.user.detectedCountryCode || traveler.user.countryCode), weight: 6 },
      { key: 'route_configured', passed: traveler.routes.length > 0, weight: 6 },
      { key: 'contact_complete', passed: Boolean(traveler.user.phone && traveler.user.email), weight: 8 },
      { key: 'phone_verified', passed: traveler.user.phoneVerified, weight: 8 },
      { key: 'email_verified', passed: traveler.user.emailVerified, weight: 8 },
      { key: 'trusted_device_present', passed: devices.length > 0, weight: 6 },
      { key: 'trusted_device_score', passed: averageDeviceTrust >= 70 && suspiciousDeviceCount === 0, weight: 8 },
      { key: 'account_age_mature', passed: accountAgeHours >= 72, weight: 4 },
      { key: 'no_current_debt', passed: this.normalizeDecimal(traveler.currentDebt) <= 0, weight: 4 },
      { key: 'kyc_checks_passed', passed: passedKycChecks >= 2, weight: 12 },
    ].map((check) => {
      if (check.passed) {
        score += check.weight;
        trustScore += check.weight;
      }
      return check;
    });

    const highFlags = flags.filter((flag) => flag.severity === 'high').length;
    const mediumFlags = flags.filter((flag) => flag.severity === 'medium').length;
    const lowFlags = flags.filter((flag) => flag.severity === 'low').length;

    score -= highFlags * 30;
    score -= mediumFlags * 12;
    score -= lowFlags * 5;

    trustScore -= highFlags * 26;
    trustScore -= mediumFlags * 10;
    trustScore -= lowFlags * 4;
    if (devices.length >= 5) trustScore -= 12;
    if (devices.length >= 8) trustScore -= 10;
    if (suspiciousDeviceCount > 0) trustScore -= 18;
    if (averageDeviceTrust > 0 && averageDeviceTrust < 55) trustScore -= 10;
    if (accountAgeHours < 24) trustScore -= 8;
    if (failedKycChecks > 0) score -= failedKycChecks * 10;
    if (failedKycChecks > 0) trustScore -= failedKycChecks * 8;

    score = Math.max(0, Math.min(100, score));
    trustScore = Math.max(0, Math.min(100, trustScore));

    const missingRequirements: string[] = [];
    if (!traveler.documentUrl) missingRequirements.push('Subir documento oficial');
    if (!traveler.selfieUrl) missingRequirements.push('Subir selfie de validación');
    if (!documentProtected || !selfieProtected) missingRequirements.push('Re-subir evidencia KYC protegida');
    if (!traveler.user.phoneVerified) missingRequirements.push('Verificar teléfono');
    if (!traveler.user.emailVerified) missingRequirements.push('Verificar correo');
    if (devices.length === 0) missingRequirements.push('Registrar dispositivo confiable');

    const payoutHoldRecommended =
      highFlags > 0 ||
      trustScore < 55 ||
      !traveler.documentUrl ||
      !traveler.selfieUrl ||
      !traveler.user.phoneVerified ||
      failedKycChecks > 0;

    const suggestedKycTier =
      trustScore >= 85 && highFlags === 0 && passedKycChecks >= 2
        ? KycTier.premium
        : trustScore >= 60
          ? KycTier.enhanced
          : KycTier.basic;

    const recommendedDecision = highFlags > 0
      ? 'manual_block_review'
      : failedKycChecks > 0
        ? 'reject_or_more_docs'
        : missingRequirements.length > 0 && score < 75
          ? 'reject_or_more_docs'
          : payoutHoldRecommended && score >= 55
            ? 'approve_with_hold'
            : score >= 82
              ? 'approve'
              : 'manual_review';

    return {
      userId,
      travelerProfileId: traveler.id,
      currentStatus: traveler.status,
      score,
      trustScore,
      trustLevel: trustScore >= 85 ? 'high' : trustScore >= 60 ? 'medium' : 'low',
      checks,
      flagsSummary: { high: highFlags, medium: mediumFlags, low: lowFlags, total: flags.length },
      recommendedDecision,
      blockedReason: traveler.blockedReason,
      recentFlags: flags,
      payoutHoldRecommended,
      payoutHoldEnabled: traveler.payoutHoldEnabled,
      suggestedKycTier,
      currentKycTier: traveler.kycTier,
      missingRequirements,
      nextSteps: missingRequirements.length > 0 ? missingRequirements : ['Perfil listo para revisión final'],
      deviceTrust: {
        activeDevices: devices.length,
        suspiciousDevices: suspiciousDeviceCount,
        averageTrustScore: averageDeviceTrust,
        lastSeenAt: devices[0]?.lastSeenAt ?? null,
      },
      kycAssets: {
        documentProtected,
        selfieProtected,
        filesAttached: files.length,
      },
      evidence: {
        documentUrl: traveler.documentUrl,
        selfieUrl: traveler.selfieUrl,
      },
      kycChecks: latestKycChecks,
    };
  }

  async runKycAnalysis(userId: string, requester: { sub: string; role: string }) {
    if (requester.sub !== userId && !['admin', 'support'].includes(requester.role)) {
      throw new ForbiddenException('No tienes acceso a este análisis KYC.');
    }

    const traveler = await this.prisma.travelerProfile.findUnique({
      where: { userId },
      include: { user: true },
    });

    if (!traveler) {
      throw new NotFoundException('Perfil de viajero no encontrado.');
    }

    const files = await this.prisma.uploadedFile.findMany({
      where: { ownerId: userId, purpose: 'identity_verification' },
      orderBy: { createdAt: 'desc' },
      take: 10,
    });

    const documentFile = files.find((file) => file.url === traveler.documentUrl);
    const selfieFile = files.find((file) => file.url === traveler.selfieUrl);
    const documentNumber = traveler.dpiOrPassport?.trim() ?? '';

    const checks = [
      {
        kind: KycCheckKind.document_ocr,
        status: traveler.documentUrl && documentFile?.isProtected
          ? (documentNumber && documentFile.fileName.includes(documentNumber) ? KycCheckStatus.passed : KycCheckStatus.manual_review)
          : KycCheckStatus.failed,
        confidence: traveler.documentUrl ? (documentNumber && documentFile?.fileName.includes(documentNumber) ? 82 : 58) : 15,
        summary: traveler.documentUrl
          ? documentNumber && documentFile?.fileName.includes(documentNumber)
            ? 'Documento consistente con referencia interna.'
            : 'Documento presente, pero requiere OCR o validación manual adicional.'
          : 'No hay documento para análisis.',
      },
      {
        kind: KycCheckKind.selfie_face_match,
        status: traveler.selfieUrl && traveler.documentUrl ? KycCheckStatus.manual_review : KycCheckStatus.failed,
        confidence: traveler.selfieUrl && traveler.documentUrl ? 55 : 10,
        summary: traveler.selfieUrl && traveler.documentUrl
          ? 'Assets presentes, listo para face-match provider o revisión manual.'
          : 'Falta selfie o documento para análisis biométrico.',
      },
      {
        kind: KycCheckKind.liveness_review,
        status: selfieFile?.isProtected == true ? KycCheckStatus.manual_review : KycCheckStatus.failed,
        confidence: selfieFile?.isProtected == true ? 52 : 12,
        summary: selfieFile?.isProtected == true
          ? 'Selfie protegida recibida, requiere liveness provider o revisión humana.'
          : 'No hay selfie protegida apta para liveness.',
      },
    ];

    await this.prisma.travelerKycCheck.deleteMany({ where: { travelerProfileId: traveler.id } });
    await this.prisma.travelerKycCheck.createMany({
      data: checks.map((check) => ({
        travelerProfileId: traveler.id,
        kind: check.kind,
        status: check.status,
        confidence: check.confidence,
        summary: check.summary,
        details: {
          documentProtected: documentFile?.isProtected ?? false,
          selfieProtected: selfieFile?.isProtected ?? false,
          documentFileName: documentFile?.fileName ?? null,
          selfieFileName: selfieFile?.fileName ?? null,
        },
      })),
    });

    const summary = await this.getVerificationSummary(userId, requester);

    await this.prisma.travelerProfile.update({
      where: { userId },
      data: {
        verificationScore: summary.score,
        trustScore: summary.trustScore,
        payoutHoldEnabled: summary.payoutHoldRecommended,
        kycTier: summary.suggestedKycTier as KycTier,
      },
    });

    runtimeObservability.recordBusinessEvent({
      type: 'traveler_kyc_analysis_run',
      actorId: requester.sub,
      metadata: {
        userId,
        travelerProfileId: traveler.id,
        verificationScore: summary.score,
        trustScore: summary.trustScore,
        payoutHoldRecommended: summary.payoutHoldRecommended,
      },
    });

    return summary;
  }

  async listReviewQueue(requester: { sub: string; role: string }) {
    if (!['admin', 'support'].includes(requester.role)) {
      throw new ForbiddenException('Solo admin o soporte puede ver la cola.');
    }

    const travelers = await this.prisma.travelerProfile.findMany({
      where: {
        status: { in: [TravelerStatus.pending, TravelerStatus.rejected, TravelerStatus.blocked] },
      },
      include: {
        user: true,
        routes: true,
      },
      orderBy: { createdAt: 'asc' },
      take: 100,
    });

    const results = await Promise.all(
      travelers.map(async (traveler) => ({
        userId: traveler.userId,
        travelerProfileId: traveler.id,
        fullName: traveler.user.fullName,
        email: traveler.user.email,
        status: traveler.status,
        verificationScore: traveler.verificationScore,
        trustScore: traveler.trustScore,
        payoutHoldEnabled: traveler.payoutHoldEnabled,
        kycTier: traveler.kycTier,
        summary: await this.getVerificationSummary(traveler.userId, requester),
      })),
    );

    return results.sort((a, b) => {
      const riskA = a.summary.payoutHoldRecommended ? -20 : 0;
      const riskB = b.summary.payoutHoldRecommended ? -20 : 0;
      return (a.summary.score + a.summary.trustScore + riskA) - (b.summary.score + b.summary.trustScore + riskB);
    });
  }

  async updatePayoutHold(
    userId: string,
    payload: { enabled: boolean; reason?: string },
    requester: { sub: string; role: string },
  ) {
    if (!['admin', 'support'].includes(requester.role)) {
      throw new ForbiddenException('Solo admin o soporte puede administrar holds.');
    }

    const traveler = await this.prisma.travelerProfile.findUnique({
      where: { userId },
    });

    if (!traveler) {
      throw new NotFoundException('Perfil de viajero no encontrado.');
    }

    const updated = await this.prisma.travelerProfile.update({
      where: { userId },
      data: {
        payoutHoldEnabled: payload.enabled,
        lastKycReviewAt: new Date(),
        blockedReason: payload.enabled ? payload.reason ?? traveler.blockedReason : traveler.blockedReason,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        actorId: requester.sub,
        entityType: 'traveler_profile',
        entityId: traveler.id,
        action: payload.enabled ? 'traveler_payout_hold_enabled' : 'traveler_payout_hold_disabled',
        payload: { reason: payload.reason ?? null },
      },
    });

    await this.notificationsService.sendPush(
      userId,
      payload.enabled ? 'Retención operativa activada' : 'Retención operativa liberada',
      payload.enabled
        ? `Tu cuenta quedó bajo revisión de payout${payload.reason ? `: ${payload.reason}` : '.'}`
        : 'Tu retención operativa fue liberada y puedes continuar con normalidad.',
      'traveler_payout_hold',
    );

    return updated;
  }

  async reviewTraveler(
    userId: string,
    payload: { action: 'approve' | 'reject' | 'block'; reason?: string },
    requester: { sub: string; role: string },
  ) {
    if (!['admin', 'support'].includes(requester.role)) {
      throw new ForbiddenException('Solo admin o soporte puede revisar viajeros.');
    }

    const traveler = await this.prisma.travelerProfile.findUnique({
      where: { userId },
      include: { user: true },
    });

    if (!traveler) {
      throw new NotFoundException('Perfil de viajero no encontrado.');
    }

    const summary = await this.getVerificationSummary(userId, requester);
    const nextStatus =
      payload.action === 'approve'
        ? TravelerStatus.verified
        : payload.action === 'reject'
          ? TravelerStatus.rejected
          : TravelerStatus.blocked;

    const updated = await this.prisma.travelerProfile.update({
      where: { userId },
      data: {
        status: nextStatus,
        verificationScore: summary.score,
        trustScore: summary.trustScore,
        payoutHoldEnabled: payload.action === 'approve' ? summary.payoutHoldRecommended : true,
        kycTier: summary.suggestedKycTier as KycTier,
        lastKycReviewAt: new Date(),
        blockedReason: payload.action === 'approve' ? null : payload.reason ?? traveler.blockedReason,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        actorId: requester.sub,
        entityType: 'traveler_profile',
        entityId: traveler.id,
        action: `traveler_review_${payload.action}`,
        payload: {
          reason: payload.reason ?? null,
          verificationScore: summary.score,
          trustScore: summary.trustScore,
          payoutHoldRecommended: summary.payoutHoldRecommended,
          suggestedKycTier: summary.suggestedKycTier,
          recommendedDecision: summary.recommendedDecision,
        },
      },
    });

    await this.notificationsService.sendPush(
      userId,
      payload.action === 'approve' ? 'Perfil verificado' : payload.action === 'reject' ? 'Verificación rechazada' : 'Cuenta bloqueada',
      payload.action === 'approve'
        ? summary.payoutHoldRecommended
          ? 'Tu perfil fue aprobado con monitoreo reforzado y retención operativa temporal de payouts.'
          : 'Tu perfil de viajero fue verificado y ya puede operar con normalidad.'
        : payload.action === 'reject'
          ? `Tu perfil necesita revisión adicional${payload.reason ? `: ${payload.reason}` : '.'}`
          : `Tu cuenta fue bloqueada preventivamente${payload.reason ? `: ${payload.reason}` : '.'}`,
      'traveler_verification',
    );

    runtimeObservability.recordBusinessEvent({
      type: `traveler_review_${payload.action}`,
      entityId: traveler.id,
      actorId: requester.sub,
      metadata: {
        userId,
        verificationScore: summary.score,
        trustScore: summary.trustScore,
        payoutHoldRecommended: summary.payoutHoldRecommended,
        suggestedKycTier: summary.suggestedKycTier,
        recommendedDecision: summary.recommendedDecision,
      },
    });

    return {
      traveler: updated,
      summary,
    };
  }

  register(payload: RegisterTravelerDto) {
    return {
      message: 'Use auth/register/traveler for the full flow',
      travelerType: payload.travelerType,
      detectedCountryCode: payload.detectedCountryCode,
    };
  }
}
