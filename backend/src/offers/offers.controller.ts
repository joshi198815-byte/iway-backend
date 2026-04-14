import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { OffersService } from './offers.service';
import { CreateOfferDto } from './dto/create-offer.dto';
import { AcceptOfferDto } from './dto/accept-offer.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)

@Controller('offers')
export class OffersController {
  constructor(private readonly offersService: OffersService) {}

  @Post()
  create(@Body() body: CreateOfferDto, @Req() req: any) {
    return this.offersService.create({
      ...body,
      travelerId: req.user.sub,
    });
  }

  @Get('shipment/:shipmentId')
  findByShipment(@Param('shipmentId') shipmentId: string) {
    return this.offersService.findByShipment(shipmentId);
  }

  @Post(':id/accept')
  accept(@Param('id') id: string, @Body() body: AcceptOfferDto, @Req() req: any) {
    return this.offersService.acceptOffer(id, {
      ...body,
      acceptedByCustomerId: req.user.sub,
    });
  }
}
