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
exports.AuthService = void 0;
const common_1 = require("@nestjs/common");
const node_crypto_1 = require("node:crypto");
const jwt_1 = require("@nestjs/jwt");
const client_1 = require("@prisma/client");
const geo_service_1 = require("../geo/geo.service");
const storage_service_1 = require("../storage/storage.service");
const travelers_service_1 = require("../travelers/travelers.service");
const users_service_1 = require("../users/users.service");
const password_util_1 = require("../common/utils/password.util");
const anti_fraud_service_1 = require("../anti-fraud/anti-fraud.service");
const notifications_service_1 = require("../notifications/notifications.service");
const prisma_service_1 = require("../database/prisma/prisma.service");
const jobs_service_1 = require("../jobs/jobs.service");
let AuthService = class AuthService {
    constructor(usersService, travelersService, geoService, jwtService, storageService, antiFraudService, notificationsService, prisma, jobsService) {
        this.usersService = usersService;
        this.travelersService = travelersService;
        this.geoService = geoService;
        this.jwtService = jwtService;
        this.storageService = storageService;
        this.antiFraudService = antiFraudService;
        this.notificationsService = notificationsService;
        this.prisma = prisma;
        this.jobsService = jobsService;
    }
    onModuleInit() {
        this.jobsService.registerHandler('anti-fraud-scan', async (payload) => {
            const userId = typeof payload.userId === 'string' ? payload.userId : null;
            if (!userId) {
                throw new Error('missing_user_id');
            }
            await this.antiFraudService.buildUserRiskSignals(userId);
        });
    }
    async registerCustomer(payload) {
        const passwordHash = await (0, password_util_1.hashPassword)(payload.password);
        const detectedCountryCode = this.geoService.normalizeCountryCode(payload.countryCode);
        const user = await this.usersService.createUser({
            role: client_1.UserRole.customer,
            fullName: payload.fullName,
            email: payload.email.trim().toLowerCase(),
            phone: payload.phone.trim(),
            passwordHash,
            countryCode: detectedCountryCode ?? payload.countryCode,
            detectedCountryCode: detectedCountryCode ?? undefined,
            stateRegion: payload.stateRegion,
            city: payload.city,
            address: payload.address,
        });
        await this.jobsService.enqueue({
            name: 'anti-fraud-scan',
            payload: { userId: user.id, source: 'register_customer' },
            maxAttempts: 3,
            initialDelayMs: 250,
        });
        return {
            user,
            accessToken: this.jwtService.sign({ sub: user.id, role: user.role }),
        };
    }
    async registerTraveler(payload) {
        const passwordHash = await (0, password_util_1.hashPassword)(payload.password);
        const detectedCountryCode = this.geoService.normalizeCountryCode(payload.detectedCountryCode ?? payload.countryCode);
        const user = await this.usersService.createUser({
            role: client_1.UserRole.traveler,
            fullName: payload.fullName,
            email: payload.email.trim().toLowerCase(),
            phone: payload.phone.trim(),
            passwordHash,
            countryCode: detectedCountryCode ?? undefined,
            detectedCountryCode: detectedCountryCode ?? undefined,
            stateRegion: payload.stateRegion,
            city: payload.city,
            address: payload.address,
        });
        const documentUrl = payload.documentUrl
            ? payload.documentUrl
            : payload.documentBase64
                ? (await this.storageService.uploadBase64({
                    bucket: 'documents',
                    base64: payload.documentBase64,
                    fileName: `traveler-document-${payload.documentNumber}-${Date.now()}`,
                }, user.id)).url
                : undefined;
        const selfieUrl = payload.selfieUrl
            ? payload.selfieUrl
            : payload.selfieBase64
                ? (await this.storageService.uploadBase64({
                    bucket: 'documents',
                    base64: payload.selfieBase64,
                    fileName: `traveler-selfie-${payload.documentNumber}-${Date.now()}`,
                }, user.id)).url
                : undefined;
        const travelerProfile = await this.travelersService.createTravelerProfile({
            userId: user.id,
            travelerType: payload.travelerType,
            documentNumber: payload.documentNumber,
            documentUrl,
            selfieUrl,
            detectedCountryCode: detectedCountryCode ?? undefined,
        });
        const travelerFiles = [documentUrl, selfieUrl].filter((value) => value != null);
        if (travelerFiles.length > 0) {
            await this.storageService.attachFilesToEntity({
                ownerId: user.id,
                urls: travelerFiles,
                linkedEntityType: 'traveler_profile',
                linkedEntityId: travelerProfile.id,
                purpose: 'identity_verification',
            });
        }
        await this.jobsService.enqueue({
            name: 'anti-fraud-scan',
            payload: { userId: user.id, source: 'register_traveler' },
            maxAttempts: 3,
            initialDelayMs: 250,
        });
        return {
            user,
            travelerProfile,
            accessToken: this.jwtService.sign({ sub: user.id, role: user.role }),
        };
    }
    hashVerificationCode(code) {
        return (0, node_crypto_1.createHash)('sha256').update(code).digest('hex');
    }
    async requestVerificationCode(userId, channel) {
        const user = await this.usersService.findPublicById(userId);
        if (!user) {
            throw new common_1.UnauthorizedException('Sesión inválida.');
        }
        const alreadyVerified = channel === 'phone' ? user.phoneVerified : user.emailVerified;
        if (alreadyVerified) {
            return { channel, alreadyVerified: true };
        }
        await this.prisma.verificationCode.updateMany({
            where: { userId, channel, consumedAt: null },
            data: { consumedAt: new Date() },
        });
        const code = (0, node_crypto_1.randomInt)(100000, 1000000).toString();
        await this.prisma.verificationCode.create({
            data: {
                userId,
                channel,
                codeHash: this.hashVerificationCode(code),
                expiresAt: new Date(Date.now() + 10 * 60 * 1000),
            },
        });
        await this.notificationsService.sendPush(userId, channel === 'phone' ? 'Código de verificación de teléfono' : 'Código de verificación de correo', `Tu código iWay es ${code}. Vence en 10 minutos.`, 'contact_verification');
        return { channel, sent: true, expiresInMinutes: 10 };
    }
    async verifyContactCode(userId, channel, code) {
        const verification = await this.prisma.verificationCode.findFirst({
            where: { userId, channel, consumedAt: null },
            orderBy: { createdAt: 'desc' },
        });
        if (!verification || verification.expiresAt.getTime() < Date.now()) {
            throw new common_1.BadRequestException('El código ya venció o no existe.');
        }
        if (verification.codeHash !== this.hashVerificationCode(code.trim())) {
            await this.prisma.verificationCode.update({
                where: { id: verification.id },
                data: { attempts: verification.attempts + 1 },
            });
            throw new common_1.BadRequestException('Código inválido.');
        }
        await this.prisma.$transaction([
            this.prisma.verificationCode.update({
                where: { id: verification.id },
                data: { consumedAt: new Date() },
            }),
            this.prisma.user.update({
                where: { id: userId },
                data: channel === 'phone' ? { phoneVerified: true } : { emailVerified: true },
            }),
        ]);
        return this.me(userId);
    }
    async me(userId) {
        const user = await this.usersService.findPublicById(userId);
        if (!user) {
            throw new common_1.UnauthorizedException('Sesión inválida.');
        }
        return {
            user: {
                id: user.id,
                role: user.role,
                status: user.status,
                fullName: user.fullName,
                email: user.email,
                phone: user.phone,
                detectedCountryCode: user.detectedCountryCode,
                phoneVerified: user.phoneVerified,
                emailVerified: user.emailVerified,
                travelerProfile: user.travelerProfile,
            },
        };
    }
    async login(payload) {
        const user = await this.usersService.findByEmail(payload.email.trim().toLowerCase());
        if (!user) {
            throw new common_1.UnauthorizedException('Credenciales inválidas.');
        }
        const passwordValid = await (0, password_util_1.verifyPassword)(payload.password, user.passwordHash);
        if (!passwordValid) {
            throw new common_1.UnauthorizedException('Credenciales inválidas.');
        }
        if (user.role === client_1.UserRole.traveler &&
            user.travelerProfile?.status === 'blocked_for_debt') {
            throw new common_1.BadRequestException('Tu cuenta está bloqueada por comisiones pendientes.');
        }
        return {
            accessToken: this.jwtService.sign({ sub: user.id, role: user.role }),
            user: {
                id: user.id,
                role: user.role,
                status: user.status,
                fullName: user.fullName,
                email: user.email,
                phone: user.phone,
                detectedCountryCode: user.detectedCountryCode,
                phoneVerified: user.phoneVerified,
                emailVerified: user.emailVerified,
                travelerProfile: user.travelerProfile,
            },
        };
    }
};
exports.AuthService = AuthService;
exports.AuthService = AuthService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [users_service_1.UsersService,
        travelers_service_1.TravelersService,
        geo_service_1.GeoService,
        jwt_1.JwtService,
        storage_service_1.StorageService,
        anti_fraud_service_1.AntiFraudService,
        notifications_service_1.NotificationsService,
        prisma_service_1.PrismaService,
        jobs_service_1.JobsService])
], AuthService);
//# sourceMappingURL=auth.service.js.map