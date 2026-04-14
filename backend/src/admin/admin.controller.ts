import { Controller, ForbiddenException, Get, Req, UseGuards } from '@nestjs/common';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('dashboard-blueprint')
  getDashboardBlueprint(@Req() req: any) {
    if (!['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('Solo admin o soporte puede ver este dashboard.');
    }

    return this.adminService.getDashboardBlueprint();
  }

  @Get('observability')
  getObservabilityDashboard(@Req() req: any) {
    if (!['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('Solo admin o soporte puede ver observabilidad.');
    }

    return this.adminService.getObservabilityDashboard();
  }
}
