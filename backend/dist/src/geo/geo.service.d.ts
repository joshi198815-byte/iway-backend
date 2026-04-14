import { DetectCountryDto } from './dto/detect-country.dto';
import { ShipmentDirection, SupportedCountry } from '../common/constants/country-codes';
export declare class GeoService {
    normalizeCountryCode(countryCode?: string | null): SupportedCountry | null;
    detectCountry(payload: DetectCountryDto): {
        detectedCountryCode: SupportedCountry | null;
        supported: boolean;
    };
    resolveDirection(originCountryCode: string, destinationCountryCode: string): ShipmentDirection | null;
}
