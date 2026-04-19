import { Controller, Get } from '@nestjs/common';

@Controller('content')
export class ContentController {
  @Get('home-banners')
  getHomeBanners() {
    return [
      {
        id: 'promo-1',
        title: 'Envía esta semana con seguimiento en tiempo real',
        subtitle: 'Publica tu envío, recibe ofertas y mira cada etapa sin salir del dashboard.',
        accent: '#59D38C',
      },
      {
        id: 'promo-2',
        title: 'Seguro opcional para tus paquetes',
        subtitle: 'Activa cobertura desde el formulario y evita sorpresas en ruta.',
        accent: '#FFD27A',
      },
      {
        id: 'promo-3',
        title: 'Destinatarios guardados en USA',
        subtitle: 'Reutiliza direcciones reales con estado, ciudad y Google Places.',
        accent: '#8AB4FF',
      },
    ];
  }

  @Get('traveler-banners')
  getTravelerBanners() {
    return [
      {
        id: 'traveler-1',
        title: 'Activa tu jornada y toma pedidos de tu ruta',
        subtitle: 'Cuando estás en línea, las oportunidades compatibles llegan directo a tu panel.',
        accent: '#59D38C',
      },
      {
        id: 'traveler-2',
        title: 'Reporta tus pagos y mantén tu wallet al día',
        subtitle: 'Sube el comprobante para que Admin valide tu pago y libere tu deuda pendiente.',
        accent: '#FFD27A',
      },
      {
        id: 'traveler-3',
        title: 'Cuida tu calificación en cada entrega',
        subtitle: 'Tu selfie, tus reseñas y tu puntualidad pesan cuando el cliente decide.',
        accent: '#8AB4FF',
      },
    ];
  }
}
