import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';

class ShipmentStatusPresenter {
  static String label(String status) {
    switch (status) {
      case 'published':
        return 'Publicado';
      case 'offered':
        return 'Con ofertas';
      case 'assigned':
        return 'Asignado';
      case 'picked_up':
        return 'Recogido';
      case 'in_transit':
        return 'En ruta';
      case 'in_delivery':
        return 'Por entregar';
      case 'delivered':
        return 'Entregado';
      case 'disputed':
        return 'En disputa';
      case 'cancelled':
        return 'Cancelado';
      default:
        return status.isEmpty ? 'Sin estado' : status;
    }
  }

  static String helper(String status) {
    switch (status) {
      case 'published':
        return 'El envío ya está publicado y puede recibir ofertas.';
      case 'offered':
        return 'Ya hay propuestas activas esperando decisión.';
      case 'assigned':
        return 'El envío ya tiene viajero asignado.';
      case 'picked_up':
        return 'El paquete fue recogido y sigue en operación.';
      case 'in_transit':
        return 'El envío va en ruta hacia el destino.';
      case 'in_delivery':
        return 'Está en la fase final antes de entregarse.';
      case 'delivered':
        return 'La entrega fue cerrada operativamente.';
      case 'disputed':
        return 'Hay una incidencia abierta y soporte debe revisarla.';
      case 'cancelled':
        return 'Este envío fue cancelado y ya no sigue operativo.';
      default:
        return 'Estado operativo actualizado.';
    }
  }

  static Color tone(String status) {
    switch (status) {
      case 'delivered':
        return Colors.greenAccent;
      case 'in_delivery':
        return const Color(0xFFFFD27A);
      case 'disputed':
        return const Color(0xFFFF9A8B);
      case 'cancelled':
        return AppTheme.muted;
      default:
        return AppTheme.primary;
    }
  }
}
