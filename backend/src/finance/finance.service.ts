import { Injectable } from '@nestjs/common';
import { CommissionStatus, ShipmentDirection, TransferStatus, TravelerStatus } from '@prisma/client';
import { PrismaService } from '../database/prisma/prisma.service';

type OverviewParams = {
  range?: string;
  from?: string;
  to?: string;
  country?: string;
  direction?: string;
};

type DebtorsParams = {
  limit?: string;
  country?: string;
  onlyOverdue?: string;
  onlyBlocked?: string;
  onlyPayoutHold?: string;
  sortBy?: string;
  sortDir?: string;
};

type SettlementsParams = {
  range?: string;
  from?: string;
  to?: string;
  country?: string;
  status?: string;
};

type CountriesParams = {
  range?: string;
  from?: string;
  to?: string;
};

type RevenueSeriesParams = {
  range?: string;
  from?: string;
  to?: string;
  granularity?: string;
  country?: string;
  direction?: string;
};

@Injectable()
export class FinanceService {
  constructor(private readonly prisma: PrismaService) {}

  private parseBoolean(value?: string) {
    return value === 'true' || value === '1';
  }

  private normalizeCountry(country?: string) {
    const normalized = country?.trim().toUpperCase();
    return normalized ? normalized : undefined;
  }

  private normalizeDirection(direction?: string): ShipmentDirection | undefined {
    if (direction === ShipmentDirection.gt_to_us || direction === ShipmentDirection.us_to_gt) {
      return direction;
    }

    return undefined;
  }

  private getDateRange(range?: string, from?: string, to?: string) {
    const now = new Date();

    if (range === 'custom' && from && to) {
      return {
        range: 'custom',
        from: new Date(from),
        to: new Date(to),
      };
    }

    const start = new Date(now);
    const end = new Date(now);

    switch (range) {
      case 'year':
        start.setUTCMonth(0, 1);
        start.setUTCHours(0, 0, 0, 0);
        end.setUTCMonth(11, 31);
        end.setUTCHours(23, 59, 59, 999);
        return { range: 'year', from: start, to: end };
      case 'month':
        start.setUTCDate(1);
        start.setUTCHours(0, 0, 0, 0);
        end.setUTCMonth(end.getUTCMonth() + 1, 0);
        end.setUTCHours(23, 59, 59, 999);
        return { range: 'month', from: start, to: end };
      case 'week': {
        const day = start.getUTCDay() || 7;
        start.setUTCDate(start.getUTCDate() - day + 1);
        start.setUTCHours(0, 0, 0, 0);
        end.setUTCDate(start.getUTCDate() + 6);
        end.setUTCHours(23, 59, 59, 999);
        return { range: 'week', from: start, to: end };
      }
      case 'today':
      default:
        start.setUTCHours(0, 0, 0, 0);
        end.setUTCHours(23, 59, 59, 999);
        return { range: 'today', from: start, to: end };
    }
  }

  private normalizeGranularity(granularity?: string) {
    if (granularity === 'week' || granularity === 'month') {
      return granularity;
    }

    return 'day';
  }

  private getBucketLabel(date: Date, granularity: string) {
    const year = date.getUTCFullYear();
    const month = `${date.getUTCMonth() + 1}`.padStart(2, '0');
    const day = `${date.getUTCDate()}`.padStart(2, '0');

    if (granularity === 'month') {
      return `${year}-${month}`;
    }

    if (granularity === 'week') {
      const start = new Date(date);
      const weekday = start.getUTCDay() || 7;
      start.setUTCDate(start.getUTCDate() - weekday + 1);
      const wYear = start.getUTCFullYear();
      const wMonth = `${start.getUTCMonth() + 1}`.padStart(2, '0');
      const wDay = `${start.getUTCDate()}`.padStart(2, '0');
      return `${wYear}-${wMonth}-${wDay}`;
    }

    return `${year}-${month}-${day}`;
  }

  async getOverview(params: OverviewParams) {
    const country = this.normalizeCountry(params.country);
    const direction = this.normalizeDirection(params.direction);
    const dateRange = this.getDateRange(params.range, params.from, params.to);

    const commissionWhere = {
      generatedAt: {
        gte: dateRange.from,
        lte: dateRange.to,
      },
      ...(country || direction
        ? {
            shipment: {
              ...(country
                ? {
                    OR: [
                      { originCountryCode: country },
                      { destinationCountryCode: country },
                    ],
                  }
                : {}),
              ...(direction ? { direction } : {}),
            },
          }
        : {}),
    };

    const paidCommissionWhere = {
      ...commissionWhere,
      status: CommissionStatus.paid,
    };

    const travelerProfileWhere = {
      currentDebt: { gt: 0 },
      ...(country
        ? {
            user: {
              OR: [{ countryCode: country }, { detectedCountryCode: country }],
            },
          }
        : {}),
    };

    const payoutHoldWhere = {
      payoutHoldEnabled: true,
      ...(country
        ? {
            user: {
              OR: [{ countryCode: country }, { detectedCountryCode: country }],
            },
          }
        : {}),
    };

    const overdueWhere = {
      status: CommissionStatus.overdue,
      ...(country || direction
        ? {
            shipment: {
              ...(country
                ? {
                    OR: [
                      { originCountryCode: country },
                      { destinationCountryCode: country },
                    ],
                  }
                : {}),
              ...(direction ? { direction } : {}),
            },
          }
        : {}),
    };

    const transferWhere = {
      createdAt: {
        gte: dateRange.from,
        lte: dateRange.to,
      },
      ...(country
        ? {
            traveler: {
              OR: [{ countryCode: country }, { detectedCountryCode: country }],
            },
          }
        : {}),
    };

    const [grossCommissionAgg, paidCommissionAgg, outstandingDebtAgg, overdueDebtAgg, travelersWithDebt, blockedTravelersWithDebt, payoutHoldTravelers, pendingTransfersAgg, approvedTransfersAgg, rejectedTransfersAgg] =
      await Promise.all([
        this.prisma.travelerCommission.aggregate({
          where: commissionWhere,
          _sum: { commissionAmount: true },
        }),
        this.prisma.travelerCommission.aggregate({
          where: paidCommissionWhere,
          _sum: { commissionAmount: true },
        }),
        this.prisma.travelerProfile.aggregate({
          where: travelerProfileWhere,
          _sum: { currentDebt: true },
        }),
        this.prisma.travelerCommission.aggregate({
          where: overdueWhere,
          _sum: { commissionAmount: true },
        }),
        this.prisma.travelerProfile.count({ where: travelerProfileWhere }),
        this.prisma.travelerProfile.count({
          where: {
            ...travelerProfileWhere,
            status: TravelerStatus.blocked_for_debt,
          },
        }),
        this.prisma.travelerProfile.count({ where: payoutHoldWhere }),
        this.prisma.transferPayment.aggregate({
          where: {
            ...transferWhere,
            status: TransferStatus.submitted,
          },
          _sum: { transferredAmount: true },
        }),
        this.prisma.transferPayment.aggregate({
          where: {
            ...transferWhere,
            status: TransferStatus.approved,
          },
          _sum: { transferredAmount: true },
        }),
        this.prisma.transferPayment.aggregate({
          where: {
            ...transferWhere,
            status: TransferStatus.rejected,
          },
          _sum: { transferredAmount: true },
        }),
      ]);

    return {
      range: dateRange.range,
      from: dateRange.from,
      to: dateRange.to,
      filters: {
        country: country ?? null,
        direction: direction ?? null,
      },
      grossCommission: Number(grossCommissionAgg._sum.commissionAmount ?? 0),
      commissionCollected: Number(paidCommissionAgg._sum.commissionAmount ?? 0),
      outstandingDebt: Number(outstandingDebtAgg._sum.currentDebt ?? 0),
      overdueDebt: Number(overdueDebtAgg._sum.commissionAmount ?? 0),
      travelersWithDebt,
      blockedTravelersWithDebt,
      payoutHoldTravelers,
      pendingTransfersAmount: Number(pendingTransfersAgg._sum.transferredAmount ?? 0),
      approvedTransfersAmount: Number(approvedTransfersAgg._sum.transferredAmount ?? 0),
      rejectedTransfersAmount: Number(rejectedTransfersAgg._sum.transferredAmount ?? 0),
    };
  }

  async getRevenueSeries(params: RevenueSeriesParams) {
    const country = this.normalizeCountry(params.country);
    const direction = this.normalizeDirection(params.direction);
    const granularity = this.normalizeGranularity(params.granularity);
    const dateRange = this.getDateRange(params.range, params.from, params.to);

    const commissions = await this.prisma.travelerCommission.findMany({
      where: {
        generatedAt: {
          gte: dateRange.from,
          lte: dateRange.to,
        },
        ...(country || direction
          ? {
              shipment: {
                ...(country
                  ? {
                      OR: [
                        { originCountryCode: country },
                        { destinationCountryCode: country },
                      ],
                    }
                  : {}),
                ...(direction ? { direction } : {}),
              },
            }
          : {}),
      },
      select: {
        generatedAt: true,
        commissionAmount: true,
        status: true,
      },
      orderBy: { generatedAt: 'asc' },
    });

    const buckets = new Map<string, { bucket: string; grossCommission: number; commissionCollected: number; newDebt: number }>();

    for (const commission of commissions) {
      const bucket = this.getBucketLabel(commission.generatedAt, granularity);
      if (!buckets.has(bucket)) {
        buckets.set(bucket, {
          bucket,
          grossCommission: 0,
          commissionCollected: 0,
          newDebt: 0,
        });
      }

      const entry = buckets.get(bucket)!;
      const amount = Number(commission.commissionAmount);
      entry.grossCommission += amount;
      if (commission.status === CommissionStatus.paid) {
        entry.commissionCollected += amount;
      }
    }

    for (const item of buckets.values()) {
      item.newDebt = Math.max(0, item.grossCommission - item.commissionCollected);
    }

    return {
      range: dateRange.range,
      from: dateRange.from,
      to: dateRange.to,
      granularity,
      filters: {
        country: country ?? null,
        direction: direction ?? null,
      },
      points: [...buckets.values()],
    };
  }

  async getCountries(params: CountriesParams) {
    const dateRange = this.getDateRange(params.range, params.from, params.to);

    const [shipments, profiles, transfers] = await Promise.all([
      this.prisma.shipment.findMany({
        where: {
          createdAt: {
            gte: dateRange.from,
            lte: dateRange.to,
          },
        },
        select: {
          originCountryCode: true,
          destinationCountryCode: true,
        },
      }),
      this.prisma.travelerProfile.findMany({
        where: { currentDebt: { gt: 0 } },
        select: {
          user: {
            select: {
              countryCode: true,
              detectedCountryCode: true,
            },
          },
        },
      }),
      this.prisma.transferPayment.findMany({
        where: {
          createdAt: {
            gte: dateRange.from,
            lte: dateRange.to,
          },
        },
        select: {
          traveler: {
            select: {
              countryCode: true,
              detectedCountryCode: true,
            },
          },
        },
      }),
    ]);

    const countries = new Set<string>();
    for (const shipment of shipments) {
      if (shipment.originCountryCode) countries.add(shipment.originCountryCode.toUpperCase());
      if (shipment.destinationCountryCode) countries.add(shipment.destinationCountryCode.toUpperCase());
    }
    for (const profile of profiles) {
      const country = profile.user.detectedCountryCode ?? profile.user.countryCode;
      if (country) countries.add(country.toUpperCase());
    }
    for (const transfer of transfers) {
      const country = transfer.traveler.detectedCountryCode ?? transfer.traveler.countryCode;
      if (country) countries.add(country.toUpperCase());
    }

    const items = await Promise.all(
      [...countries].sort().map(async (country) => {
        const [grossCommissionAgg, paidCommissionAgg, outstandingDebtAgg, travelersWithDebt, shipmentsCount, approvedTransfersAgg, rejectedTransfersAgg] =
          await Promise.all([
            this.prisma.travelerCommission.aggregate({
              where: {
                generatedAt: {
                  gte: dateRange.from,
                  lte: dateRange.to,
                },
                shipment: {
                  OR: [
                    { originCountryCode: country },
                    { destinationCountryCode: country },
                  ],
                },
              },
              _sum: { commissionAmount: true },
            }),
            this.prisma.travelerCommission.aggregate({
              where: {
                generatedAt: {
                  gte: dateRange.from,
                  lte: dateRange.to,
                },
                status: CommissionStatus.paid,
                shipment: {
                  OR: [
                    { originCountryCode: country },
                    { destinationCountryCode: country },
                  ],
                },
              },
              _sum: { commissionAmount: true },
            }),
            this.prisma.travelerProfile.aggregate({
              where: {
                currentDebt: { gt: 0 },
                user: {
                  OR: [{ countryCode: country }, { detectedCountryCode: country }],
                },
              },
              _sum: { currentDebt: true },
            }),
            this.prisma.travelerProfile.count({
              where: {
                currentDebt: { gt: 0 },
                user: {
                  OR: [{ countryCode: country }, { detectedCountryCode: country }],
                },
              },
            }),
            this.prisma.shipment.count({
              where: {
                createdAt: {
                  gte: dateRange.from,
                  lte: dateRange.to,
                },
                OR: [
                  { originCountryCode: country },
                  { destinationCountryCode: country },
                ],
              },
            }),
            this.prisma.transferPayment.aggregate({
              where: {
                createdAt: {
                  gte: dateRange.from,
                  lte: dateRange.to,
                },
                status: TransferStatus.approved,
                traveler: {
                  OR: [{ countryCode: country }, { detectedCountryCode: country }],
                },
              },
              _sum: { transferredAmount: true },
            }),
            this.prisma.transferPayment.aggregate({
              where: {
                createdAt: {
                  gte: dateRange.from,
                  lte: dateRange.to,
                },
                status: TransferStatus.rejected,
                traveler: {
                  OR: [{ countryCode: country }, { detectedCountryCode: country }],
                },
              },
              _sum: { transferredAmount: true },
            }),
          ]);

        return {
          country,
          grossCommission: Number(grossCommissionAgg._sum.commissionAmount ?? 0),
          commissionCollected: Number(paidCommissionAgg._sum.commissionAmount ?? 0),
          outstandingDebt: Number(outstandingDebtAgg._sum.currentDebt ?? 0),
          travelersWithDebt,
          shipmentsCount,
          approvedTransfersAmount: Number(approvedTransfersAgg._sum.transferredAmount ?? 0),
          rejectedTransfersAmount: Number(rejectedTransfersAgg._sum.transferredAmount ?? 0),
        };
      }),
    );

    return {
      range: dateRange.range,
      from: dateRange.from,
      to: dateRange.to,
      items,
    };
  }

  async getSettlements(params: SettlementsParams) {
    const country = this.normalizeCountry(params.country);
    const dateRange = this.getDateRange(params.range, params.from, params.to);
    const status = [TransferStatus.submitted, TransferStatus.approved, TransferStatus.rejected].includes(
      params.status as TransferStatus,
    )
      ? (params.status as TransferStatus)
      : undefined;

    const baseWhere = {
      createdAt: {
        gte: dateRange.from,
        lte: dateRange.to,
      },
      ...(country
        ? {
            traveler: {
              OR: [{ countryCode: country }, { detectedCountryCode: country }],
            },
          }
        : {}),
      ...(status ? { status } : {}),
    };

    const [submittedCount, approvedCount, rejectedCount, submittedAmountAgg, approvedAmountAgg, rejectedAmountAgg, items] =
      await Promise.all([
        this.prisma.transferPayment.count({
          where: {
            ...baseWhere,
            status: TransferStatus.submitted,
          },
        }),
        this.prisma.transferPayment.count({
          where: {
            ...baseWhere,
            status: TransferStatus.approved,
          },
        }),
        this.prisma.transferPayment.count({
          where: {
            ...baseWhere,
            status: TransferStatus.rejected,
          },
        }),
        this.prisma.transferPayment.aggregate({
          where: {
            ...baseWhere,
            status: TransferStatus.submitted,
          },
          _sum: { transferredAmount: true },
        }),
        this.prisma.transferPayment.aggregate({
          where: {
            ...baseWhere,
            status: TransferStatus.approved,
          },
          _sum: { transferredAmount: true },
        }),
        this.prisma.transferPayment.aggregate({
          where: {
            ...baseWhere,
            status: TransferStatus.rejected,
          },
          _sum: { transferredAmount: true },
        }),
        this.prisma.transferPayment.findMany({
          where: baseWhere,
          include: {
            traveler: {
              select: {
                id: true,
                fullName: true,
                email: true,
                phone: true,
                countryCode: true,
                detectedCountryCode: true,
              },
            },
          },
          orderBy: { createdAt: 'desc' },
          take: 100,
        }),
      ]);

    return {
      range: dateRange.range,
      from: dateRange.from,
      to: dateRange.to,
      filters: {
        country: country ?? null,
        status: status ?? null,
      },
      summary: {
        submittedCount,
        approvedCount,
        rejectedCount,
        submittedAmount: Number(submittedAmountAgg._sum.transferredAmount ?? 0),
        approvedAmount: Number(approvedAmountAgg._sum.transferredAmount ?? 0),
        rejectedAmount: Number(rejectedAmountAgg._sum.transferredAmount ?? 0),
      },
      items: items.map((item) => ({
        transferId: item.id,
        travelerId: item.travelerId,
        travelerName: item.traveler.fullName,
        travelerEmail: item.traveler.email,
        travelerPhone: item.traveler.phone,
        country: item.traveler.detectedCountryCode ?? item.traveler.countryCode ?? null,
        status: item.status,
        transferredAmount: Number(item.transferredAmount),
        bankReference: item.bankReference,
        weeklySettlementId: item.weeklySettlementId,
        reviewedBy: item.reviewedBy,
        reviewedAt: item.reviewedAt,
        createdAt: item.createdAt,
      })),
    };
  }

  async getDebtors(params: DebtorsParams) {
    const country = this.normalizeCountry(params.country);
    const limit = Math.min(Math.max(Number(params.limit || 50), 1), 200);
    const onlyOverdue = this.parseBoolean(params.onlyOverdue);
    const onlyBlocked = this.parseBoolean(params.onlyBlocked);
    const onlyPayoutHold = this.parseBoolean(params.onlyPayoutHold);
    const sortBy = ['currentDebt', 'overdueDebt', 'lastSettlementAt'].includes(params.sortBy ?? '')
      ? (params.sortBy as 'currentDebt' | 'overdueDebt' | 'lastSettlementAt')
      : 'currentDebt';
    const sortDir = params.sortDir === 'asc' ? 'asc' : 'desc';

    const profiles = await this.prisma.travelerProfile.findMany({
      where: {
        currentDebt: { gt: 0 },
        ...(onlyBlocked ? { status: TravelerStatus.blocked_for_debt } : {}),
        ...(onlyPayoutHold ? { payoutHoldEnabled: true } : {}),
        ...(country
          ? {
              user: {
                OR: [{ countryCode: country }, { detectedCountryCode: country }],
              },
            }
          : {}),
      },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            countryCode: true,
            detectedCountryCode: true,
          },
        },
      },
      take: 500,
    });

    const travelerIds = profiles.map((item) => item.userId);

    const [overdueAgg, settlements] = await Promise.all([
      this.prisma.travelerCommission.groupBy({
        by: ['travelerId'],
        where: {
          travelerId: { in: travelerIds.length > 0 ? travelerIds : ['__none__'] },
          status: CommissionStatus.overdue,
        },
        _sum: { commissionAmount: true },
      }),
      this.prisma.weeklySettlement.findMany({
        where: {
          travelerId: { in: travelerIds.length > 0 ? travelerIds : ['__none__'] },
        },
        orderBy: { weekEnd: 'desc' },
        select: {
          travelerId: true,
          weekEnd: true,
        },
      }),
    ]);

    const overdueMap = new Map(overdueAgg.map((item) => [item.travelerId, Number(item._sum.commissionAmount ?? 0)]));
    const settlementMap = new Map<string, Date>();
    for (const settlement of settlements) {
      if (!settlementMap.has(settlement.travelerId)) {
        settlementMap.set(settlement.travelerId, settlement.weekEnd);
      }
    }

    let items = profiles.map((profile) => ({
      travelerId: profile.userId,
      fullName: profile.user.fullName,
      email: profile.user.email,
      phone: profile.user.phone,
      country: profile.user.detectedCountryCode ?? profile.user.countryCode ?? null,
      travelerStatus: profile.status,
      currentDebt: Number(profile.currentDebt),
      overdueDebt: overdueMap.get(profile.userId) ?? 0,
      weeklyBlockEnabled: profile.weeklyBlockEnabled,
      payoutHoldEnabled: profile.payoutHoldEnabled,
      lastSettlementAt: settlementMap.get(profile.userId)?.toISOString() ?? null,
    }));

    if (onlyOverdue) {
      items = items.filter((item) => item.overdueDebt > 0);
    }

    items.sort((a, b) => {
      let left: number | string = a.currentDebt;
      let right: number | string = b.currentDebt;

      if (sortBy === 'overdueDebt') {
        left = a.overdueDebt;
        right = b.overdueDebt;
      }

      if (sortBy === 'lastSettlementAt') {
        left = a.lastSettlementAt ?? '';
        right = b.lastSettlementAt ?? '';
      }

      if (left < right) return sortDir === 'asc' ? -1 : 1;
      if (left > right) return sortDir === 'asc' ? 1 : -1;
      return 0;
    });

    const paged = items.slice(0, limit);

    return {
      filters: {
        country: country ?? null,
        onlyOverdue,
        onlyBlocked,
        onlyPayoutHold,
        sortBy,
        sortDir,
        limit,
      },
      total: items.length,
      items: paged,
    };
  }
}
