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
}
