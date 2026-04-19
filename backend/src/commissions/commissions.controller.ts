import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  Post,
  Put,
  Req,
  UseGuards,
} from '@nestjs/common';
import { CommissionsService } from './commissions.service';
import { RegisterCommissionPaymentDto } from './dto/register-commission-payment.dto';
import { RunWeeklyCutoffDto } from './dto/run-weekly-cutoff.dto';
import { UpdatePricingSettingsDto } from './dto/update-pricing-settings.dto';
import { UpdateCutoffPreferenceDto } from './dto/update-cutoff-preference.dto';
import { CreateLedgerAdjustmentDto } from './dto/create-ledger-adjustment.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)

@Controller('commissions')
export class CommissionsController {
  constructor(private readonly commissionsService: CommissionsService) {}

  @Post('payments')
  registerPayment(@Body() body: RegisterCommissionPaymentDto, @Req() req: any) {
    return this.commissionsService.registerPayment({
      ...body,
      travelerId: req.user.sub,
    });
  }

  @Post('weekly-cutoff')
  runWeeklyCutoff(@Body() body: RunWeeklyCutoffDto, @Req() req: any) {
    if (req.user.role !== 'admin') {
      throw new ForbiddenException('Solo admin puede ejecutar el corte semanal.');
    }

    return this.commissionsService.runWeeklyCutoff(body.runDateIso);
  }

  @Get('me/cutoff-preference')
  getMyCutoffPreference(@Req() req: any) {
    return this.commissionsService.getTravelerCutoffPreference(req.user.sub);
  }

  @Put('me/cutoff-preference')
  updateMyCutoffPreference(@Body() body: UpdateCutoffPreferenceDto, @Req() req: any) {
    return this.commissionsService.updateTravelerCutoffPreference(req.user.sub, body.preferredCutoffDay);
  }

  @Get('me/ledger')
  getMyLedger(@Req() req: any) {
    return this.commissionsService.getTravelerLedger(req.user.sub);
  }

  @Get('traveler/:travelerId/summary')
  getTravelerSummary(@Param('travelerId') travelerId: string, @Req() req: any) {
    if (req.user.sub !== travelerId && !['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('No puedes ver el resumen de otro viajero.');
    }

    return this.commissionsService.getTravelerSummary(travelerId);
  }

  @Get('traveler/:travelerId/ledger')
  getTravelerLedger(@Param('travelerId') travelerId: string, @Req() req: any) {
    if (req.user.sub !== travelerId && !['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('No puedes ver el ledger de otro viajero.');
    }

    return this.commissionsService.getTravelerLedger(travelerId);
  }

  @Post('traveler/:travelerId/ledger-adjustments')
  createLedgerAdjustment(@Param('travelerId') travelerId: string, @Body() body: CreateLedgerAdjustmentDto, @Req() req: any) {
    if (req.user.role !== 'admin') {
      throw new ForbiddenException('Solo admin puede registrar ajustes manuales.');
    }

    return this.commissionsService.createManualAdjustment(travelerId, body, req.user);
  }

  @Get('settings')
  getPricingSettings(@Req() req: any) {
    if (req.user.role !== 'admin') {
      throw new ForbiddenException('Solo admin puede ver esta configuración.');
    }

    return this.commissionsService.getPricingSettings();
  }

  @Put('settings')
  updatePricingSettings(@Body() body: UpdatePricingSettingsDto, @Req() req: any) {
    if (req.user.role !== 'admin') {
      throw new ForbiddenException('Solo admin puede editar esta configuración.');
    }

    return this.commissionsService.updatePricingSettings(
      body.commissionPerLb,
      body.groundCommissionPercent,
      req.user.sub,
    );
  }
}
