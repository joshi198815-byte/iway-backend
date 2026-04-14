"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.TravelersService = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const prisma_service_1 = require("../database/prisma/prisma.service");
const notifications_service_1 = require("../notifications/notifications.service");
const runtime_observability_1 = require("../common/observability/runtime-observability");
let TravelersService = class TravelersService {
    constructor(prisma, notificationsService) {
        this.prisma = prisma;
        this.notificationsService = notificationsService;
    }
    normalizeDecimal(value) {
        const parsed = Number(value ?? 0);
        return Number.isFinite(parsed) ? parsed : 0;
    }
    getAllowedDirectionsByType(travelerType) {
        switch (travelerType) {
            case client_1.TravelerType.avion_ida_vuelta:
                return [client_1.ShipmentDirection.gt_to_us, client_1.ShipmentDirection.us_to_gt];
            case client_1.TravelerType.avion_tierra:
                return [client_1.ShipmentDirection.gt_to_us, client_1.ShipmentDirection.us_to_gt];
            case client_1.TravelerType.solo_tierra:
                return [client_1.ShipmentDirection.us_to_gt];
        }
    }
    async createTravelerProfile(payload) {
        const directions = this.getAllowedDirectionsByType(payload.travelerType);
        const profile = await this.prisma.travelerProfile.create({
            data: {
                userId: payload.userId,
                travelerType: payload.travelerType,
                status: client_1.TravelerStatus.pending,
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
                kycTier: summary.suggestedKycTier,
            },
        });
        return profile;
    }
    async getVerificationSummary(userId, requester) {
        if (requester.sub !== userId && !['admin', 'support'].includes(requester.role)) {
            throw new common_1.ForbiddenException('No tienes acceso a esta verificación.');
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
            throw new common_1.NotFoundException('Perfil de viajero no encontrado.');
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
        const passedKycChecks = latestKycChecks.filter((check) => check.status === client_1.KycCheckStatus.passed).length;
        const failedKycChecks = latestKycChecks.filter((check) => check.status === client_1.KycCheckStatus.failed).length;
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
        if (devices.length >= 5)
            trustScore -= 12;
        if (devices.length >= 8)
            trustScore -= 10;
        if (suspiciousDeviceCount > 0)
            trustScore -= 18;
        if (averageDeviceTrust > 0 && averageDeviceTrust < 55)
            trustScore -= 10;
        if (accountAgeHours < 24)
            trustScore -= 8;
        if (failedKycChecks > 0)
            score -= failedKycChecks * 10;
        if (failedKycChecks > 0)
            trustScore -= failedKycChecks * 8;
        score = Math.max(0, Math.min(100, score));
        trustScore = Math.max(0, Math.min(100, trustScore));
        const missingRequirements = [];
        if (!traveler.documentUrl)
            missingRequirements.push('Subir documento oficial');
        if (!traveler.selfieUrl)
            missingRequirements.push('Subir selfie de validación');
        if (!documentProtected || !selfieProtected)
            missingRequirements.push('Re-subir evidencia KYC protegida');
        if (!traveler.user.phoneVerified)
            missingRequirements.push('Verificar teléfono');
        if (!traveler.user.emailVerified)
            missingRequirements.push('Verificar correo');
        if (devices.length === 0)
            missingRequirements.push('Registrar dispositivo confiable');
        const payoutHoldRecommended = highFlags > 0 ||
            trustScore < 55 ||
            !traveler.documentUrl ||
            !traveler.selfieUrl ||
            !traveler.user.phoneVerified ||
            failedKycChecks > 0;
        const suggestedKycTier = trustScore >= 85 && highFlags === 0 && passedKycChecks >= 2
            ? client_1.KycTier.premium
            : trustScore >= 60
                ? client_1.KycTier.enhanced
                : client_1.KycTier.basic;
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
    async runKycAnalysis(userId, requester) {
        if (requester.sub !== userId && !['admin', 'support'].includes(requester.role)) {
            throw new common_1.ForbiddenException('No tienes acceso a este análisis KYC.');
        }
        const traveler = await this.prisma.travelerProfile.findUnique({
            where: { userId },
            include: { user: true },
        });
        if (!traveler) {
            throw new common_1.NotFoundException('Perfil de viajero no encontrado.');
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
                kind: client_1.KycCheckKind.document_ocr,
                status: traveler.documentUrl && documentFile?.isProtected
                    ? (documentNumber && documentFile.fileName.includes(documentNumber) ? client_1.KycCheckStatus.passed : client_1.KycCheckStatus.manual_review)
                    : client_1.KycCheckStatus.failed,
                confidence: traveler.documentUrl ? (documentNumber && documentFile?.fileName.includes(documentNumber) ? 82 : 58) : 15,
                summary: traveler.documentUrl
                    ? documentNumber && documentFile?.fileName.includes(documentNumber)
                        ? 'Documento consistente con referencia interna.'
                        : 'Documento presente, pero requiere OCR o validación manual adicional.'
                    : 'No hay documento para análisis.',
            },
            {
                kind: client_1.KycCheckKind.selfie_face_match,
                status: traveler.selfieUrl && traveler.documentUrl ? client_1.KycCheckStatus.manual_review : client_1.KycCheckStatus.failed,
                confidence: traveler.selfieUrl && traveler.documentUrl ? 55 : 10,
                summary: traveler.selfieUrl && traveler.documentUrl
                    ? 'Assets presentes, listo para face-match provider o revisión manual.'
                    : 'Falta selfie o documento para análisis biométrico.',
            },
            {
                kind: client_1.KycCheckKind.liveness_review,
                status: selfieFile?.isProtected == true ? client_1.KycCheckStatus.manual_review : client_1.KycCheckStatus.failed,
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
        runtime_observability_1.runtimeObservability.recordBusinessEvent({
            type: 'traveler_kyc_analysis_run',
            actorId: requester.sub,
            metadata: { userId, travelerProfileId: traveler.id },
        });
        return this.getVerificationSummary(userId, requester);
    }
    async listReviewQueue(requester) {
        if (!['admin', 'support'].includes(requester.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede ver la cola.');
        }
        const travelers = await this.prisma.travelerProfile.findMany({
            where: {
                status: { in: [client_1.TravelerStatus.pending, client_1.TravelerStatus.rejected, client_1.TravelerStatus.blocked] },
            },
            include: {
                user: true,
                routes: true,
            },
            orderBy: { createdAt: 'asc' },
            take: 100,
        });
        const results = await Promise.all(travelers.map(async (traveler) => ({
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
        })));
        return results.sort((a, b) => {
            const riskA = a.summary.payoutHoldRecommended ? -20 : 0;
            const riskB = b.summary.payoutHoldRecommended ? -20 : 0;
            return (a.summary.score + a.summary.trustScore + riskA) - (b.summary.score + b.summary.trustScore + riskB);
        });
    }
    async updatePayoutHold(userId, payload, requester) {
        if (!['admin', 'support'].includes(requester.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede administrar holds.');
        }
        const traveler = await this.prisma.travelerProfile.findUnique({
            where: { userId },
        });
        if (!traveler) {
            throw new common_1.NotFoundException('Perfil de viajero no encontrado.');
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
        await this.notificationsService.sendPush(userId, payload.enabled ? 'Retención operativa activada' : 'Retención operativa liberada', payload.enabled
            ? `Tu cuenta quedó bajo revisión de payout${payload.reason ? `: ${payload.reason}` : '.'}`
            : 'Tu retención operativa fue liberada y puedes continuar con normalidad.', 'traveler_payout_hold');
        return updated;
    }
    async reviewTraveler(userId, payload, requester) {
        if (!['admin', 'support'].includes(requester.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede revisar viajeros.');
        }
        const traveler = await this.prisma.travelerProfile.findUnique({
            where: { userId },
            include: { user: true },
        });
        if (!traveler) {
            throw new common_1.NotFoundException('Perfil de viajero no encontrado.');
        }
        const summary = await this.getVerificationSummary(userId, requester);
        const nextStatus = payload.action === 'approve'
            ? client_1.TravelerStatus.verified
            : payload.action === 'reject'
                ? client_1.TravelerStatus.rejected
                : client_1.TravelerStatus.blocked;
        const updated = await this.prisma.travelerProfile.update({
            where: { userId },
            data: {
                status: nextStatus,
                verificationScore: summary.score,
                trustScore: summary.trustScore,
                payoutHoldEnabled: payload.action === 'approve' ? summary.payoutHoldRecommended : true,
                kycTier: summary.suggestedKycTier,
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
        await this.notificationsService.sendPush(userId, payload.action === 'approve' ? 'Perfil verificado' : payload.action === 'reject' ? 'Verificación rechazada' : 'Cuenta bloqueada', payload.action === 'approve'
            ? summary.payoutHoldRecommended
                ? 'Tu perfil fue aprobado con monitoreo reforzado y retención operativa temporal de payouts.'
                : 'Tu perfil de viajero fue verificado y ya puede operar con normalidad.'
            : payload.action === 'reject'
                ? `Tu perfil necesita revisión adicional${payload.reason ? `: ${payload.reason}` : '.'}`
                : `Tu cuenta fue bloqueada preventivamente${payload.reason ? `: ${payload.reason}` : '.'}`, 'traveler_verification');
        runtime_observability_1.runtimeObservability.recordBusinessEvent({
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
    register(payload) {
        return {
            message: 'Use auth/register/traveler for the full flow',
            travelerType: payload.travelerType,
            detectedCountryCode: payload.detectedCountryCode,
        };
    }
};
exports.TravelersService = TravelersService;
exports.TravelersService = TravelersService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        notifications_service_1.NotificationsService])
], TravelersService);
//# sourceMappingURL=travelers.service.js.map