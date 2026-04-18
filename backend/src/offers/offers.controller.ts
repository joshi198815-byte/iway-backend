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
  findByShipment(@Param('shipmentId') shipmentId: string, @Req() req: any) {
    return this.offersService.findByShipment(shipmentId, req.user);
  }

  @Post(':id/accept')
  accept(@Param('id') id: string, @Req() req: any) {
    return this.offersService.acceptOffer(id, {
      acceptedByCustomerId: req.user.sub,
    });
  }

  @Post(':id/reject')
  reject(@Param('id') id: string, @Req() req: any) {
    return this.offersService.rejectOffer(id, {
      rejectedByCustomerId: req.user.sub,
    });
  }
}
