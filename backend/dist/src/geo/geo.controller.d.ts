import { GeoService } from './geo.service';
import { DetectCountryDto } from './dto/detect-country.dto';
export declare class GeoController {
    private readonly geoService;
    constructor(geoService: GeoService);
    detectCountry(body: DetectCountryDto): {
        detectedCountryCode: import("../common/constants/country-codes").SupportedCountry | null;
        supported: boolean;
    };
}
