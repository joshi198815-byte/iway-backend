import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/shared/models/shipment_status.dart';

class ShipmentStatusPresenter {
  static String label(String status) {
    switch (parseShipmentStatus(status)) {
      case ShipmentStatusValue.published:
        return 'Publicado';
      case ShipmentStatusValue.offered:
        return 'Con ofertas';
      case ShipmentStatusValue.assigned:
        return 'Asignado';
      case ShipmentStatusValue.pickedUp:
        return 'Recogido';
      case ShipmentStatusValue.inTransit:
        return 'En ruta';
      case ShipmentStatusValue.inDelivery:
        return 'Por entregar';
      case ShipmentStatusValue.delivered:
        return 'Entregado';
      case ShipmentStatusValue.disputed:
        return 'En disputa';
      case null:
        return status.isEmpty ? 'Sin estado' : status;
    }
  }

  static String helper(String status) {
    switch (parseShipmentStatus(status)) {
      case ShipmentStatusValue.published:
        return 'El envío ya está publicado y puede recibir ofertas.';
      case ShipmentStatusValue.offered:
        return 'Ya hay propuestas activas esperando decisión.';
      case ShipmentStatusValue.assigned:
        return 'El envío ya tiene viajero asignado.';
      case ShipmentStatusValue.pickedUp:
        return 'El paquete fue recogido y sigue en operación.';
      case ShipmentStatusValue.inTransit:
        return 'El envío va en ruta hacia el destino.';
      case ShipmentStatusValue.inDelivery:
        return 'Está en la fase final antes de entregarse.';
      case ShipmentStatusValue.delivered:
        return 'La entrega fue cerrada operativamente.';
      case ShipmentStatusValue.disputed:
        return 'Hay una incidencia abierta y soporte debe revisarla.';
      case null:
        return 'Estado operativo actualizado.';
    }
  }

  static Color tone(String status) {
    switch (parseShipmentStatus(status)) {
      case ShipmentStatusValue.delivered:
        return Colors.greenAccent;
      case ShipmentStatusValue.inDelivery:
        return const Color(0xFFFFD27A);
      case ShipmentStatusValue.disputed:
        return const Color(0xFFFF9A8B);
      case ShipmentStatusValue.published:
      case ShipmentStatusValue.offered:
      case ShipmentStatusValue.assigned:
      case ShipmentStatusValue.pickedUp:
      case ShipmentStatusValue.inTransit:
      case null:
        return AppTheme.primary;
    }
  }
}
