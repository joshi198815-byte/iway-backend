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
exports.AntiFraudService = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const prisma_service_1 = require("../database/prisma/prisma.service");
const runtime_observability_1 = require("../common/observability/runtime-observability");
let AntiFraudService = class AntiFraudService {
    constructor(prisma) {
        this.prisma = prisma;
        this.phoneRegex = /(?:\+?\d[\d\s-]{6,}\d)/g;
        this.emailRegex = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;
        this.linkRegex = /(https?:\/\/\S+|www\.\S+)/gi;
        this.directContactRegex = /(whatsapp|telegram|llámame|llamame|escríbeme|escribeme|pásame tu número|pasame tu numero|te escribo aparte|mejor por fuera)/gi;
    }
    analyzeMessage(body) {
        const flags = [];
        const containsPhone = this.phoneRegex.test(body);
        const containsEmail = this.emailRegex.test(body);
        const containsExternalLink = this.linkRegex.test(body);
        const containsDirectContactIntent = this.directContactRegex.test(body);
        if (containsPhone)
            flags.push('phone_shared');
        if (containsEmail)
            flags.push('email_shared');
        if (containsExternalLink)
            flags.push('external_link_shared');
        if (containsDirectContactIntent)
            flags.push('direct_contact_intent');
        let sanitizedBody = body
            .replace(this.phoneRegex, '[contacto oculto]')
            .replace(this.emailRegex, '[email oculto]')
            .replace(this.linkRegex, '[link oculto]');
        const riskStatus = flags.length > 0 ? client_1.MessageRiskStatus.flagged : client_1.MessageRiskStatus.clean;
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
    async createFlags(params) {
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
    async createAutoFlagIfMissing(params) {
        const existing = await this.prisma.antiFraudFlag.findFirst({
            where: {
                userId: params.userId,
                flagType: params.flagType,
            },
            orderBy: { createdAt: 'desc' },
        });
        const existingSource = existing?.details;
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
    async buildUserRiskSignals(userId) {
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            include: { travelerProfile: true },
        });
        if (!user) {
            throw new common_1.ForbiddenException('Usuario no encontrado.');
        }
        const now = Date.now();
        const last24h = new Date(now - 24 * 60 * 60 * 1000);
        const last7d = new Date(now - 7 * 24 * 60 * 60 * 1000);
        const [duplicateDocumentCount, shipmentsLast24h, offersLast24h, transfersLast7d, flaggedMessagesLast7d, activeDeviceCount, existingFlags,] = await Promise.all([
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
                    riskStatus: { not: client_1.MessageRiskStatus.clean },
                    createdAt: { gte: last7d },
                },
            }),
            this.prisma.deviceToken.count({ where: { userId, active: true } }),
            this.prisma.antiFraudFlag.findMany({ where: { userId }, orderBy: { createdAt: 'desc' }, take: 50 }),
        ]);
        const signals = [];
        if (duplicateDocumentCount > 0) {
            signals.push({
                key: 'duplicate_document_number',
                severity: 'high',
                evidence: { duplicateDocumentCount, documentNumber: user.travelerProfile?.dpiOrPassport ?? null },
            });
        }
        if (user.countryCode &&
            user.detectedCountryCode &&
            user.countryCode.toUpperCase() != user.detectedCountryCode.toUpperCase()) {
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
        const recommendedRiskLevel = existingHigh + highSignals > 0 ? 'high' : existingMedium + mediumSignals >= 3 ? 'medium' : 'low';
        const recommendedAction = recommendedRiskLevel == 'high'
            ? 'manual_block_review'
            : recommendedRiskLevel == 'medium'
                ? 'manual_review'
                : 'allow_monitoring';
        runtime_observability_1.runtimeObservability.recordBusinessEvent({
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
    async getUserRiskSummary(userId) {
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
    async listReviewQueue(requester) {
        if (!['admin', 'support'].includes(requester.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede ver la cola antifraude.');
        }
        const users = await this.prisma.user.findMany({
            where: { role: 'traveler' },
            include: { travelerProfile: true },
            orderBy: { createdAt: 'desc' },
            take: 80,
        });
        const queue = await Promise.all(users.map(async (user) => ({
            userId: user.id,
            fullName: user.fullName,
            email: user.email,
            travelerStatus: user.travelerProfile?.status ?? null,
            summary: await this.getUserRiskSummary(user.id),
        })));
        return queue
            .filter((item) => item.summary.recommendedRiskLevel !== 'low' || item.summary.total > 0)
            .sort((a, b) => a.summary.riskScore - b.summary.riskScore);
    }
    async createManualFlag(params) {
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
        runtime_observability_1.runtimeObservability.recordBusinessEvent({
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
};
exports.AntiFraudService = AntiFraudService;
exports.AntiFraudService = AntiFraudService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], AntiFraudService);
//# sourceMappingURL=anti-fraud.service.js.map