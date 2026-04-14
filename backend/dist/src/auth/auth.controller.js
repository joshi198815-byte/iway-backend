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
exports.AuthController = void 0;
const common_1 = require("@nestjs/common");
const auth_service_1 = require("./auth.service");
const login_dto_1 = require("./dto/login.dto");
const register_customer_dto_1 = require("./dto/register-customer.dto");
const register_traveler_auth_dto_1 = require("./dto/register-traveler-auth.dto");
const jwt_auth_guard_1 = require("./jwt-auth.guard");
const request_verification_code_dto_1 = require("./dto/request-verification-code.dto");
const verify_contact_code_dto_1 = require("./dto/verify-contact-code.dto");
let AuthController = class AuthController {
    constructor(authService) {
        this.authService = authService;
    }
    registerCustomer(body) {
        return this.authService.registerCustomer(body);
    }
    registerTraveler(body) {
        return this.authService.registerTraveler(body);
    }
    login(body) {
        return this.authService.login(body);
    }
    requestVerificationCode(body, req) {
        return this.authService.requestVerificationCode(req.user.sub, body.channel);
    }
    verifyContact(body, req) {
        return this.authService.verifyContactCode(req.user.sub, body.channel, body.code);
    }
    me(req) {
        return this.authService.me(req.user.sub);
    }
};
exports.AuthController = AuthController;
__decorate([
    (0, common_1.Post)('register/customer'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [register_customer_dto_1.RegisterCustomerDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "registerCustomer", null);
__decorate([
    (0, common_1.Post)('register/traveler'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [register_traveler_auth_dto_1.RegisterTravelerAuthDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "registerTraveler", null);
__decorate([
    (0, common_1.Post)('login'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [login_dto_1.LoginDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "login", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Post)('verification-code'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [request_verification_code_dto_1.RequestVerificationCodeDto, Object]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "requestVerificationCode", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Post)('verify-contact'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [verify_contact_code_dto_1.VerifyContactCodeDto, Object]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "verifyContact", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Get)('me'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "me", null);
exports.AuthController = AuthController = __decorate([
    (0, common_1.Controller)('auth'),
    __metadata("design:paramtypes", [auth_service_1.AuthService])
], AuthController);
//# sourceMappingURL=auth.controller.js.map