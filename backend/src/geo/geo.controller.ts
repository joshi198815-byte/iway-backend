import { Body, Controller, Post } from '@nestjs/common';
import { GeoService } from './geo.service';
import { DetectCountryDto } from './dto/detect-country.dto';

@Controller('geo')
export class GeoController {
  constructor(private readonly geoService: GeoService) {}

  @Post('detect-country')
  detectCountry(@Body() body: DetectCountryDto) {
    return this.geoService.detectCountry(body);
  }
}
