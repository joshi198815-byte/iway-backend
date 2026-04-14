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
exports.HealthService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../database/prisma/prisma.service");
let HealthService = class HealthService {
    constructor(prisma) {
        this.prisma = prisma;
    }
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
        }
        catch (error) {
            return {
                ok: false,
                latencyMs: Date.now() - startedAt,
                message: error instanceof Error ? error.message : 'database check failed',
            };
        }
    }
    async getBusinessMetrics() {
        const [totalUsers, totalCustomers, totalTravelers, totalAdmins, blockedUsers, pendingUsers, travelerPending, travelerVerified, travelerBlocked, travelerRejected, shipmentsPublished, shipmentsAssigned, shipmentsDelivered, shipmentsDisputed, offersPending, offersAccepted, transfersSubmitted, transfersApproved, transfersRejected, commissionsPending, commissionsOverdue, commissionsPaid,] = await Promise.all([
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
            this.prisma.shipment.count({ where: { status: 'published' } }),
            this.prisma.shipment.count({ where: { status: 'assigned' } }),
            this.prisma.shipment.count({ where: { status: 'delivered' } }),
            this.prisma.shipment.count({ where: { status: 'disputed' } }),
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
                published: shipmentsPublished,
                assigned: shipmentsAssigned,
                delivered: shipmentsDelivered,
                disputed: shipmentsDisputed,
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
};
exports.HealthService = HealthService;
exports.HealthService = HealthService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], HealthService);
//# sourceMappingURL=health.service.js.map