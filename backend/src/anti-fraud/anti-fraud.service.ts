import { ForbiddenException, Injectable } from '@nestjs/common';
import { MessageRiskStatus } from '@prisma/client';
import { PrismaService } from '../database/prisma/prisma.service';
import { runtimeObservability } from '../common/observability/runtime-observability';

type RiskSignal = {
  key: string;
  severity: 'low' | 'medium' | 'high';
  evidence: Record<string, unknown>;
};

@Injectable()
export class AntiFraudService {
  constructor(private readonly prisma: PrismaService) {}

  private phoneRegex = /(?:\+?\d[\d\s-]{6,}\d)/g;
  private emailRegex = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;
  private linkRegex = /(https?:\/\/\S+|www\.\S+)/gi;
  private directContactRegex = /(whatsapp|telegram|llámame|llamame|escríbeme|escribeme|pásame tu número|pasame tu numero|te escribo aparte|mejor por fuera)/gi;

  analyzeMessage(body: string) {
    const flags: string[] = [];

    const containsPhone = this.phoneRegex.test(body);
    const containsEmail = this.emailRegex.test(body);
    const containsExternalLink = this.linkRegex.test(body);
    const containsDirectContactIntent = this.directContactRegex.test(body);

    if (containsPhone) flags.push('phone_shared');
    if (containsEmail) flags.push('email_shared');
    if (containsExternalLink) flags.push('external_link_shared');
    if (containsDirectContactIntent) flags.push('direct_contact_intent');

    let sanitizedBody = body
      .replace(this.phoneRegex, '[contacto oculto]')
      .replace(this.emailRegex, '[email oculto]')
      .replace(this.linkRegex, '[link oculto]');

    const riskStatus = flags.length > 0 ? MessageRiskStatus.flagged : MessageRiskStatus.clean;

    if (flags.includes('direct_contact_intent') && flags.length >= 2) {
      sanitizedBody = '[mensaje bloqueado por posible intento de sacar la conversación fuera de iway]';
    }

    return {
      sanitizedBody,
      riskStatus,
      flags,
      containsPhone,
      containsEmail,
      containsExternalLink,
      containsDirectContactIntent,
    };
  }

  async createFlags(params: {
    userId?: string;
    shipmentId?: string;
    messageId?: string;
    flags: string[];
  }) {
    if (params.flags.length === 0) {
      return;
    }

    await this.prisma.antiFraudFlag.createMany({
      data: params.flags.map((flagType) => ({
        userId: params.userId,
        shipmentId: params.shipmentId,
        messageId: params.messageId,
        flagType,
        severity: flagType === 'direct_contact_intent' ? 'high' : 'medium',
      })),
    });
  }

  private async createAutoFlagIfMissing(params: {
    userId: string;
    flagType: string;
    severity: 'low' | 'medium' | 'high';
    details: Record<string, unknown>;
  }) {
    const existing = await this.prisma.antiFraudFlag.findFirst({
      where: {
        userId: params.userId,
        flagType: params.flagType,
      },
      orderBy: { createdAt: 'desc' },
    });

    const existingSource = existing?.details as Record<string, unknown> | null | undefined;
    if (existing && existingSource?.source === 'auto_risk_scan') {
      return existing;
    }

    return this.prisma.antiFraudFlag.create({
      data: {
        userId: params.userId,
        flagType: params.flagType,
        severity: params.severity,
        details: {
          ...params.details,
          source: 'auto_risk_scan',
        },
      },
    });
  }

  async buildUserRiskSignals(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { travelerProfile: true },
    });

    if (!user) {
      throw new ForbiddenException('Usuario no encontrado.');
    }

    const now = Date.now();
    const last24h = new Date(now - 24 * 60 * 60 * 1000);
    const last7d = new Date(now - 7 * 24 * 60 * 60 * 1000);

    const [
      duplicateDocumentCount,
      shipmentsLast24h,
      offersLast24h,
      transfersLast7d,
      flaggedMessagesLast7d,
      activeDeviceCount,
      existingFlags,
    ] = await Promise.all([
      user.travelerProfile?.dpiOrPassport
        ? this.prisma.travelerProfile.count({
            where: {
              dpiOrPassport: user.travelerProfile.dpiOrPassport,
              userId: { not: userId },
            },
          })
        : Promise.resolve(0),
      this.prisma.shipment.count({ where: { customerId: userId, createdAt: { gte: last24h } } }),
      this.prisma.offer.count({ where: { travelerId: userId, createdAt: { gte: last24h } } }),
      this.prisma.transferPayment.count({ where: { travelerId: userId, createdAt: { gte: last7d } } }),
      this.prisma.message.count({
        where: {
          senderId: userId,
          riskStatus: { not: MessageRiskStatus.clean },
          createdAt: { gte: last7d },
        },
      }),
      this.prisma.deviceToken.count({ where: { userId, active: true } }),
      this.prisma.antiFraudFlag.findMany({ where: { userId }, orderBy: { createdAt: 'desc' }, take: 50 }),
    ]);

    const signals: RiskSignal[] = [];

    if (duplicateDocumentCount > 0) {
      signals.push({
        key: 'duplicate_document_number',
        severity: 'high',
        evidence: { duplicateDocumentCount, documentNumber: user.travelerProfile?.dpiOrPassport ?? null },
      });
    }

    if (
      user.countryCode &&
      user.detectedCountryCode &&
      user.countryCode.toUpperCase() != user.detectedCountryCode.toUpperCase()
    ) {
      signals.push({
        key: 'country_mismatch',
        severity: 'medium',
        evidence: { countryCode: user.countryCode, detectedCountryCode: user.detectedCountryCode },
      });
    }

    if (shipmentsLast24h >= 5 || offersLast24h >= 10) {
      signals.push({
        key: 'high_activity_velocity',
        severity: shipmentsLast24h >= 8 || offersLast24h >= 16 ? 'high' : 'medium',
        evidence: { shipmentsLast24h, offersLast24h },
      });
    }

    if (transfersLast7d >= 4) {
      signals.push({
        key: 'transfer_velocity_spike',
        severity: transfersLast7d >= 7 ? 'high' : 'medium',
        evidence: { transfersLast7d },
      });
    }

    if (flaggedMessagesLast7d >= 3) {
      signals.push({
        key: 'flagged_chat_pattern',
        severity: flaggedMessagesLast7d >= 6 ? 'high' : 'medium',
        evidence: { flaggedMessagesLast7d },
      });
    }

    if (activeDeviceCount >= 5) {
      signals.push({
        key: 'device_spread',
        severity: activeDeviceCount >= 8 ? 'high' : 'medium',
        evidence: { activeDeviceCount },
      });
    }

    for (const signal of signals) {
      await this.createAutoFlagIfMissing({
        userId,
        flagType: signal.key,
        severity: signal.severity,
        details: signal.evidence,
      });
    }

    const highSignals = signals.filter((signal) => signal.severity === 'high').length;
    const mediumSignals = signals.filter((signal) => signal.severity === 'medium').length;
    const lowSignals = signals.filter((signal) => signal.severity === 'low').length;

    const existingHigh = existingFlags.filter((flag) => flag.severity === 'high').length;
    const existingMedium = existingFlags.filter((flag) => flag.severity === 'medium').length;
    const existingLow = existingFlags.filter((flag) => flag.severity === 'low').length;

    let riskScore = 100;
    riskScore -= (existingHigh + highSignals) * 28;
    riskScore -= (existingMedium + mediumSignals) * 11;
    riskScore -= (existingLow + lowSignals) * 4;
    riskScore = Math.max(0, Math.min(100, riskScore));

    const recommendedRiskLevel =
      existingHigh + highSignals > 0 ? 'high' : existingMedium + mediumSignals >= 3 ? 'medium' : 'low';
    const recommendedAction =
      recommendedRiskLevel == 'high'
        ? 'manual_block_review'
        : recommendedRiskLevel == 'medium'
          ? 'manual_review'
          : 'allow_monitoring';

    runtimeObservability.recordBusinessEvent({
      type: 'anti_fraud_scan',
      actorId: userId,
      metadata: { recommendedRiskLevel, recommendedAction, riskScore },
    });

    return {
      riskScore,
      recommendedRiskLevel,
      recommendedAction,
      signals,
    };
  }

  async getUserRiskSummary(userId: string) {
    const signalSummary = await this.buildUserRiskSignals(userId);
    const flags = await this.prisma.antiFraudFlag.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    const high = flags.filter((flag) => flag.severity === 'high').length;
    const medium = flags.filter((flag) => flag.severity === 'medium').length;
    const low = flags.filter((flag) => flag.severity === 'low').length;

    return {
      total: flags.length,
      high,
      medium,
      low,
      riskScore: signalSummary.riskScore,
      signals: signalSummary.signals,
      recentFlags: flags,
      recommendedRiskLevel: signalSummary.recommendedRiskLevel,
      recommendedAction: signalSummary.recommendedAction,
    };
  }

  async listReviewQueue(requester: { sub: string; role: string }) {
    if (!['admin', 'support'].includes(requester.role)) {
      throw new ForbiddenException('Solo admin o soporte puede ver la cola antifraude.');
    }

    const users = await this.prisma.user.findMany({
      where: { role: 'traveler' },
      include: { travelerProfile: true },
      orderBy: { createdAt: 'desc' },
      take: 80,
    });

    const queue = await Promise.all(
      users.map(async (user) => ({
        userId: user.id,
        fullName: user.fullName,
        email: user.email,
        travelerStatus: user.travelerProfile?.status ?? null,
        summary: await this.getUserRiskSummary(user.id),
      })),
    );

    return queue
      .filter((item) => item.summary.recommendedRiskLevel !== 'low' || item.summary.total > 0)
      .sort((a, b) => a.summary.riskScore - b.summary.riskScore);
  }

  async createManualFlag(params: {
    userId: string;
    actorId?: string;
    flagType: string;
    severity: 'low' | 'medium' | 'high';
    details?: Record<string, unknown>;
  }) {
    const created = await this.prisma.antiFraudFlag.create({
      data: {
        userId: params.userId,
        flagType: params.flagType,
        severity: params.severity,
        details: {
          ...(params.details ?? {}),
          actorId: params.actorId ?? null,
          source: 'manual_review',
        },
      },
    });

    runtimeObservability.recordBusinessEvent({
      type: 'manual_fraud_flag',
      actorId: params.actorId,
      metadata: { userId: params.userId, flagType: params.flagType, severity: params.severity },
    });

    return created;
  }

  getRules() {
    return {
      protectedContactData: true,
      scansChatForPhones: true,
      scansChatForEmails: true,
      scansChatForLinks: true,
      scansDirectContactIntent: true,
      autoFlagsSuspiciousMessages: true,
      autoScansDuplicateDocuments: true,
      autoScansVelocitySpikes: true,
      autoScansCountryMismatch: true,
      autoScansDeviceSpread: true,
      masksSensitiveData: true,
    };
  }
}
