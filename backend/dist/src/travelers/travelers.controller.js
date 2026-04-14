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
exports.TravelersController = void 0;
const common_1 = require("@nestjs/common");
const travelers_service_1 = require("./travelers.service");
const register_traveler_dto_1 = require("./dto/register-traveler.dto");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const review_traveler_dto_1 = require("./dto/review-traveler.dto");
const update_payout_hold_dto_1 = require("./dto/update-payout-hold.dto");
let TravelersController = class TravelersController {
    constructor(travelersService) {
        this.travelersService = travelersService;
    }
    register(body) {
        return this.travelersService.register(body);
    }
    getAllowedRoutes(travelerType) {
        return this.travelersService.getAllowedDirectionsByType(travelerType);
    }
    getMyVerificationSummary(req) {
        return this.travelersService.getVerificationSummary(req.user.sub, req.user);
    }
    getReviewQueue(req) {
        return this.travelersService.listReviewQueue(req.user);
    }
    runKycAnalysis(userId, req) {
        return this.travelersService.runKycAnalysis(userId, req.user);
    }
    updatePayoutHold(userId, body, req) {
        return this.travelersService.updatePayoutHold(userId, body, req.user);
    }
    reviewTraveler(userId, body, req) {
        return this.travelersService.reviewTraveler(userId, body, req.user);
    }
};
exports.TravelersController = TravelersController;
__decorate([
    (0, common_1.Post)('register'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [register_traveler_dto_1.RegisterTravelerDto]),
    __metadata("design:returntype", void 0)
], TravelersController.prototype, "register", null);
__decorate([
    (0, common_1.Get)('allowed-routes/:travelerType'),
    __param(0, (0, common_1.Param)('travelerType')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TravelersController.prototype, "getAllowedRoutes", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Get)('me/verification-summary'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], TravelersController.prototype, "getMyVerificationSummary", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Get)('review-queue'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], TravelersController.prototype, "getReviewQueue", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Post)(':userId/run-kyc-analysis'),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], TravelersController.prototype, "runKycAnalysis", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Post)(':userId/payout-hold'),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_payout_hold_dto_1.UpdatePayoutHoldDto, Object]),
    __metadata("design:returntype", void 0)
], TravelersController.prototype, "updatePayoutHold", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Post)(':userId/review'),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, review_traveler_dto_1.ReviewTravelerDto, Object]),
    __metadata("design:returntype", void 0)
], TravelersController.prototype, "reviewTraveler", null);
exports.TravelersController = TravelersController = __decorate([
    (0, common_1.Controller)('travelers'),
    __metadata("design:paramtypes", [travelers_service_1.TravelersService])
], TravelersController);
//# sourceMappingURL=travelers.controller.js.map