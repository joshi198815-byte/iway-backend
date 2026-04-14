import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { TrackingService } from './tracking.service';
import { UpdateTrackingDto } from './dto/update-tracking.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)

@Controller('tracking')
export class TrackingController {
  constructor(private readonly trackingService: TrackingService) {}

  @Post()
  update(@Body() body: UpdateTrackingDto, @Req() req: any) {
    return this.trackingService.update(
      {
        ...body,
        travelerId: req.user.sub,
      },
      req.user,
    );
  }

  @Get('shipment/:shipmentId/latest')
  getLatest(@Param('shipmentId') shipmentId: string, @Req() req: any) {
    return this.trackingService.getLatestLocation(shipmentId, req.user);
  }

  @Get('shipment/:shipmentId/timeline')
  getTimeline(@Param('shipmentId') shipmentId: string, @Req() req: any) {
    return this.trackingService.getTimeline(shipmentId, req.user);
  }

  @Get('shipment/:shipmentId/eta')
  getEta(@Param('shipmentId') shipmentId: string, @Req() req: any) {
    return this.trackingService.getEta(shipmentId, req.user);
  }

  @Get('shipment/:shipmentId/route')
  getRoute(@Param('shipmentId') shipmentId: string, @Req() req: any) {
    return this.trackingService.getRoute(shipmentId, req.user);
  }
}
