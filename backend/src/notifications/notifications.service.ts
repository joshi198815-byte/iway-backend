import { ForbiddenException, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { createHash } from 'node:crypto';
import * as admin from 'firebase-admin';
import { PrismaService } from '../database/prisma/prisma.service';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { runtimeObservability } from '../common/observability/runtime-observability';
import { JobsService } from '../jobs/jobs.service';

@Injectable()
export class NotificationsService implements OnModuleInit {
  private readonly logger = new Logger(NotificationsService.name);
  private firebaseApp: admin.app.App | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly realtimeGateway: RealtimeGateway,
    private readonly jobsService: JobsService,
  ) {}

  onModuleInit() {
    this.jobsService.registerHandler('push-dispatch-single', async (payload) => {
      const devices = Array.isArray(payload.devices) ? payload.devices : [];

      const pushResults = await Promise.all(
        devices.map((device) => {
          const entry = device as Record<string, unknown>;
          return this.sendFirebasePushToToken({
            token: String(entry.token ?? ''),
            title: String(payload.title ?? ''),
            body: String(payload.body ?? ''),
            type: typeof payload.type === 'string' ? payload.type : 'push',
            shipmentId: typeof payload.shipmentId === 'string' ? payload.shipmentId : undefined,
          });
        }),
      );

      runtimeObservability.recordBusinessEvent({
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

      const pushResults = await Promise.all(
        devices.map((device) => {
          const entry = device as Record<string, unknown>;
          return this.sendFirebasePushToToken({
            token: String(entry.token ?? ''),
            title: String(payload.title ?? ''),
            body: String(payload.body ?? ''),
            type: typeof payload.type === 'string' ? payload.type : 'push',
            shipmentId: typeof payload.shipmentId === 'string' ? payload.shipmentId : undefined,
          });
        }),
      );

      runtimeObservability.recordBusinessEvent({
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

    this.jobsService.registerHandler('scheduled-pickup-reminder', async (payload) => {
      const userIds = Array.isArray(payload.userIds)
        ? payload.userIds.map((item) => String(item)).filter((item) => item.trim().length > 0)
        : [];

      if (userIds.length === 0) {
        return;
      }

      await this.sendPushMany(
        userIds,
        String(payload.title ?? ''),
        String(payload.body ?? ''),
        typeof payload.type === 'string' ? payload.type : 'pickup_reminder',
        typeof payload.shipmentId === 'string' ? payload.shipmentId : undefined,
        { highPriority: payload.highPriority === true },
      );
    });
  }

  private getFirebaseServiceAccount() {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim();
    if (!raw) {
      return null;
    }

    try {
      const parsed = JSON.parse(raw) as Record<string, unknown>;
      const privateKeyRaw = typeof parsed.private_key === 'string'
        ? parsed.private_key
        : typeof parsed.privateKey === 'string'
          ? parsed.privateKey
          : '';

      return {
        projectId: typeof parsed.project_id === 'string' ? parsed.project_id : typeof parsed.projectId === 'string' ? parsed.projectId : undefined,
        clientEmail: typeof parsed.client_email === 'string' ? parsed.client_email : typeof parsed.clientEmail === 'string' ? parsed.clientEmail : undefined,
        privateKey: privateKeyRaw.replace(/\\n/g, '\n'),
      } as admin.ServiceAccount;
    } catch (error) {
      this.logger.error(
        `firebase service account json invalid error=${error instanceof Error ? error.message : 'unknown'}`,
      );
      return null;
    }
  }

  private firebaseConfigured() {
    return Boolean(this.getFirebaseServiceAccount());
  }

  private getFirebaseApp() {
    if (this.firebaseApp) {
      return this.firebaseApp;
    }

    const serviceAccount = this.getFirebaseServiceAccount();
    if (!serviceAccount) {
      return null;
    }

    try {
      this.firebaseApp = admin.apps.length > 0
        ? admin.apps[0]
        : admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
          });
      return this.firebaseApp;
    } catch (error) {
      this.logger.error(
        `firebase initialize failed error=${error instanceof Error ? error.message : 'unknown'}`,
      );
      return null;
    }
  }

  private routeForType(type?: string, shipmentId?: string) {
    switch (type) {
      case 'offer':
      case 'offer_updated':
      case 'offer_rejected':
      case 'shipment_available':
      case 'shipment_published':
        return shipmentId ? '/offers' : '/notifications';
      case 'chat_message':
        return shipmentId ? '/chat' : '/notifications';
      case 'offer_accepted':
      case 'pickup_appointment_confirmed':
      case 'pickup_reminder_24h':
      case 'pickup_reminder_customer_1h':
      case 'pickup_reminder_traveler_1h':
      case 'shipment_assigned':
      case 'shipment_in_route':
      case 'shipment_status_changed':
      case 'shipment_delivered':
      case 'delivery_closed':
      case 'tracking_updated':
        return shipmentId ? '/tracking' : '/notifications';
      case 'traveler_verification':
        return '/profile';
      case 'rating':
        return '/my_ratings';
      case 'transfer_review':
        return '/debts';
      default:
        return '/notifications';
    }
  }

  private formatPickupDateTime(value: Date) {
    const local = new Date(value);
    const day = `${local.getDate()}`.padStart(2, '0');
    const month = `${local.getMonth() + 1}`.padStart(2, '0');
    const year = `${local.getFullYear()}`;
    const hour = `${local.getHours()}`.padStart(2, '0');
    const minute = `${local.getMinutes()}`.padStart(2, '0');
    return `${day}/${month}/${year} a las ${hour}:${minute}`;
  }

  async schedulePickupReminders(params: {
    shipmentId: string;
    customerId: string;
    travelerId: string;
    pickupAt: Date;
  }) {
    const pickupTime = params.pickupAt.getTime();
    const now = Date.now();

    await this.sendPush(
      params.travelerId,
      'Cita confirmada',
      `Cita confirmada para el ${this.formatPickupDateTime(params.pickupAt)}.`,
      'pickup_appointment_confirmed',
      params.shipmentId,
      { highPriority: true },
    );

    const scheduledJobs: Promise<unknown>[] = [];

    if (pickupTime - 24 * 60 * 60 * 1000 > now) {
      scheduledJobs.push(
        this.jobsService.enqueue({
          name: 'scheduled-pickup-reminder',
          initialDelayMs: pickupTime - 24 * 60 * 60 * 1000 - now,
          payload: {
            userIds: [params.customerId, params.travelerId],
            title: 'Recordatorio de recolección',
            body: `Recordatorio: Mañana es la recolección del paquete #${params.shipmentId}.`,
            type: 'pickup_reminder_24h',
            shipmentId: params.shipmentId,
          },
        }),
      );
    }

    if (pickupTime - 60 * 60 * 1000 > now) {
      scheduledJobs.push(
        this.jobsService.enqueue({
          name: 'scheduled-pickup-reminder',
          initialDelayMs: pickupTime - 60 * 60 * 1000 - now,
          payload: {
            userIds: [params.customerId],
            title: 'Tu viajero está cerca',
            body: `Tu viajero está cerca del paquete #${params.shipmentId}.`,
            type: 'pickup_reminder_customer_1h',
            shipmentId: params.shipmentId,
            highPriority: true,
          },
        }),
      );
      scheduledJobs.push(
        this.jobsService.enqueue({
          name: 'scheduled-pickup-reminder',
          initialDelayMs: pickupTime - 60 * 60 * 1000 - now,
          payload: {
            userIds: [params.travelerId],
            title: 'Es hora de recoger',
            body: `Es hora de recoger el paquete #${params.shipmentId}, abre tu mapa aquí.`,
            type: 'pickup_reminder_traveler_1h',
            shipmentId: params.shipmentId,
            highPriority: true,
          },
        }),
      );
    }

    await Promise.all(scheduledJobs);
  }

  private async sendFirebasePushToToken(params: {
    token: string;
    title: string;
    body: string;
    type?: string;
    shipmentId?: string;
    highPriority?: boolean;
  }) {
    const firebaseApp = this.getFirebaseApp();
    if (!firebaseApp) {
      return { sent: false, invalidToken: false, responseBody: 'firebase_not_configured' };
    }

    try {
      const messageId = await firebaseApp.messaging().send({
        token: params.token,
        notification: {
          title: params.title,
          body: params.body,
        },
        data: {
          type: params.type ?? 'push',
          shipmentId: params.shipmentId ?? '',
          route: this.routeForType(params.type, params.shipmentId),
          priority: 'high',
          sound: 'default',
          content_available: 'true',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'high_importance_channel',
            priority: 'max',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            sound: 'default',
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          headers: {
            'apns-priority': '10',
            'apns-push-type': 'alert',
          },
          payload: {
            aps: {
              sound: 'default',
              'content-available': 1,
              'mutable-content': 1,
              'interruption-level': params.highPriority ? 'time-sensitive' : 'active',
            },
          },
        },
      });

      return {
        sent: true,
        status: 200,
        invalidToken: false,
        responseBody: messageId,
      };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      const invalidToken =
        errorMessage.includes('registration-token-not-registered') ||
        errorMessage.includes('Requested entity was not found') ||
        errorMessage.includes('UNREGISTERED');

      return {
        sent: false,
        status: 500,
        invalidToken,
        responseBody: errorMessage,
      };
    }
  }

  private async deactivateInvalidDeviceTokens(
    devices: Array<{ token: string }>,
    results: Array<{ invalidToken?: boolean }>,
  ) {
    const tokensToDeactivate = devices
      .filter((device, index) => results[index]?.invalidToken === true)
      .map((device) => device.token)
      .filter((token) => token.trim().length > 0);

    if (tokensToDeactivate.length === 0) {
      return;
    }

    await this.prisma.deviceToken.updateMany({
      where: { token: { in: tokensToDeactivate } },
      data: {
        active: false,
        lastSeenAt: new Date(),
      },
    });
  }

  async findByUser(userId: string) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async create(
    userId: string,
    title: string,
    body: string,
    type = 'system',
    shipmentId?: string,
  ) {
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

    runtimeObservability.recordBusinessEvent({
      type: 'notification_created',
      entityId: notification.id,
      actorId: userId,
      shipmentId: shipmentId ?? undefined,
      metadata: { notificationType: type },
    });

    return notification;
  }

  async createMany(
    userIds: string[],
    title: string,
    body: string,
    type = 'system',
    shipmentId?: string,
  ) {
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

    runtimeObservability.recordBusinessEvent({
      type: 'notification_batch_created',
      actorId: uniqueUserIds[0],
      shipmentId: shipmentId ?? undefined,
      metadata: { notificationType: type, userCount: uniqueUserIds.length },
    });

    return result;
  }

  async markRead(id: string, requester: { sub: string; role: string }) {
    const notification = await this.prisma.notification.findUnique({
      where: { id },
    });

    if (!notification) {
      throw new ForbiddenException('Notificación no encontrada.');
    }

    if (notification.userId !== requester.sub && !['admin', 'support'].includes(requester.role)) {
      throw new ForbiddenException('No puedes marcar esta notificación.');
    }

    return this.prisma.notification.update({
      where: { id },
      data: { readAt: new Date() },
    });
  }

  async markAllRead(requester: { sub: string; role: string }) {
    return this.prisma.notification.updateMany({
      where: {
        userId: requester.sub,
        readAt: null,
      },
      data: {
        readAt: new Date(),
      },
    });
  }

  async sendPushMany(
    userIds: string[],
    title: string,
    body: string,
    type = 'push',
    shipmentId?: string,
    options?: { highPriority?: boolean },
  ) {
    try {
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
      let sentCount = 0;

      this.logger.log(
        `sendPushMany start type=${type} shipmentId=${shipmentId ?? '-'} userCount=${uniqueUserIds.length} deviceCount=${activeDevices.length} providerConfigured=${providerConfigured}`,
      );

      if (providerConfigured && activeDevices.length > 0) {
        const results = await Promise.all(
          activeDevices.map((device) =>
            this.sendFirebasePushToToken({
              token: device.token,
              title,
              body,
              type,
              shipmentId,
              highPriority: options?.highPriority === true,
            }),
          ),
        );
        await this.deactivateInvalidDeviceTokens(activeDevices, results);
        sentCount = results.filter((result) => result.sent).length;

        const failedResults = results.filter((result) => !result.sent);
        if (failedResults.length > 0) {
          this.logger.warn(
            `sendPushMany partial failure type=${type} shipmentId=${shipmentId ?? '-'} statuses=${failedResults.map((result) => result.status ?? 0).join(',')} bodies=${failedResults.map((result) => result.responseBody ?? '').filter((body) => body.length > 0).join(' | ')}`,
          );
        }
      }

      this.logger.log(
        `sendPushMany result type=${type} shipmentId=${shipmentId ?? '-'} userCount=${uniqueUserIds.length} deviceCount=${activeDevices.length} sentCount=${sentCount} providerConfigured=${providerConfigured}`,
      );

      return {
        queued: false,
        providerConfigured,
        userCount: uniqueUserIds.length,
        deviceCount: activeDevices.length,
        sentCount,
        jobId: null,
      };
    } catch (error) {
      this.logger.error(
        `sendPushMany failed type=${type} shipmentId=${shipmentId ?? '-'} error=${error instanceof Error ? error.message : 'unknown'}`,
      );
      return {
        queued: false,
        providerConfigured: this.firebaseConfigured(),
        userCount: [...new Set(userIds.filter((id) => typeof id === 'string' && id.trim().length > 0))].length,
        deviceCount: 0,
        sentCount: 0,
        jobId: null,
      };
    }
  }

  async registerDeviceToken(userId: string, payload: RegisterDeviceTokenDto) {
    const fingerprint = createHash('sha256')
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

    this.logger.log(
      `registerDeviceToken userId=${userId} platform=${payload.platform} suspicious=${suspicious} installationId=${payload.installationId ?? '-'} tokenSuffix=${payload.token.slice(-12)}`,
    );

    runtimeObservability.recordBusinessEvent({
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

  async deactivateDeviceToken(userId: string, token: string) {
    return this.prisma.deviceToken.updateMany({
      where: { userId, token },
      data: {
        active: false,
        lastSeenAt: new Date(),
      },
    });
  }

  async sendPush(
    userId: string,
    title: string,
    body: string,
    type = 'push',
    shipmentId?: string,
    options?: { highPriority?: boolean },
  ) {
    try {
      const notification = await this.create(userId, title, body, type, shipmentId);
      const activeDevices = await this.prisma.deviceToken.findMany({
        where: { userId, active: true },
        select: { id: true, platform: true, token: true },
      });

      const providerConfigured = this.firebaseConfigured();
      let pushResults: Array<{ sent: boolean; status?: number; invalidToken?: boolean; responseBody?: string }> = [];

      this.logger.log(
        `sendPush start userId=${userId} type=${type} shipmentId=${shipmentId ?? '-'} deviceCount=${activeDevices.length} providerConfigured=${providerConfigured}`,
      );

      if (providerConfigured && activeDevices.length > 0) {
        pushResults = await Promise.all(
          activeDevices.map((device) =>
            this.sendFirebasePushToToken({
              token: device.token,
              title,
              body,
              type,
              shipmentId,
              highPriority: options?.highPriority === true,
            }),
          ),
        );
        await this.deactivateInvalidDeviceTokens(activeDevices, pushResults);
      }

      const sentCount = pushResults.filter((result) => result.sent).length;
      const failedCount = pushResults.length - sentCount;

      this.logger.log(
        `sendPush result userId=${userId} type=${type} shipmentId=${shipmentId ?? '-'} deviceCount=${activeDevices.length} sentCount=${sentCount} failedCount=${failedCount} providerConfigured=${providerConfigured}`,
      );

      if (failedCount > 0) {
        this.logger.warn(
          `sendPush partial failure userId=${userId} type=${type} shipmentId=${shipmentId ?? '-'} statuses=${pushResults.map((result) => result.status ?? 0).join(',')} bodies=${pushResults.map((result) => result.responseBody ?? '').filter((body) => body.length > 0).join(' | ')}`,
        );
      }

      return {
        ...notification,
        queued: false,
        providerConfigured,
        deviceCount: activeDevices.length,
        sentCount,
        jobId: null,
        devices: activeDevices.map((device, index) => ({
          id: device.id,
          platform: device.platform,
          sent: index < pushResults.length ? pushResults[index].sent : false,
        })),
      };
    } catch (error) {
      this.logger.error(
        `sendPush failed userId=${userId} type=${type} shipmentId=${shipmentId ?? '-'} error=${error instanceof Error ? error.message : 'unknown'}`,
      );
      return {
        queued: false,
        providerConfigured: this.firebaseConfigured(),
        deviceCount: 0,
        sentCount: 0,
        jobId: null,
        devices: [],
      };
    }
  }
}
