import { Body, Controller, ForbiddenException, Get, Param, Post, Put, Req, UseGuards } from '@nestjs/common';
import { TransfersService } from './transfers.service';
import { SubmitTransferDto } from './dto/submit-transfer.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ReviewTransferDto } from './dto/review-transfer.dto';

@UseGuards(JwtAuthGuard)
@Controller('transfers')
export class TransfersController {
  constructor(private readonly transfersService: TransfersService) {}

  @Post()
  submit(@Body() body: SubmitTransferDto, @Req() req: any) {
    return this.transfersService.submit(req.user.sub, body);
  }

  @Get('me')
  getMyTransfers(@Req() req: any) {
    return this.transfersService.getMyTransfers(req.user.sub);
  }

  @Get('me/payout-policy')
  getMyPayoutPolicy(@Req() req: any) {
    return this.transfersService.getPayoutPolicy(req.user.sub, req.user);
  }

  @Get('traveler/:travelerId/payout-policy')
  getTravelerPayoutPolicy(@Param('travelerId') travelerId: string, @Req() req: any) {
    if (!['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('Solo admin o soporte puede consultar esta política.');
    }

    return this.transfersService.getPayoutPolicy(travelerId, req.user);
  }

  @Get('review-queue')
  getReviewQueue(@Req() req: any) {
    if (!['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('Solo admin o soporte puede revisar transferencias.');
    }

    return this.transfersService.getReviewQueue(req.user);
  }

  @Put(':transferId/review')
  reviewTransfer(@Param('transferId') transferId: string, @Body() body: ReviewTransferDto, @Req() req: any) {
    if (!['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('Solo admin o soporte puede revisar transferencias.');
    }

    return this.transfersService.reviewTransfer(transferId, body, req.user);
  }
}
