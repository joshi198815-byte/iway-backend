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
exports.CommissionsController = void 0;
const common_1 = require("@nestjs/common");
const commissions_service_1 = require("./commissions.service");
const register_commission_payment_dto_1 = require("./dto/register-commission-payment.dto");
const run_weekly_cutoff_dto_1 = require("./dto/run-weekly-cutoff.dto");
const update_pricing_settings_dto_1 = require("./dto/update-pricing-settings.dto");
const update_cutoff_preference_dto_1 = require("./dto/update-cutoff-preference.dto");
const create_ledger_adjustment_dto_1 = require("./dto/create-ledger-adjustment.dto");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
let CommissionsController = class CommissionsController {
    constructor(commissionsService) {
        this.commissionsService = commissionsService;
    }
    registerPayment(body, req) {
        return this.commissionsService.registerPayment({
            ...body,
            travelerId: req.user.sub,
        });
    }
    runWeeklyCutoff(body, req) {
        if (!['admin', 'support'].includes(req.user.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede ejecutar el corte semanal.');
        }
        return this.commissionsService.runWeeklyCutoff(body.runDateIso);
    }
    getMyCutoffPreference(req) {
        return this.commissionsService.getTravelerCutoffPreference(req.user.sub);
    }
    updateMyCutoffPreference(body, req) {
        return this.commissionsService.updateTravelerCutoffPreference(req.user.sub, body.preferredCutoffDay);
    }
    getMyLedger(req) {
        return this.commissionsService.getTravelerLedger(req.user.sub);
    }
    getTravelerSummary(travelerId, req) {
        if (req.user.sub !== travelerId && !['admin', 'support'].includes(req.user.role)) {
            throw new common_1.ForbiddenException('No puedes ver el resumen de otro viajero.');
        }
        return this.commissionsService.getTravelerSummary(travelerId);
    }
    getTravelerLedger(travelerId, req) {
        if (req.user.sub !== travelerId && !['admin', 'support'].includes(req.user.role)) {
            throw new common_1.ForbiddenException('No puedes ver el ledger de otro viajero.');
        }
        return this.commissionsService.getTravelerLedger(travelerId);
    }
    createLedgerAdjustment(travelerId, body, req) {
        if (!['admin', 'support'].includes(req.user.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede registrar ajustes manuales.');
        }
        return this.commissionsService.createManualAdjustment(travelerId, body, req.user);
    }
    getPricingSettings(req) {
        if (!['admin', 'support'].includes(req.user.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede ver esta configuración.');
        }
        return this.commissionsService.getPricingSettings();
    }
    updatePricingSettings(body, req) {
        if (!['admin', 'support'].includes(req.user.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede editar esta configuración.');
        }
        return this.commissionsService.updatePricingSettings(body.commissionPerLb, body.groundCommissionPercent, req.user.sub);
    }
};
exports.CommissionsController = CommissionsController;
__decorate([
    (0, common_1.Post)('payments'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [register_commission_payment_dto_1.RegisterCommissionPaymentDto, Object]),
    __metadata("design:returntype", void 0)
], CommissionsController.prototype, "registerPayment", null);
__decorate([
    (0, common_1.Post)('weekly-cutoff'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [run_weekly_cutoff_dto_1.RunWeeklyCutoffDto, Object]),
    __metadata("design:returntype", void 0)
], CommissionsController.prototype, "runWeeklyCutoff", null);
__decorate([
    (0, common_1.Get)('me/cutoff-preference'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], CommissionsController.prototype, "getMyCutoffPreference", null);
__decorate([
    (0, common_1.Put)('me/cutoff-preference'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [update_cutoff_preference_dto_1.UpdateCutoffPreferenceDto, Object]),
    __metadata("design:returntype", void 0)
], CommissionsController.prototype, "updateMyCutoffPreference", null);
__decorate([
    (0, common_1.Get)('me/ledger'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], CommissionsController.prototype, "getMyLedger", null);
__decorate([
    (0, common_1.Get)('traveler/:travelerId/summary'),
    __param(0, (0, common_1.Param)('travelerId')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], CommissionsController.prototype, "getTravelerSummary", null);
__decorate([
    (0, common_1.Get)('traveler/:travelerId/ledger'),
    __param(0, (0, common_1.Param)('travelerId')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], CommissionsController.prototype, "getTravelerLedger", null);
__decorate([
    (0, common_1.Post)('traveler/:travelerId/ledger-adjustments'),
    __param(0, (0, common_1.Param)('travelerId')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, create_ledger_adjustment_dto_1.CreateLedgerAdjustmentDto, Object]),
    __metadata("design:returntype", void 0)
], CommissionsController.prototype, "createLedgerAdjustment", null);
__decorate([
    (0, common_1.Get)('settings'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], CommissionsController.prototype, "getPricingSettings", null);
__decorate([
    (0, common_1.Put)('settings'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [update_pricing_settings_dto_1.UpdatePricingSettingsDto, Object]),
    __metadata("design:returntype", void 0)
], CommissionsController.prototype, "updatePricingSettings", null);
exports.CommissionsController = CommissionsController = __decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('commissions'),
    __metadata("design:paramtypes", [commissions_service_1.CommissionsService])
], CommissionsController);
//# sourceMappingURL=commissions.controller.js.map