class PaymentModel {

  final String id;
  final String travelerId;
  final String shipmentId;

  final double monto;
  final String tipo; // libra | tierra

  final bool pagado;

  PaymentModel({
    required this.id,
    required this.travelerId,
    required this.shipmentId,
    required this.monto,
    required this.tipo,
    this.pagado = false,
  });
}