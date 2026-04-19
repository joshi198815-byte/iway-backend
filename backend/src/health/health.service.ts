import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma/prisma.service';

@Injectable()
export class HealthService {
  constructor(private readonly prisma: PrismaService) {}

  async getHealthSnapshot() {
    const db = await this.getDatabaseHealth();
    const business = await this.getBusinessMetrics();

    return {
      ok: db.ok,
      service: 'iway-backend',
      env: process.env.NODE_ENV ?? 'development',
      version: process.env.npm_package_version ?? 'unknown',
      timestamp: new Date().toISOString(),
      dependencies: {
        database: db,
      },
      business,
    };
  }

  async getDatabaseHealth() {
    const startedAt = Date.now();
    try {
      await this.prisma.$queryRawUnsafe('SELECT 1');
      return {
        ok: true,
        latencyMs: Date.now() - startedAt,
      };
    } catch (error) {
      return {
        ok: false,
        latencyMs: Date.now() - startedAt,
        message: error instanceof Error ? error.message : 'falló la verificación de base de datos',
      };
    }
  }

  async getBusinessMetrics() {
    const [
      totalUsers,
      totalCustomers,
      totalTravelers,
      totalAdmins,
      blockedUsers,
      pendingUsers,
      travelerPending,
      travelerVerified,
      travelerBlocked,
      travelerRejected,
      shipmentsPublished,
      shipmentsAssigned,
      shipmentsDelivered,
      shipmentsDisputed,
      offersPending,
      offersAccepted,
      transfersSubmitted,
      transfersApproved,
      transfersRejected,
      commissionsPending,
      commissionsOverdue,
      commissionsPaid,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { role: 'customer' } }),
      this.prisma.user.count({ where: { role: 'traveler' } }),
      this.prisma.user.count({ where: { role: 'admin' } }),
      this.prisma.user.count({ where: { status: 'blocked' } }),
      this.prisma.user.count({ where: { status: 'pending_verification' } }),
      this.prisma.travelerProfile.count({ where: { status: 'pending' } }),
      this.prisma.travelerProfile.count({ where: { status: 'verified' } }),
      this.prisma.travelerProfile.count({ where: { status: { in: ['blocked', 'blocked_for_debt'] } } }),
      this.prisma.travelerProfile.count({ where: { status: 'rejected' } }),
      this.prisma.shipment.count({ where: { status: 'pending' } }),
      this.prisma.shipment.count({ where: { status: 'assigned' } }),
      this.prisma.shipment.count({ where: { status: 'delivered' } }),
      this.prisma.shipment.count({ where: { status: 'arrived' } }),
      this.prisma.offer.count({ where: { status: 'pending' } }),
      this.prisma.offer.count({ where: { status: 'accepted' } }),
      this.prisma.transferPayment.count({ where: { status: 'submitted' } }),
      this.prisma.transferPayment.count({ where: { status: 'approved' } }),
      this.prisma.transferPayment.count({ where: { status: 'rejected' } }),
      this.prisma.travelerCommission.count({ where: { status: { in: ['pending', 'due', 'for_review'] } } }),
      this.prisma.travelerCommission.count({ where: { status: 'overdue' } }),
      this.prisma.travelerCommission.count({ where: { status: 'paid' } }),
    ]);

    return {
      users: {
        total: totalUsers,
        customers: totalCustomers,
        travelers: totalTravelers,
        admins: totalAdmins,
        blocked: blockedUsers,
        pendingVerification: pendingUsers,
      },
      travelers: {
        pending: travelerPending,
        verified: travelerVerified,
        blocked: travelerBlocked,
        rejected: travelerRejected,
      },
      shipments: {
        pending: shipmentsPublished,
        assigned: shipmentsAssigned,
        delivered: shipmentsDelivered,
        arrived: shipmentsDisputed,
      },
      offers: {
        pending: offersPending,
        accepted: offersAccepted,
      },
      transfers: {
        submitted: transfersSubmitted,
        approved: transfersApproved,
        rejected: transfersRejected,
      },
      commissions: {
        actionable: commissionsPending,
        overdue: commissionsOverdue,
        paid: commissionsPaid,
      },
    };
  }
}
