import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ShipmentsService } from './shipments.service';
import { CreateShipmentDto } from './dto/create-shipment.dto';
import { UpdateShipmentStatusDto } from './dto/update-shipment-status.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)

@Controller('shipments')
export class ShipmentsController {
  constructor(private readonly shipmentsService: ShipmentsService) {}

  @Post()
  create(@Body() body: CreateShipmentDto, @Req() req: any) {
    return this.shipmentsService.create({
      ...body,
      customerId: req.user.sub,
    });
  }

  @Get('available')
  findAvailable(@Req() req: any) {
    return this.shipmentsService.findAvailableForTraveler(req.user.sub, req.user.role);
  }

  @Get()
  findAll(@Req() req: any) {
    if (!['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('Solo admin o soporte puede ver todos los envíos.');
    }

    return this.shipmentsService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.shipmentsService.findOne(id);
  }

  @Patch(':id/status')
  updateStatus(@Param('id') id: string, @Body() body: UpdateShipmentStatusDto, @Req() req: any) {
    if (!['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('Solo admin o soporte puede actualizar estados.');
    }

    return this.shipmentsService.updateStatus(id, body);
  }
}
