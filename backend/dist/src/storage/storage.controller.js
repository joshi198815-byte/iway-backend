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
exports.StorageController = void 0;
const common_1 = require("@nestjs/common");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const storage_service_1 = require("./storage.service");
const upload_base64_dto_1 = require("./dto/upload-base64.dto");
let StorageController = class StorageController {
    constructor(storageService) {
        this.storageService = storageService;
    }
    getBlueprint() {
        return this.storageService.getUploadBlueprint();
    }
    uploadBase64(body, req) {
        if (body.bucket == 'transfer-proofs' && !['traveler', 'admin', 'support'].includes(req.user.role)) {
            throw new common_1.ForbiddenException('No tienes permiso para subir archivos a este bucket.');
        }
        return this.storageService.uploadBase64(body, req.user.sub);
    }
    async getProtectedFile(bucket, ownerId, fileName, req, res) {
        const absolutePath = await this.storageService.resolveProtectedFile({
            bucket,
            ownerId,
            fileName,
            requesterId: req.user.sub,
            requesterRole: req.user.role,
        });
        return res.sendFile(absolutePath);
    }
};
exports.StorageController = StorageController;
__decorate([
    (0, common_1.Get)('blueprint'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], StorageController.prototype, "getBlueprint", null);
__decorate([
    (0, common_1.Post)('upload-base64'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [upload_base64_dto_1.UploadBase64Dto, Object]),
    __metadata("design:returntype", void 0)
], StorageController.prototype, "uploadBase64", null);
__decorate([
    (0, common_1.Get)('file/:bucket/:ownerId/:fileName'),
    __param(0, (0, common_1.Param)('bucket')),
    __param(1, (0, common_1.Param)('ownerId')),
    __param(2, (0, common_1.Param)('fileName')),
    __param(3, (0, common_1.Req)()),
    __param(4, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, Object, Object]),
    __metadata("design:returntype", Promise)
], StorageController.prototype, "getProtectedFile", null);
exports.StorageController = StorageController = __decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('storage'),
    __metadata("design:paramtypes", [storage_service_1.StorageService])
], StorageController);
//# sourceMappingURL=storage.controller.js.map