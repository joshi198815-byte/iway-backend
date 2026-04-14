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
exports.TrackingController = void 0;
const common_1 = require("@nestjs/common");
const tracking_service_1 = require("./tracking.service");
const update_tracking_dto_1 = require("./dto/update-tracking.dto");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
let TrackingController = class TrackingController {
    constructor(trackingService) {
        this.trackingService = trackingService;
    }
    update(body, req) {
        return this.trackingService.update({
            ...body,
            travelerId: req.user.sub,
        }, req.user);
    }
    getLatest(shipmentId, req) {
        return this.trackingService.getLatestLocation(shipmentId, req.user);
    }
    getTimeline(shipmentId, req) {
        return this.trackingService.getTimeline(shipmentId, req.user);
    }
    getEta(shipmentId, req) {
        return this.trackingService.getEta(shipmentId, req.user);
    }
    getRoute(shipmentId, req) {
        return this.trackingService.getRoute(shipmentId, req.user);
    }
};
exports.TrackingController = TrackingController;
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [update_tracking_dto_1.UpdateTrackingDto, Object]),
    __metadata("design:returntype", void 0)
], TrackingController.prototype, "update", null);
__decorate([
    (0, common_1.Get)('shipment/:shipmentId/latest'),
    __param(0, (0, common_1.Param)('shipmentId')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], TrackingController.prototype, "getLatest", null);
__decorate([
    (0, common_1.Get)('shipment/:shipmentId/timeline'),
    __param(0, (0, common_1.Param)('shipmentId')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], TrackingController.prototype, "getTimeline", null);
__decorate([
    (0, common_1.Get)('shipment/:shipmentId/eta'),
    __param(0, (0, common_1.Param)('shipmentId')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], TrackingController.prototype, "getEta", null);
__decorate([
    (0, common_1.Get)('shipment/:shipmentId/route'),
    __param(0, (0, common_1.Param)('shipmentId')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], TrackingController.prototype, "getRoute", null);
exports.TrackingController = TrackingController = __decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('tracking'),
    __metadata("design:paramtypes", [tracking_service_1.TrackingService])
], TrackingController);
//# sourceMappingURL=tracking.controller.js.map