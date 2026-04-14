import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { CommissionStatus, Prisma, Shipment, ShipmentStatus, TravelerStatus } from '@prisma/client';
import { PrismaService } from '../database/prisma/prisma.service';
import { RegisterCommissionPaymentDto } from './dto/register-commission-payment.dto';
import { runtimeObservability } from '../common/observability/runtime-observability';

@Injectable()
export class CommissionsService {
  constructor(private readonly prisma: PrismaService) {}

  private normalizeCutoffDay(day: number) {
    if (day < 1 || day > 7) {
      return 4;
    }

    return day;
  }

  private getIsoWeekday(date: Date) {
    const day = date.getUTCDay();
    return day === 0 ? 7 : day;
  }

  private getUpcomingCutoff(date: Date, preferredCutoffDay: number) {
    const normalized = new Date(date);
    const today = this.getIsoWeekday(normalized);
    const cutoffDay = this.normalizeCutoffDay(preferredCutoffDay);
    let diff = cutoffDay - today;

    if (diff < 0) {
      diff += 7;
    }

    normalized.setUTCDate(normalized.getUTCDate() + diff);
    normalized.setUTCHours(23, 59, 59, 999);
    return normalized;
  }

  private getSettlementWindow(date: Date, preferredCutoffDay: number) {
    const weekEnd = this.getUpcomingCutoff(date, preferredCutoffDay);
    const weekStart = new Date(weekEnd);
    weekStart.setUTCDate(weekEnd.getUTCDate() - 6);
    weekStart.setUTCHours(0, 0, 0, 0);

    return { weekStart, weekEnd, dueDate: weekEnd };
  }

  private getCutoffDayLabel(day: number) {
    return ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'][this.normalizeCutoffDay(day) - 1];
  }

  private async createLedgerEntry(params: {
    travelerId: string;
    kind: 'commission_accrual' | 'transfer_applied' | 'manual_adjustment';
    direction: 'debit' | 'credit';
    amount: number;
    description: string;
    balanceAfter?: number;
    commissionId?: string;
    transferId?: string;
    weeklySettlementId?: string;
    createdBy?: string;
    metadata?: Record<string, unknown>;
  }) {
    return this.prisma.travelerLedgerEntry.create({
      data: {
        travelerId: params.travelerId,
        kind: params.kind,
        direction: params.direction,
        amount: params.amount,
        balanceAfter: params.balanceAfter,
        description: params.description,
        commissionId: params.commissionId,
        transferId: params.transferId,
        weeklySettlementId: params.weeklySettlementId,
        createdBy: params.createdBy,
        metadata: params.metadata as Prisma.InputJsonValue | undefined,
      },
    });
  }

  async getTravelerLedger(travelerId: string) {
    const traveler = await this.prisma.travelerProfile.findUnique({
      where: { userId: travelerId },
      select: { currentDebt: true, preferredCutoffDay: true },
    });

    if (!traveler) {
      throw new NotFoundException('Perfil de viajero no encontrado.');
    }

    const entries = await this.prisma.travelerLedgerEntry.findMany({
      where: { travelerId },
      orderBy: [{ occurredAt: 'desc' }, { createdAt: 'desc' }],
      take: 100,
    });

    return {
      travelerId,
      currentDebt: Number(traveler.currentDebt),
      preferredCutoffDay: traveler.preferredCutoffDay,
      preferredCutoffLabel: this.getCutoffDayLabel(traveler.preferredCutoffDay),
      entries: entries.map((item) => ({
        ...item,
        amount: Number(item.amount),
        balanceAfter: item.balanceAfter == null ? null : Number(item.balanceAfter),
      })),
    };
  }

  private async getPricingHistory() {
    const logs = await this.prisma.auditLog.findMany({
      where: {
        entityType: 'pricing_settings',
        action: 'update',
      },
      include: {
        actor: {
          select: {
            fullName: true,
            email: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 8,
    });

    return logs.map((log) => ({
      id: log.id,
      actorId: log.actorId,
      actorName: log.actor?.fullName ?? null,
      actorEmail: log.actor?.email ?? null,
      createdAt: log.createdAt,
      payload: log.payload,
    }));
  }

  async getPricingSettings() {
    const settings = await this.prisma.pricingSettings.upsert({
      where: { id: 'default' },
      update: {},
      create: {
        id: 'default',
        commissionPerLb: 1.5,
        groundCommissionPercent: 0.04,
      },
    });

    const history = await this.getPricingHistory();

    return {
      ...settings,
      commissionPerLb: Number(settings.commissionPerLb),
      groundCommissionPercent: Number(settings.groundCommissionPercent),
      history,
    };
  }

  async updatePricingSettings(
    commissionPerLb: number,
    groundCommissionPercent: number,
    actorId?: string,
  ) {
    const previous = await this.prisma.pricingSettings.findUnique({
      where: { id: 'default' },
    });

    const settings = await this.prisma.pricingSettings.upsert({
      where: { id: 'default' },
      update: {
        commissionPerLb,
        groundCommissionPercent,
      },
      create: {
        id: 'default',
        commissionPerLb,
        groundCommissionPercent,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        actorId,
        entityType: 'pricing_settings',
        entityId: settings.id,
        action: 'update',
        payload: {
          previous: previous
            ? {
                commissionPerLb: Number(previous.commissionPerLb),
                groundCommissionPercent: Number(previous.groundCommissionPercent),
              }
            : null,
          next: {
            commissionPerLb: Number(settings.commissionPerLb),
            groundCommissionPercent: Number(settings.groundCommissionPercent),
          },
        },
      },
    });

    const history = await this.getPricingHistory();

    return {
      ...settings,
      commissionPerLb: Number(settings.commissionPerLb),
      groundCommissionPercent: Number(settings.groundCommissionPercent),
      history,
    };
  }

  async calculateCommissionAmount(shipment: Shipment) {
    const settings = await this.getPricingSettings();

    if (shipment.packageType === 'libra' && shipment.weightLb) {
      return Number(shipment.weightLb) * Number(settings.commissionPerLb);
    }

    return Number(shipment.declaredValue) * Number(settings.groundCommissionPercent);
  }

  async createCommissionForDeliveredShipment(shipment: Shipment) {
    if (!shipment.assignedTravelerId || shipment.status !== ShipmentStatus.delivered) {
      return null;
    }

    const existing = await this.prisma.travelerCommission.findUnique({
      where: { shipmentId: shipment.id },
    });

    if (existing) {
      return existing;
    }

    const generatedAt = new Date();
    const travelerProfile = await this.prisma.travelerProfile.findUnique({
      where: { userId: shipment.assignedTravelerId },
      select: { preferredCutoffDay: true, currentDebt: true },
    });
    const preferredCutoffDay = travelerProfile?.preferredCutoffDay ?? 4;
    const { dueDate, weekStart } = this.getSettlementWindow(generatedAt, preferredCutoffDay);
    const settlementWeek = weekStart;
    const commissionAmount = await this.calculateCommissionAmount(shipment);

    const commission = await this.prisma.travelerCommission.create({
      data: {
        shipmentId: shipment.id,
        travelerId: shipment.assignedTravelerId,
        commissionAmount,
        status: CommissionStatus.pending,
        generatedAt,
        dueDate,
        settlementWeek,
      },
    });

    await this.prisma.travelerProfile.updateMany({
      where: { userId: shipment.assignedTravelerId },
      data: {
        currentDebt: {
          increment: commissionAmount,
        },
      },
    });

    const settlement = await this.upsertWeeklySettlement(shipment.assignedTravelerId, generatedAt);
    const balanceAfter = Number(travelerProfile?.currentDebt ?? 0) + commissionAmount;

    await this.createLedgerEntry({
      travelerId: shipment.assignedTravelerId,
      kind: 'commission_accrual',
      direction: 'debit',
      amount: commissionAmount,
      balanceAfter,
      commissionId: commission.id,
      weeklySettlementId: settlement.id,
      description: `Comisión generada por envío ${shipment.id}`,
      metadata: { shipmentId: shipment.id },
    });

    runtimeObservability.recordBusinessEvent({
      type: 'commission_accrued',
      entityId: commission.id,
      actorId: shipment.assignedTravelerId,
      shipmentId: shipment.id,
      metadata: { amount: commissionAmount, weeklySettlementId: settlement.id },
    });

    return commission;
  }

  async upsertWeeklySettlement(travelerId: string, baseDate: Date) {
    const traveler = await this.prisma.travelerProfile.findUnique({
      where: { userId: travelerId },
      select: { preferredCutoffDay: true },
    });

    const preferredCutoffDay = traveler?.preferredCutoffDay ?? 4;
    const { weekStart, weekEnd, dueDate } = this.getSettlementWindow(baseDate, preferredCutoffDay);

    const pending = await this.prisma.travelerCommission.aggregate({
      where: {
        travelerId,
        status: { in: [CommissionStatus.pending, CommissionStatus.due, CommissionStatus.overdue] },
      },
      _sum: {
        commissionAmount: true,
      },
    });

    const totalPending = Number(pending._sum.commissionAmount ?? 0);

    return this.prisma.weeklySettlement.upsert({
      where: {
        travelerId_weekStart_weekEnd: {
          travelerId,
          weekStart,
          weekEnd,
        },
      },
      update: {
        totalPending,
        totalCommission: totalPending,
        dueDate,
        isOverdue: dueDate < new Date() && totalPending > 0,
        isBlocked: totalPending > 0 && dueDate < new Date(),
      },
      create: {
        travelerId,
        weekStart,
        weekEnd,
        dueDate,
        totalPending,
        totalCommission: totalPending,
        totalPaid: 0,
        isOverdue: dueDate < new Date() && totalPending > 0,
        isBlocked: totalPending > 0 && dueDate < new Date(),
      },
    });
  }

  async registerPayment(payload: RegisterCommissionPaymentDto) {
    const pendingCommissions = await this.prisma.travelerCommission.findMany({
      where: {
        travelerId: payload.travelerId,
        status: { in: [CommissionStatus.pending, CommissionStatus.due, CommissionStatus.overdue] },
      },
      orderBy: { generatedAt: 'asc' },
    });

    const totalPending = pendingCommissions.reduce(
      (sum, item) => sum + Number(item.commissionAmount),
      0,
    );

    const transfer = await this.prisma.transferPayment.create({
      data: {
        travelerId: payload.travelerId,
        bankReference: payload.bankReference,
        transferredAmount: payload.transferredAmount,
        status: payload.transferredAmount >= totalPending ? 'approved' : 'submitted',
      },
    });

    if (payload.transferredAmount >= totalPending && pendingCommissions.length > 0) {
      await this.prisma.travelerCommission.updateMany({
        where: {
          id: { in: pendingCommissions.map((item) => item.id) },
        },
        data: {
          status: CommissionStatus.paid,
          paidAt: new Date(),
        },
      });

      await this.prisma.travelerProfile.updateMany({
        where: { userId: payload.travelerId },
        data: {
          currentDebt: 0,
          status: TravelerStatus.verified,
          blockedReason: null,
        },
      });
    }

    await this.upsertWeeklySettlement(payload.travelerId, new Date());

    return {
      transfer,
      totalPending,
      autoReleased: payload.transferredAmount >= totalPending,
    };
  }

  async runWeeklyCutoff(runDateIso?: string) {
    const runDate = runDateIso ? new Date(runDateIso) : new Date();

    const overdueCommissions = await this.prisma.travelerCommission.findMany({
      where: {
        status: { in: [CommissionStatus.pending, CommissionStatus.due] },
        dueDate: { lte: runDate },
      },
    });

    const travelerIds = [...new Set(overdueCommissions.map((item) => item.travelerId))];

    if (overdueCommissions.length > 0) {
      await this.prisma.travelerCommission.updateMany({
        where: {
          id: { in: overdueCommissions.map((item) => item.id) },
        },
        data: {
          status: CommissionStatus.overdue,
        },
      });
    }

    for (const travelerId of travelerIds) {
      const debt = overdueCommissions
        .filter((item) => item.travelerId === travelerId)
        .reduce((sum, item) => sum + Number(item.commissionAmount), 0);

      await this.prisma.travelerProfile.updateMany({
        where: { userId: travelerId },
        data: {
          status: TravelerStatus.blocked_for_debt,
          currentDebt: debt,
          blockedReason: 'Comisiones semanales pendientes',
        },
      });

      await this.upsertWeeklySettlement(travelerId, runDate);
    }

    return {
      processedCommissions: overdueCommissions.length,
      blockedTravelers: travelerIds.length,
      runDate,
    };
  }

  async getTravelerSummary(travelerId: string) {
    const pricingSettings = await this.getPricingSettings();
    const traveler = await this.prisma.travelerProfile.findUnique({
      where: { userId: travelerId },
      select: { preferredCutoffDay: true, currentDebt: true, status: true },
    });

    if (!traveler) {
      throw new NotFoundException('Perfil de viajero no encontrado.');
    }

    const commissions = await this.prisma.travelerCommission.findMany({
      where: { travelerId },
      include: {
        shipment: {
          select: {
            packageType: true,
            weightLb: true,
            declaredValue: true,
            originCountryCode: true,
            destinationCountryCode: true,
          },
        },
      },
      orderBy: { generatedAt: 'desc' },
    });

    const totalPending = commissions
      .filter((item) => item.status !== CommissionStatus.paid)
      .reduce((sum, item) => sum + Number(item.commissionAmount), 0);

    const settlements = await this.prisma.weeklySettlement.findMany({
      where: { travelerId },
      orderBy: { weekEnd: 'desc' },
      take: 8,
    });

    const recentTransfers = await this.prisma.transferPayment.findMany({
      where: { travelerId },
      orderBy: { createdAt: 'desc' },
      take: 8,
    });

    const recentLedger = await this.prisma.travelerLedgerEntry.findMany({
      where: { travelerId },
      orderBy: [{ occurredAt: 'desc' }, { createdAt: 'desc' }],
      take: 12,
    });

    return {
      travelerId,
      totalPending,
      currentDebt: Number(traveler.currentDebt),
      travelerStatus: traveler.status,
      preferredCutoffDay: traveler.preferredCutoffDay,
      preferredCutoffLabel: this.getCutoffDayLabel(traveler.preferredCutoffDay),
      pricingSettings: {
        commissionPerLb: Number(pricingSettings.commissionPerLb),
        groundCommissionPercent: Number(pricingSettings.groundCommissionPercent),
      },
      recentTransfers: recentTransfers.map((item) => ({
        ...item,
        transferredAmount: Number(item.transferredAmount),
      })),
      settlements: settlements.map((item) => ({
        ...item,
        totalCommission: Number(item.totalCommission),
        totalPaid: Number(item.totalPaid),
        totalPending: Number(item.totalPending),
      })),
      ledger: recentLedger.map((item) => ({
        ...item,
        amount: Number(item.amount),
        balanceAfter: item.balanceAfter == null ? null : Number(item.balanceAfter),
      })),
      commissions: commissions.map((item) => ({
        ...item,
        commissionAmount: Number(item.commissionAmount),
        ruleType: item.shipment.packageType === 'libra' ? 'per_lb' : 'ground_percent',
        calculationBase:
          item.shipment.packageType === 'libra'
            ? Number(item.shipment.weightLb ?? 0)
            : Number(item.shipment.declaredValue),
        appliedRate:
          item.shipment.packageType === 'libra'
            ? Number(pricingSettings.commissionPerLb)
            : Number(pricingSettings.groundCommissionPercent),
      })),
    };
  }


  async createManualAdjustment(
    travelerId: string,
    payload: { direction: 'debit' | 'credit'; amount: number; description: string; weeklySettlementId?: string },
    requester: { sub: string; role: string },
  ) {
    if (!['admin', 'support'].includes(requester.role)) {
      throw new ForbiddenException('Solo admin o soporte puede registrar ajustes manuales.');
    }

    const traveler = await this.prisma.travelerProfile.findUnique({
      where: { userId: travelerId },
      select: { currentDebt: true },
    });

    if (!traveler) {
      throw new NotFoundException('Perfil de viajero no encontrado.');
    }

    const settlement = payload.weeklySettlementId
      ? await this.prisma.weeklySettlement.findUnique({ where: { id: payload.weeklySettlementId } })
      : await this.upsertWeeklySettlement(travelerId, new Date());

    if (!settlement) {
      throw new NotFoundException('Corte semanal no encontrado.');
    }

    if (settlement.travelerId !== travelerId) {
      throw new ForbiddenException('Ese corte no pertenece al viajero indicado.');
    }

    const nextDebt =
      payload.direction === 'debit'
        ? Number(traveler.currentDebt) + payload.amount
        : Math.max(0, Number(traveler.currentDebt) - payload.amount);

    await this.prisma.travelerProfile.update({
      where: { userId: travelerId },
      data: {
        currentDebt: nextDebt,
        status: nextDebt > 0 ? TravelerStatus.blocked_for_debt : TravelerStatus.verified,
        blockedReason: nextDebt > 0 ? 'Saldo pendiente operativo' : null,
      },
    });

    await this.prisma.weeklySettlement.update({
      where: { id: settlement.id },
      data:
        payload.direction === 'debit'
          ? {
              totalCommission: { increment: payload.amount },
              totalPending: { increment: payload.amount },
            }
          : {
              totalPaid: { increment: payload.amount },
              totalPending: Math.max(0, Number(settlement.totalPending) - payload.amount),
            },
    });

    const entry = await this.createLedgerEntry({
      travelerId,
      kind: 'manual_adjustment',
      direction: payload.direction,
      amount: payload.amount,
      balanceAfter: nextDebt,
      weeklySettlementId: settlement.id,
      createdBy: requester.sub,
      description: payload.description,
      metadata: { reason: payload.description },
    });

    await this.prisma.auditLog.create({
      data: {
        actorId: requester.sub,
        entityType: 'traveler_ledger_entry',
        entityId: entry.id,
        action: 'manual_adjustment_created',
        payload: {
          travelerId,
          weeklySettlementId: settlement.id,
          direction: payload.direction,
          amount: payload.amount,
          description: payload.description,
          balanceAfter: nextDebt,
        },
      },
    });

    runtimeObservability.recordBusinessEvent({
      type: 'manual_ledger_adjustment',
      entityId: entry.id,
      actorId: requester.sub,
      metadata: { travelerId, direction: payload.direction, amount: payload.amount },
    });

    return {
      entry: {
        ...entry,
        amount: Number(entry.amount),
        balanceAfter: entry.balanceAfter == null ? null : Number(entry.balanceAfter),
      },
      currentDebt: nextDebt,
    };
  }

  async recordApprovedTransferLedger(params: {
    travelerId: string;
    transferId: string;
    weeklySettlementId?: string | null;
    amount: number;
    balanceAfter: number;
    createdBy?: string;
    metadata?: Record<string, unknown>;
  }) {
    return this.createLedgerEntry({
      travelerId: params.travelerId,
      kind: 'transfer_applied',
      direction: 'credit',
      amount: params.amount,
      balanceAfter: params.balanceAfter,
      transferId: params.transferId,
      weeklySettlementId: params.weeklySettlementId ?? undefined,
      createdBy: params.createdBy,
      description: `Pago aplicado a deuda del traveler ${params.travelerId}`,
      metadata: params.metadata,
    });
  }

  async updateTravelerCutoffPreference(travelerId: string, preferredCutoffDay: number) {
    const normalizedDay = this.normalizeCutoffDay(preferredCutoffDay);

    const traveler = await this.prisma.travelerProfile.findUnique({
      where: { userId: travelerId },
    });

    if (!traveler) {
      throw new NotFoundException('Perfil de viajero no encontrado.');
    }

    const updated = await this.prisma.travelerProfile.update({
      where: { userId: travelerId },
      data: { preferredCutoffDay: normalizedDay },
    });

    await this.upsertWeeklySettlement(travelerId, new Date());

    return {
      preferredCutoffDay: updated.preferredCutoffDay,
      preferredCutoffLabel: this.getCutoffDayLabel(updated.preferredCutoffDay),
    };
  }

  async getTravelerCutoffPreference(travelerId: string) {
    const traveler = await this.prisma.travelerProfile.findUnique({
      where: { userId: travelerId },
      select: { preferredCutoffDay: true },
    });

    if (!traveler) {
      throw new NotFoundException('Perfil de viajero no encontrado.');
    }

    return {
      preferredCutoffDay: traveler.preferredCutoffDay,
      preferredCutoffLabel: this.getCutoffDayLabel(traveler.preferredCutoffDay),
    };
  }
}
