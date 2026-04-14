"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.TravelersModule = void 0;
const common_1 = require("@nestjs/common");
const travelers_controller_1 = require("./travelers.controller");
const notifications_module_1 = require("../notifications/notifications.module");
const travelers_service_1 = require("./travelers.service");
let TravelersModule = class TravelersModule {
};
exports.TravelersModule = TravelersModule;
exports.TravelersModule = TravelersModule = __decorate([
    (0, common_1.Module)({
        imports: [notifications_module_1.NotificationsModule],
        controllers: [travelers_controller_1.TravelersController],
        providers: [travelers_service_1.TravelersService],
        exports: [travelers_service_1.TravelersService],
    })
], TravelersModule);
//# sourceMappingURL=travelers.module.js.map