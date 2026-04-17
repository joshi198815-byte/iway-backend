import { Controller, ForbiddenException, Get, Query, Req, UseGuards } from '@nestjs/common';
import { FinanceService } from './finance.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('finance')
export class FinanceController {
  constructor(private readonly financeService: FinanceService) {}

  @Get('overview')
  getOverview(
    @Query('range') range: string | undefined,
    @Query('from') from: string | undefined,
    @Query('to') to: string | undefined,
    @Query('country') country: string | undefined,
    @Query('direction') direction: string | undefined,
    @Req() req: any,
  ) {
    if (!['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('Solo admin o soporte puede ver finanzas.');
    }

    return this.financeService.getOverview({ range, from, to, country, direction });
  }

  @Get('debtors')
  getDebtors(
    @Query('limit') limit: string | undefined,
    @Query('country') country: string | undefined,
    @Query('onlyOverdue') onlyOverdue: string | undefined,
    @Query('onlyBlocked') onlyBlocked: string | undefined,
    @Query('onlyPayoutHold') onlyPayoutHold: string | undefined,
    @Query('sortBy') sortBy: string | undefined,
    @Query('sortDir') sortDir: string | undefined,
    @Req() req: any,
  ) {
    if (!['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('Solo admin o soporte puede ver deudores.');
    }

    return this.financeService.getDebtors({
      limit,
      country,
      onlyOverdue,
      onlyBlocked,
      onlyPayoutHold,
      sortBy,
      sortDir,
    });
  }

  @Get('settlements')
  getSettlements(
    @Query('range') range: string | undefined,
    @Query('from') from: string | undefined,
    @Query('to') to: string | undefined,
    @Query('country') country: string | undefined,
    @Query('status') status: string | undefined,
    @Req() req: any,
  ) {
    if (!['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('Solo admin o soporte puede ver liquidaciones.');
    }

    return this.financeService.getSettlements({ range, from, to, country, status });
  }

  @Get('countries')
  getCountries(
    @Query('range') range: string | undefined,
    @Query('from') from: string | undefined,
    @Query('to') to: string | undefined,
    @Req() req: any,
  ) {
    if (!['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('Solo admin o soporte puede ver finanzas por país.');
    }

    return this.financeService.getCountries({ range, from, to });
  }
}
