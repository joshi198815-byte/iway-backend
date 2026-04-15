class ShipmentModel {
  final String id;
  final String userId;
  final String tipo;
  final double? peso;
  final String? descripcion;
  final double valor;
  final String origen;
  final String destino;
  final String receptorNombre;
  final String receptorTelefono;
  final String receptorDireccion;
  final double? deliveryLat;
  final double? deliveryLng;
  final List<String> imagenes;
  final bool seguro;
  final double costoSeguro;
  String estado;

  ShipmentModel({
    required this.id,
    required this.userId,
    required this.tipo,
    this.peso,
    this.descripcion,
    required this.valor,
    required this.origen,
    required this.destino,
    required this.receptorNombre,
    required this.receptorTelefono,
    required this.receptorDireccion,
    this.deliveryLat,
    this.deliveryLng,
    required this.imagenes,
    required this.seguro,
    required this.costoSeguro,
    required this.estado,
  });

  factory ShipmentModel.fromBackendJson(Map<String, dynamic> json) {
    return ShipmentModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['customerId'] ?? json['userId'] ?? '').toString(),
      tipo: (json['packageType'] ?? json['tipo'] ?? '').toString(),
      peso: _toDouble(json['weightLb'] ?? json['peso']),
      descripcion: json['description']?.toString() ?? json['descripcion']?.toString(),
      valor: _toDouble(json['declaredValue'] ?? json['valor']) ?? 0,
      origen: (json['originCountryCode'] ?? json['origen'] ?? '').toString(),
      destino: (json['destinationCountryCode'] ?? json['destino'] ?? '').toString(),
      receptorNombre: (json['receiverName'] ?? json['receptorNombre'] ?? '').toString(),
      receptorTelefono: (json['receiverPhone'] ?? json['receptorTelefono'] ?? '').toString(),
      receptorDireccion: (json['receiverAddress'] ?? json['receptorDireccion'] ?? '').toString(),
      deliveryLat: _toDouble(json['deliveryLat']),
      deliveryLng: _toDouble(json['deliveryLng']),
      imagenes: (json['imagenes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      seguro: json['insuranceEnabled'] == true || json['seguro'] == true,
      costoSeguro: _toDouble(json['costoSeguro']) ?? 0,
      estado: (json['status'] ?? json['estado'] ?? '').toString(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
