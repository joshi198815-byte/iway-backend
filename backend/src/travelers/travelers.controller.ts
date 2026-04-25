import { Body, Controller, ForbiddenException, Get, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { TravelersService } from './travelers.service';
import { RegisterTravelerDto } from './dto/register-traveler.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ReviewTravelerDto } from './dto/review-traveler.dto';
import { UpdatePayoutHoldDto } from './dto/update-payout-hold.dto';

@Controller('travelers')
export class TravelersController {
  constructor(private readonly travelersService: TravelersService) {}

  @Post('register')
  register(@Body() body: RegisterTravelerDto) {
    return this.travelersService.register(body);
  }

  @Get('allowed-routes/:travelerType')
  getAllowedRoutes(@Param('travelerType') travelerType: 'avion_ida_vuelta' | 'avion_tierra' | 'solo_tierra') {
    return this.travelersService.getAllowedDirectionsByType(travelerType);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/workspace')
  getMyWorkspace(@Req() req: any) {
    return this.travelersService.getWorkspace(req.user.sub, req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('me/workspace')
  updateMyWorkspace(
    @Body() body: { isOnline?: boolean; routes?: string[] },
    @Req() req: any,
  ) {
    return this.travelersService.updateWorkspace(req.user.sub, body, req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/verification-summary')
  getMyVerificationSummary(@Req() req: any) {
    return this.travelersService.getVerificationSummary(req.user.sub, req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/destinations')
  getMyDestinations(@Req() req: any) {
    return this.travelersService.getDestinations(req.user.sub, req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('me/destinations')
  updateMyDestinations(
    @Body() body: { destinations?: string[] },
    @Req() req: any,
  ) {
    return this.travelersService.updateDestinations(req.user.sub, body, req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/route-announcement')
  getMyRouteAnnouncement(@Req() req: any) {
    return this.travelersService.getLatestRouteAnnouncement(req.user.sub, req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/route-announcement')
  publishMyRouteAnnouncement(
    @Body() body: { message?: string; allowedProducts?: string[] | string; regions?: string[] | string },
    @Req() req: any,
  ) {
    return this.travelersService.publishRouteAnnouncement(req.user.sub, body, req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Get('review-queue')
  getReviewQueue(@Req() req: any) {
    if (req.user.role !== 'admin') {
      throw new ForbiddenException('Solo admin puede revisar viajeros.');
    }
    return this.travelersService.listReviewQueue(req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':userId/run-kyc-analysis')
  runKycAnalysis(@Param('userId') userId: string, @Req() req: any) {
    if (req.user.role !== 'admin') {
      throw new ForbiddenException('Solo admin puede ejecutar KYC.');
    }
    return this.travelersService.runKycAnalysis(userId, req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':userId/payout-hold')
  updatePayoutHold(@Param('userId') userId: string, @Body() body: UpdatePayoutHoldDto, @Req() req: any) {
    if (req.user.role !== 'admin') {
      throw new ForbiddenException('Solo admin puede gestionar payout hold.');
    }
    return this.travelersService.updatePayoutHold(userId, body, req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':userId/review')
  reviewTraveler(@Param('userId') userId: string, @Body() body: ReviewTravelerDto, @Req() req: any) {
    if (req.user.role !== 'admin') {
      throw new ForbiddenException('Solo admin puede revisar viajeros.');
    }
    return this.travelersService.reviewTraveler(userId, body, req.user);
  }
}
