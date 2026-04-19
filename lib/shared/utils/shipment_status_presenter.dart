import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/shared/models/shipment_status.dart';

class ShipmentStatusPresenter {
  static String label(String status) {
    switch (parseShipmentStatus(status)) {
      case ShipmentStatusValue.pending:
        return 'Pendiente';
      case ShipmentStatusValue.offered:
        return 'Con ofertas';
      case ShipmentStatusValue.assigned:
        return 'Asignado';
      case ShipmentStatusValue.pickedUp:
        return 'Recogido';
      case ShipmentStatusValue.inTransit:
        return 'En ruta';
      case ShipmentStatusValue.arrived:
        return 'Arribó';
      case ShipmentStatusValue.delivered:
        return 'Entregado';
      case null:
        return status.isEmpty ? 'Sin estado' : status;
    }
  }

  static String helper(String status) {
    switch (parseShipmentStatus(status)) {
      case ShipmentStatusValue.pending:
        return 'El envío está listo para recibir ofertas.';
      case ShipmentStatusValue.offered:
        return 'Ya hay propuestas activas esperando decisión.';
      case ShipmentStatusValue.assigned:
        return 'El envío ya tiene viajero asignado.';
      case ShipmentStatusValue.pickedUp:
        return 'El paquete fue recogido y sigue en operación.';
      case ShipmentStatusValue.inTransit:
        return 'El envío va en ruta hacia el destino.';
      case ShipmentStatusValue.arrived:
        return 'El paquete ya arribó al punto final antes de entregarse.';
      case ShipmentStatusValue.delivered:
        return 'La entrega fue cerrada operativamente.';
      case null:
        return 'Estado operativo actualizado.';
    }
  }

  static Color tone(String status) {
    switch (parseShipmentStatus(status)) {
      case ShipmentStatusValue.delivered:
        return Colors.greenAccent;
      case ShipmentStatusValue.arrived:
        return const Color(0xFFFFD27A);
      case ShipmentStatusValue.pending:
      case ShipmentStatusValue.offered:
      case ShipmentStatusValue.assigned:
      case ShipmentStatusValue.pickedUp:
      case ShipmentStatusValue.inTransit:
      case null:
        return AppTheme.primary;
    }
  }
}
