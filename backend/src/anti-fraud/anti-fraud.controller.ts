import { Body, Controller, ForbiddenException, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { AntiFraudService } from './anti-fraud.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateManualFlagDto } from './dto/create-manual-flag.dto';

@Controller('anti-fraud')
export class AntiFraudController {
  constructor(private readonly antiFraudService: AntiFraudService) {}

  @Get('rules')
  getRules() {
    return this.antiFraudService.getRules();
  }

  @UseGuards(JwtAuthGuard)
  @Get('user/:userId/summary')
  getUserSummary(@Param('userId') userId: string, @Req() req: any) {
    if (req.user.sub !== userId && !['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('No tienes acceso a este resumen.');
    }

    return this.antiFraudService.getUserRiskSummary(userId);
  }

  @UseGuards(JwtAuthGuard)
  @Get('review-queue')
  getReviewQueue(@Req() req: any) {
    if (!['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('Solo admin o soporte puede ver la cola antifraude.');
    }

    return this.antiFraudService.listReviewQueue(req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Post('user/:userId/recompute')
  recomputeUserSummary(@Param('userId') userId: string, @Req() req: any) {
    if (req.user.sub !== userId && !['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('No tienes acceso a este escaneo.');
    }

    return this.antiFraudService.getUserRiskSummary(userId);
  }

  @UseGuards(JwtAuthGuard)
  @Post('user/:userId/flags')
  createManualFlag(@Param('userId') userId: string, @Body() body: CreateManualFlagDto, @Req() req: any) {
    if (!['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('Solo admin o soporte puede crear flags manuales.');
    }

    return this.antiFraudService.createManualFlag({
      userId,
      actorId: req.user.sub,
      flagType: body.flagType,
      severity: body.severity,
      details: body.details,
    });
  }
}
