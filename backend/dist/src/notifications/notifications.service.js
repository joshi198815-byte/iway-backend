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
exports.NotificationsService = void 0;
const common_1 = require("@nestjs/common");
const node_crypto_1 = require("node:crypto");
const prisma_service_1 = require("../database/prisma/prisma.service");
const realtime_gateway_1 = require("../realtime/realtime.gateway");
const runtime_observability_1 = require("../common/observability/runtime-observability");
const jobs_service_1 = require("../jobs/jobs.service");
let NotificationsService = class NotificationsService {
    constructor(prisma, realtimeGateway, jobsService) {
        this.prisma = prisma;
        this.realtimeGateway = realtimeGateway;
        this.jobsService = jobsService;
    }
    onModuleInit() {
        this.jobsService.registerHandler('push-dispatch-single', async (payload) => {
            const devices = Array.isArray(payload.devices) ? payload.devices : [];
            const accessToken = await this.getFirebaseAccessToken();
            if (!accessToken) {
                throw new Error('firebase_access_token_unavailable');
            }
            const pushResults = await Promise.all(devices.map((device) => {
                const entry = device;
                return this.sendFirebasePushToToken({
                    token: String(entry.token ?? ''),
                    title: String(payload.title ?? ''),
                    body: String(payload.body ?? ''),
                    type: typeof payload.type === 'string' ? payload.type : 'push',
                    shipmentId: typeof payload.shipmentId === 'string' ? payload.shipmentId : undefined,
                    accessToken,
                });
            }));
            runtime_observability_1.runtimeObservability.recordBusinessEvent({
                type: 'push_dispatch',
                actorId: typeof payload.userId === 'string' ? payload.userId : undefined,
                shipmentId: typeof payload.shipmentId === 'string' ? payload.shipmentId : undefined,
                metadata: {
                    pushType: payload.type,
                    deviceCount: devices.length,
                    sentCount: pushResults.filter((result) => result.sent).length,
                },
            });
        });
        this.jobsService.registerHandler('push-dispatch-batch', async (payload) => {
            const devices = Array.isArray(payload.devices) ? payload.devices : [];
            const accessToken = await this.getFirebaseAccessToken();
            if (!accessToken) {
                throw new Error('firebase_access_token_unavailable');
            }
            const pushResults = await Promise.all(devices.map((device) => {
                const entry = device;
                return this.sendFirebasePushToToken({
                    token: String(entry.token ?? ''),
                    title: String(payload.title ?? ''),
                    body: String(payload.body ?? ''),
                    type: typeof payload.type === 'string' ? payload.type : 'push',
                    shipmentId: typeof payload.shipmentId === 'string' ? payload.shipmentId : undefined,
                    accessToken,
                });
            }));
            runtime_observability_1.runtimeObservability.recordBusinessEvent({
                type: 'push_dispatch_batch',
                actorId: typeof payload.actorId === 'string' ? payload.actorId : undefined,
                shipmentId: typeof payload.shipmentId === 'string' ? payload.shipmentId : undefined,
                metadata: {
                    pushType: payload.type,
                    userCount: payload.userCount,
                    deviceCount: devices.length,
                    sentCount: pushResults.filter((result) => result.sent).length,
                },
            });
        });
    }
    base64UrlEncode(input) {
        return Buffer.from(input)
            .toString('base64')
            .replace(/=/g, '')
            .replace(/\+/g, '-')
            .replace(/\//g, '_');
    }
    firebaseConfigured() {
        return Boolean(process.env.FIREBASE_PROJECT_ID &&
            process.env.FIREBASE_CLIENT_EMAIL &&
            process.env.FIREBASE_PRIVATE_KEY);
    }
    async getFirebaseAccessToken() {
        const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
        const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');
        if (!clientEmail || !privateKey) {
            return null;
        }
        const now = Math.floor(Date.now() / 1000);
        const header = this.base64UrlEncode(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
        const claimSet = this.base64UrlEncode(JSON.stringify({
            iss: clientEmail,
            scope: 'https://www.googleapis.com/auth/firebase.messaging',
            aud: 'https://oauth2.googleapis.com/token',
            exp: now + 3600,
            iat: now,
        }));
        const signer = (0, node_crypto_1.createSign)('RSA-SHA256');
        signer.update(`${header}.${claimSet}`);
        signer.end();
        const signature = this.base64UrlEncode(signer.sign(privateKey));
        const assertion = `${header}.${claimSet}.${signature}`;
        const response = await fetch('https://oauth2.googleapis.com/token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({
                grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                assertion,
            }),
        });
        if (!response.ok) {
            return null;
        }
        const data = (await response.json());
        return data.access_token ?? null;
    }
    async sendFirebasePushToToken(params) {
        const projectId = process.env.FIREBASE_PROJECT_ID;
        const accessToken = params.accessToken ?? (await this.getFirebaseAccessToken());
        if (!projectId || !accessToken) {
            return { sent: false };
        }
        const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
                message: {
                    token: params.token,
                    notification: {
                        title: params.title,
                        body: params.body,
                    },
                    data: {
                        type: params.type ?? 'push',
                        shipmentId: params.shipmentId ?? '',
                        route: params.shipmentId ? '/tracking' : '/notifications',
                    },
                    android: {
                        priority: 'high',
                        notification: {
                            channelId: 'iway_high_importance',
                        },
                    },
                    apns: {
                        headers: {
                            'apns-priority': '10',
                        },
                        payload: {
                            aps: {
                                sound: 'default',
                            },
                        },
                    },
                },
            }),
        });
        return {
            sent: response.ok,
            status: response.status,
        };
    }
    async findByUser(userId) {
        return this.prisma.notification.findMany({
            where: { userId },
            orderBy: { createdAt: 'desc' },
        });
    }
    async create(userId, title, body, type = 'system', shipmentId) {
        const notification = await this.prisma.notification.create({
            data: {
                userId,
                title,
                body,
                type,
                shipmentId,
            },
        });
        this.realtimeGateway.emitNotificationUpdated(userId, {
            userId,
            notificationId: notification.id,
            type,
            shipmentId: shipmentId ?? null,
        });
        runtime_observability_1.runtimeObservability.recordBusinessEvent({
            type: 'notification_created',
            entityId: notification.id,
            actorId: userId,
            shipmentId: shipmentId ?? undefined,
            metadata: { notificationType: type },
        });
        return notification;
    }
    async createMany(userIds, title, body, type = 'system', shipmentId) {
        const uniqueUserIds = [...new Set(userIds.filter((id) => typeof id === 'string' && id.trim().length > 0))];
        if (uniqueUserIds.length === 0) {
            return { count: 0 };
        }
        const result = await this.prisma.notification.createMany({
            data: uniqueUserIds.map((userId) => ({
                userId,
                title,
                body,
                type,
                shipmentId,
            })),
        });
        uniqueUserIds.forEach((userId) => {
            this.realtimeGateway.emitNotificationUpdated(userId, {
                userId,
                type,
                shipmentId: shipmentId ?? null,
            });
        });
        runtime_observability_1.runtimeObservability.recordBusinessEvent({
            type: 'notification_batch_created',
            actorId: uniqueUserIds[0],
            shipmentId: shipmentId ?? undefined,
            metadata: { notificationType: type, userCount: uniqueUserIds.length },
        });
        return result;
    }
    async markRead(id, requester) {
        const notification = await this.prisma.notification.findUnique({
            where: { id },
        });
        if (!notification) {
            throw new common_1.ForbiddenException('Notificación no encontrada.');
        }
        if (notification.userId !== requester.sub && !['admin', 'support'].includes(requester.role)) {
            throw new common_1.ForbiddenException('No puedes marcar esta notificación.');
        }
        return this.prisma.notification.update({
            where: { id },
            data: { readAt: new Date() },
        });
    }
    async sendPushMany(userIds, title, body, type = 'push', shipmentId) {
        const uniqueUserIds = [...new Set(userIds.filter((id) => typeof id === 'string' && id.trim().length > 0))];
        if (uniqueUserIds.length === 0) {
            return { queued: false, providerConfigured: this.firebaseConfigured(), userCount: 0, deviceCount: 0, sentCount: 0 };
        }
        await this.createMany(uniqueUserIds, title, body, type, shipmentId);
        const activeDevices = await this.prisma.deviceToken.findMany({
            where: { userId: { in: uniqueUserIds }, active: true },
            select: { id: true, platform: true, token: true, userId: true },
        });
        const providerConfigured = this.firebaseConfigured();
        const dispatchJob = providerConfigured && activeDevices.length > 0
            ? await this.jobsService.enqueue({
                name: 'push-dispatch-batch',
                payload: {
                    actorId: uniqueUserIds[0],
                    title,
                    body,
                    type,
                    shipmentId: shipmentId ?? null,
                    userCount: uniqueUserIds.length,
                    devices: activeDevices.map((device) => ({
                        token: device.token,
                        userId: device.userId,
                        platform: device.platform,
                    })),
                },
                maxAttempts: 4,
            })
            : null;
        return {
            queued: Boolean(dispatchJob),
            providerConfigured,
            userCount: uniqueUserIds.length,
            deviceCount: activeDevices.length,
            sentCount: 0,
            jobId: dispatchJob?.id ?? null,
        };
    }
    async registerDeviceToken(userId, payload) {
        const fingerprint = (0, node_crypto_1.createHash)('sha256')
            .update(`${payload.platform}:${payload.installationId ?? payload.token}`)
            .digest('hex');
        const existingFingerprints = await this.prisma.deviceToken.count({
            where: {
                fingerprint,
                userId: { not: userId },
            },
        });
        const trustScore = existingFingerprints > 0 ? 28 : payload.installationId ? 82 : 64;
        const suspicious = existingFingerprints > 0;
        const token = await this.prisma.deviceToken.upsert({
            where: { token: payload.token },
            update: {
                userId,
                platform: payload.platform,
                deviceLabel: payload.deviceLabel,
                installationId: payload.installationId,
                fingerprint,
                trustScore,
                suspicious,
                trustedAt: suspicious ? null : new Date(),
                active: true,
                lastSeenAt: new Date(),
            },
            create: {
                userId,
                token: payload.token,
                platform: payload.platform,
                deviceLabel: payload.deviceLabel,
                installationId: payload.installationId,
                fingerprint,
                trustScore,
                suspicious,
                trustedAt: suspicious ? null : new Date(),
                active: true,
            },
        });
        runtime_observability_1.runtimeObservability.recordBusinessEvent({
            type: 'device_token_registered',
            actorId: userId,
            metadata: {
                platform: payload.platform,
                trustScore,
                suspicious,
                sharedFingerprintCount: existingFingerprints,
            },
        });
        return token;
    }
    async deactivateDeviceToken(userId, token) {
        return this.prisma.deviceToken.updateMany({
            where: { userId, token },
            data: {
                active: false,
                lastSeenAt: new Date(),
            },
        });
    }
    async sendPush(userId, title, body, type = 'push', shipmentId) {
        const notification = await this.create(userId, title, body, type, shipmentId);
        const activeDevices = await this.prisma.deviceToken.findMany({
            where: { userId, active: true },
            select: { id: true, platform: true, token: true },
        });
        const providerConfigured = this.firebaseConfigured();
        const dispatchJob = providerConfigured && activeDevices.length > 0
            ? await this.jobsService.enqueue({
                name: 'push-dispatch-single',
                payload: {
                    userId,
                    title,
                    body,
                    type,
                    shipmentId: shipmentId ?? null,
                    devices: activeDevices.map((device) => ({
                        token: device.token,
                        platform: device.platform,
                    })),
                },
                maxAttempts: 4,
            })
            : null;
        return {
            ...notification,
            queued: Boolean(dispatchJob),
            providerConfigured,
            deviceCount: activeDevices.length,
            sentCount: 0,
            jobId: dispatchJob?.id ?? null,
            devices: activeDevices.map((device) => ({
                id: device.id,
                platform: device.platform,
                sent: false,
            })),
        };
    }
};
exports.NotificationsService = NotificationsService;
exports.NotificationsService = NotificationsService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        realtime_gateway_1.RealtimeGateway,
        jobs_service_1.JobsService])
], NotificationsService);
//# sourceMappingURL=notifications.service.js.map