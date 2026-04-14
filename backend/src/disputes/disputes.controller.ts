import { Body, Controller, Get, Param, Post, Put, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { DisputesService } from './disputes.service';
import { CreateDisputeDto } from './dto/create-dispute.dto';
import { ResolveDisputeDto } from './dto/resolve-dispute.dto';

@UseGuards(JwtAuthGuard)
@Controller('disputes')
export class DisputesController {
  constructor(private readonly disputesService: DisputesService) {}

  @Post()
  create(@Body() body: CreateDisputeDto, @Req() req: any) {
    return this.disputesService.create(body, req.user);
  }

  @Get('me')
  listMine(@Req() req: any) {
    return this.disputesService.listMine(req.user);
  }

  @Get('queue')
  getQueue(@Req() req: any) {
    return this.disputesService.getQueue(req.user);
  }

  @Put(':disputeId/resolve')
  resolve(@Param('disputeId') disputeId: string, @Body() body: ResolveDisputeDto, @Req() req: any) {
    return this.disputesService.resolve(disputeId, body, req.user);
  }
}
