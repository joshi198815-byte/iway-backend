"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const health_module_1 = require("./health/health.module");
const database_module_1 = require("./database/database.module");
const auth_module_1 = require("./auth/auth.module");
const users_module_1 = require("./users/users.module");
const travelers_module_1 = require("./travelers/travelers.module");
const geo_module_1 = require("./geo/geo.module");
const shipments_module_1 = require("./shipments/shipments.module");
const offers_module_1 = require("./offers/offers.module");
const chat_module_1 = require("./chat/chat.module");
const tracking_module_1 = require("./tracking/tracking.module");
const ratings_module_1 = require("./ratings/ratings.module");
const notifications_module_1 = require("./notifications/notifications.module");
const commissions_module_1 = require("./commissions/commissions.module");
const transfers_module_1 = require("./transfers/transfers.module");
const anti_fraud_module_1 = require("./anti-fraud/anti-fraud.module");
const admin_module_1 = require("./admin/admin.module");
const audit_module_1 = require("./audit/audit.module");
const storage_module_1 = require("./storage/storage.module");
const jobs_module_1 = require("./jobs/jobs.module");
const realtime_module_1 = require("./realtime/realtime.module");
const disputes_module_1 = require("./disputes/disputes.module");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            config_1.ConfigModule.forRoot({ isGlobal: true }),
            health_module_1.HealthModule,
            database_module_1.DatabaseModule,
            auth_module_1.AuthModule,
            users_module_1.UsersModule,
            travelers_module_1.TravelersModule,
            geo_module_1.GeoModule,
            shipments_module_1.ShipmentsModule,
            offers_module_1.OffersModule,
            chat_module_1.ChatModule,
            tracking_module_1.TrackingModule,
            ratings_module_1.RatingsModule,
            notifications_module_1.NotificationsModule,
            commissions_module_1.CommissionsModule,
            transfers_module_1.TransfersModule,
            anti_fraud_module_1.AntiFraudModule,
            admin_module_1.AdminModule,
            audit_module_1.AuditModule,
            storage_module_1.StorageModule,
            jobs_module_1.JobsModule,
            realtime_module_1.RealtimeModule,
            disputes_module_1.DisputesModule,
        ],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map