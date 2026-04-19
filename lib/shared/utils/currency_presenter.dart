import 'package:iway_app/features/shipment/models/shipment_model.dart';

class CurrencyPresenter {
  static String usd(num amount) {
    return 'US\$${amount.toDouble().toStringAsFixed(2)}';
  }

  static String symbolForShipment(ShipmentModel shipment) {
    final origin = shipment.origen.trim().toUpperCase();
    final destination = shipment.destino.trim().toUpperCase();

    if (origin == 'GT' || destination == 'GT') {
      return 'Q';
    }

    return 'US\$';
  }

  static String formatForShipment(ShipmentModel shipment, double amount) {
    return '${symbolForShipment(shipment)}${amount.toStringAsFixed(2)}';
  }
}
