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
exports.TransfersController = void 0;
const common_1 = require("@nestjs/common");
const transfers_service_1 = require("./transfers.service");
const submit_transfer_dto_1 = require("./dto/submit-transfer.dto");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const review_transfer_dto_1 = require("./dto/review-transfer.dto");
let TransfersController = class TransfersController {
    constructor(transfersService) {
        this.transfersService = transfersService;
    }
    submit(body, req) {
        return this.transfersService.submit(req.user.sub, body);
    }
    getMyTransfers(req) {
        return this.transfersService.getMyTransfers(req.user.sub);
    }
    getMyPayoutPolicy(req) {
        return this.transfersService.getPayoutPolicy(req.user.sub, req.user);
    }
    getTravelerPayoutPolicy(travelerId, req) {
        if (!['admin', 'support'].includes(req.user.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede consultar esta política.');
        }
        return this.transfersService.getPayoutPolicy(travelerId, req.user);
    }
    getReviewQueue(req) {
        if (!['admin', 'support'].includes(req.user.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede revisar transferencias.');
        }
        return this.transfersService.getReviewQueue(req.user);
    }
    reviewTransfer(transferId, body, req) {
        if (!['admin', 'support'].includes(req.user.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede revisar transferencias.');
        }
        return this.transfersService.reviewTransfer(transferId, body, req.user);
    }
};
exports.TransfersController = TransfersController;
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [submit_transfer_dto_1.SubmitTransferDto, Object]),
    __metadata("design:returntype", void 0)
], TransfersController.prototype, "submit", null);
__decorate([
    (0, common_1.Get)('me'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], TransfersController.prototype, "getMyTransfers", null);
__decorate([
    (0, common_1.Get)('me/payout-policy'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], TransfersController.prototype, "getMyPayoutPolicy", null);
__decorate([
    (0, common_1.Get)('traveler/:travelerId/payout-policy'),
    __param(0, (0, common_1.Param)('travelerId')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], TransfersController.prototype, "getTravelerPayoutPolicy", null);
__decorate([
    (0, common_1.Get)('review-queue'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], TransfersController.prototype, "getReviewQueue", null);
__decorate([
    (0, common_1.Put)(':transferId/review'),
    __param(0, (0, common_1.Param)('transferId')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, review_transfer_dto_1.ReviewTransferDto, Object]),
    __metadata("design:returntype", void 0)
], TransfersController.prototype, "reviewTransfer", null);
exports.TransfersController = TransfersController = __decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('transfers'),
    __metadata("design:paramtypes", [transfers_service_1.TransfersService])
], TransfersController);
//# sourceMappingURL=transfers.controller.js.map