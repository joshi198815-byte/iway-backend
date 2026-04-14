"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.GeoService = void 0;
const common_1 = require("@nestjs/common");
const country_codes_1 = require("../common/constants/country-codes");
let GeoService = class GeoService {
    normalizeCountryCode(countryCode) {
        const normalized = countryCode?.trim().toUpperCase();
        if (normalized === country_codes_1.SupportedCountry.Guatemala ||
            normalized === country_codes_1.SupportedCountry.UnitedStates) {
            return normalized;
        }
        return null;
    }
    detectCountry(payload) {
        const normalized = this.normalizeCountryCode(payload.countryCode);
        return {
            detectedCountryCode: normalized,
            supported: Boolean(normalized),
        };
    }
    resolveDirection(originCountryCode, destinationCountryCode) {
        const origin = this.normalizeCountryCode(originCountryCode);
        const destination = this.normalizeCountryCode(destinationCountryCode);
        if (origin === country_codes_1.SupportedCountry.Guatemala && destination === country_codes_1.SupportedCountry.UnitedStates) {
            return country_codes_1.ShipmentDirection.GtToUs;
        }
        if (origin === country_codes_1.SupportedCountry.UnitedStates && destination === country_codes_1.SupportedCountry.Guatemala) {
            return country_codes_1.ShipmentDirection.UsToGt;
        }
        return null;
    }
};
exports.GeoService = GeoService;
exports.GeoService = GeoService = __decorate([
    (0, common_1.Injectable)()
], GeoService);
//# sourceMappingURL=geo.service.js.map