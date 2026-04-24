import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  InternalServerErrorException,
  Logger,
  Param,
  Patch,
  Post,
  Req,
  UnauthorizedException,
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

  private readonly logger = new Logger(ShipmentsController.name);

  @Post()
  create(@Body() body: CreateShipmentDto, @Req() req: any) {
    return this.shipmentsService.create(body, req.user.sub);
  }

  @Get('available')
  findAvailable(@Req() req: any) {
    return this.handleFindAvailable(req);
  }

  @Get('opportunities')
  findAvailableAlias(@Req() req: any) {
    return this.handleFindAvailable(req);
  }

  private async handleFindAvailable(req: any) {
    try {
      const userId = req.user?.sub?.toString().trim();
      const role = req.user?.role?.toString().trim();

      if (!userId || !role) {
        throw new UnauthorizedException('No se pudo validar la sesión del viajero. Inicia sesión de nuevo.');
      }

      return await this.shipmentsService.findAvailableForTraveler(userId, role);
    } catch (error) {
      if (error instanceof UnauthorizedException || error instanceof ForbiddenException) {
        throw error;
      }

      const message = error instanceof Error ? error.message : 'Error desconocido';
      this.logger.error(`Error al cargar oportunidades para ${req.user?.sub ?? 'sin_usuario'}: ${message}`);
      throw new InternalServerErrorException('No se pudieron cargar las oportunidades del viajero. Revisa la sesión o los filtros operativos.');
    }
  }

  @Get()
  findAll(@Req() req: any) {
    if (!['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('Solo admin o soporte puede ver todos los envíos.');
    }

    return this.shipmentsService.findAll();
  }

  @Get('mine')
  findMine(@Req() req: any) {
    return this.shipmentsService.findMine(req.user);
  }

  @Get(':id')
  findOne(@Param('id') id: string, @Req() req: any) {
    return this.shipmentsService.findOne(id, req.user);
  }

  @Patch(':id/status')
  updateStatus(@Param('id') id: string, @Body() body: UpdateShipmentStatusDto, @Req() req: any) {
    return this.shipmentsService.updateStatus(id, body, req.user);
  }
}
