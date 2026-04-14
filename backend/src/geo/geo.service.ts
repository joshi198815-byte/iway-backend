import { Injectable } from '@nestjs/common';
import { DetectCountryDto } from './dto/detect-country.dto';
import { ShipmentDirection, SupportedCountry } from '../common/constants/country-codes';

@Injectable()
export class GeoService {
  normalizeCountryCode(countryCode?: string | null) {
    const normalized = countryCode?.trim().toUpperCase();

    if (
      normalized === SupportedCountry.Guatemala ||
      normalized === SupportedCountry.UnitedStates
    ) {
      return normalized;
    }

    return null;
  }

  detectCountry(payload: DetectCountryDto) {
    const normalized = this.normalizeCountryCode(payload.countryCode);

    return {
      detectedCountryCode: normalized,
      supported: Boolean(normalized),
    };
  }

  resolveDirection(originCountryCode: string, destinationCountryCode: string) {
    const origin = this.normalizeCountryCode(originCountryCode);
    const destination = this.normalizeCountryCode(destinationCountryCode);

    if (origin === SupportedCountry.Guatemala && destination === SupportedCountry.UnitedStates) {
      return ShipmentDirection.GtToUs;
    }

    if (origin === SupportedCountry.UnitedStates && destination === SupportedCountry.Guatemala) {
      return ShipmentDirection.UsToGt;
    }

    return null;
  }
}
