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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AntiFraudController = void 0;
const common_1 = require("@nestjs/common");
const anti_fraud_service_1 = require("./anti-fraud.service");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const create_manual_flag_dto_1 = require("./dto/create-manual-flag.dto");
let AntiFraudController = class AntiFraudController {
    constructor(antiFraudService) {
        this.antiFraudService = antiFraudService;
    }
    getRules() {
        return this.antiFraudService.getRules();
    }
    getUserSummary(userId, req) {
        if (req.user.sub !== userId && !['admin', 'support'].includes(req.user.role)) {
            throw new common_1.ForbiddenException('No tienes acceso a este resumen.');
        }
        return this.antiFraudService.getUserRiskSummary(userId);
    }
    getReviewQueue(req) {
        if (!['admin', 'support'].includes(req.user.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede ver la cola antifraude.');
        }
        return this.antiFraudService.listReviewQueue(req.user);
    }
    recomputeUserSummary(userId, req) {
        if (req.user.sub !== userId && !['admin', 'support'].includes(req.user.role)) {
            throw new common_1.ForbiddenException('No tienes acceso a este escaneo.');
        }
        return this.antiFraudService.getUserRiskSummary(userId);
    }
    createManualFlag(userId, body, req) {
        if (!['admin', 'support'].includes(req.user.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede crear flags manuales.');
        }
        return this.antiFraudService.createManualFlag({
            userId,
            actorId: req.user.sub,
            flagType: body.flagType,
            severity: body.severity,
            details: body.details,
        });
    }
};
exports.AntiFraudController = AntiFraudController;
__decorate([
    (0, common_1.Get)('rules'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], AntiFraudController.prototype, "getRules", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Get)('user/:userId/summary'),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], AntiFraudController.prototype, "getUserSummary", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Get)('review-queue'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], AntiFraudController.prototype, "getReviewQueue", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Post)('user/:userId/recompute'),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], AntiFraudController.prototype, "recomputeUserSummary", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Post)('user/:userId/flags'),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, create_manual_flag_dto_1.CreateManualFlagDto, Object]),
    __metadata("design:returntype", void 0)
], AntiFraudController.prototype, "createManualFlag", null);
exports.AntiFraudController = AntiFraudController = __decorate([
    (0, common_1.Controller)('anti-fraud'),
    __metadata("design:paramtypes", [anti_fraud_service_1.AntiFraudService])
], AntiFraudController);
//# sourceMappingURL=anti-fraud.controller.js.map