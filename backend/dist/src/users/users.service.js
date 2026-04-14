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
exports.UsersService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../database/prisma/prisma.service");
let UsersService = class UsersService {
    constructor(prisma) {
        this.prisma = prisma;
    }
    async ensureUniqueUser(email, phone) {
        const existing = await this.prisma.user.findFirst({
            where: {
                OR: [{ email }, { phone }],
            },
        });
        if (existing) {
            throw new common_1.BadRequestException('Ya existe un usuario con ese correo o teléfono.');
        }
    }
    async createUser(payload) {
        await this.ensureUniqueUser(payload.email, payload.phone);
        return this.prisma.user.create({
            data: {
                role: payload.role,
                fullName: payload.fullName,
                email: payload.email,
                phone: payload.phone,
                passwordHash: payload.passwordHash,
                countryCode: payload.countryCode,
                detectedCountryCode: payload.detectedCountryCode,
                stateRegion: payload.stateRegion,
                city: payload.city,
                address: payload.address,
            },
            select: {
                id: true,
                role: true,
                fullName: true,
                email: true,
                phone: true,
                countryCode: true,
                detectedCountryCode: true,
                createdAt: true,
            },
        });
    }
    async findByEmail(email) {
        return this.prisma.user.findUnique({
            where: { email },
            include: {
                travelerProfile: {
                    include: {
                        routes: true,
                    },
                },
            },
        });
    }
    async findPublicById(id) {
        return this.prisma.user.findUnique({
            where: { id },
            select: {
                id: true,
                role: true,
                status: true,
                fullName: true,
                email: true,
                phone: true,
                countryCode: true,
                detectedCountryCode: true,
                phoneVerified: true,
                emailVerified: true,
                travelerProfile: true,
            },
        });
    }
    getBlueprint() {
        return {
            roles: ['customer', 'traveler', 'admin', 'support'],
            antiFraud: ['phone verification', 'country detection', 'audit logs'],
            protectedContactData: true,
        };
    }
};
exports.UsersService = UsersService;
exports.UsersService = UsersService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], UsersService);
//# sourceMappingURL=users.service.js.map