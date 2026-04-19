import { Body, Controller, ForbiddenException, Get, Param, Put, Req, UseGuards } from '@nestjs/common';
import { PrismaService } from '../database/prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('content')
export class ContentController {
  constructor(private readonly prisma: PrismaService) {}

  private async resolveBannerFeed(key: 'home' | 'traveler', fallback: Array<Record<string, unknown>>) {
    const latest = await this.prisma.auditLog.findFirst({
      where: {
        entityType: 'content_banner_feed',
        entityId: key,
        action: 'content_banner_feed_updated',
      },
      orderBy: { createdAt: 'desc' },
    });

    const payload = latest?.payload as Record<string, unknown> | null | undefined;
    const items = payload?.items;
    if (!Array.isArray(items)) {
      return fallback;
    }

    return items
      .filter((item): item is Record<string, unknown> => Boolean(item && typeof item === 'object'))
      .map((item, index) => ({
        id: item.id?.toString() ?? `${key}-${index + 1}`,
        title: item.title?.toString() ?? '',
        subtitle: item.subtitle?.toString() ?? '',
        accent: item.accent?.toString() ?? '#59D38C',
        mediaUrl: item.mediaUrl?.toString() ?? null,
        mediaType: item.mediaType?.toString() ?? 'image',
      }));
  }

  @Get('home-banners')
  getHomeBanners() {
    return this.resolveBannerFeed('home', [
      {
        'id': 'promo-1',
        'title': 'Envía esta semana con seguimiento en tiempo real',
        'subtitle': 'Publica tu envío, recibe ofertas y mira cada etapa sin salir del dashboard.',
        'accent': '#59D38C',
        'mediaUrl': null,
        'mediaType': 'image',
      },
      {
        'id': 'promo-2',
        'title': 'Seguro opcional para tus paquetes',
        'subtitle': 'Activa cobertura desde el formulario y evita sorpresas en ruta.',
        'accent': '#FFD27A',
        'mediaUrl': null,
        'mediaType': 'image',
      },
      {
        'id': 'promo-3',
        'title': 'Destinatarios guardados en USA',
        'subtitle': 'Reutiliza direcciones reales con estado, ciudad y Google Places.',
        'accent': '#8AB4FF',
        'mediaUrl': null,
        'mediaType': 'image',
      },
    ]);
  }

  @Get('traveler-banners')
  getTravelerBanners() {
    return this.resolveBannerFeed('traveler', [
      {
        'id': 'traveler-1',
        'title': 'Activa tu jornada y toma pedidos de tu ruta',
        'subtitle': 'Cuando estás en línea, las oportunidades compatibles llegan directo a tu panel.',
        'accent': '#59D38C',
        'mediaUrl': null,
        'mediaType': 'image',
      },
      {
        'id': 'traveler-2',
        'title': 'Reporta tus pagos y mantén tu wallet al día',
        'subtitle': 'Sube el comprobante para que Admin valide tu pago y libere tu deuda pendiente.',
        'accent': '#FFD27A',
        'mediaUrl': null,
        'mediaType': 'image',
      },
      {
        'id': 'traveler-3',
        'title': 'Cuida tu calificación en cada entrega',
        'subtitle': 'Tu selfie, tus reseñas y tu puntualidad pesan cuando el cliente decide.',
        'accent': '#8AB4FF',
        'mediaUrl': null,
        'mediaType': 'image',
      },
    ]);
  }

  @UseGuards(JwtAuthGuard)
  @Put(':feedKey')
  async updateBannerFeed(
    @Param('feedKey') feedKey: 'home' | 'traveler',
    @Body() body: { items?: Array<Record<string, unknown>> },
    @Req() req: any,
  ) {
    if (req.user.role !== 'admin') {
      throw new ForbiddenException('Solo admin puede editar banners.');
    }

    if (!['home', 'traveler'].includes(feedKey)) {
      throw new ForbiddenException('Feed inválido.');
    }

    const items = Array.isArray(body?.items)
      ? body.items
          .filter((item): item is Record<string, unknown> => Boolean(item && typeof item === 'object'))
          .map((item, index) => ({
            id: item.id?.toString() ?? `${feedKey}-${index + 1}`,
            title: item.title?.toString() ?? '',
            subtitle: item.subtitle?.toString() ?? '',
            accent: item.accent?.toString() ?? '#59D38C',
            mediaUrl: item.mediaUrl?.toString() ?? null,
            mediaType: item.mediaType?.toString() === 'video' ? 'video' : 'image',
          }))
      : [];

    await this.prisma.auditLog.create({
      data: {
        actorId: req.user.sub,
        entityType: 'content_banner_feed',
        entityId: feedKey,
        action: 'content_banner_feed_updated',
        payload: { items },
      },
    });

    return this.resolveBannerFeed(feedKey, []);
  }
}
