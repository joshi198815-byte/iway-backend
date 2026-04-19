class ShipmentModel {
  final String id;
  final String userId;
  final String? assignedTravelerId;
  final String tipo;
  final double? peso;
  final String? descripcion;
  final double valor;
  final String origen;
  final String destino;
  final String remitenteNombre;
  final String remitenteTelefono;
  final String remitenteDireccion;
  final String remitenteRegion;
  final String receptorNombre;
  final String receptorTelefono;
  final String receptorDireccion;
  final List<String> imagenes;
  final List<String> imagenesReferencia;
  final List<String> evidenciasEntrega;
  final bool seguro;
  final double costoSeguro;
  final double? pickupLat;
  final double? pickupLng;
  final double? deliveryLat;
  final double? deliveryLng;
  final int marketplaceScore;
  final String marketplaceTier;
  final int offerCount;
  final List<String> marketplaceInsights;
  String estado;

  ShipmentModel({
    required this.id,
    required this.userId,
    this.assignedTravelerId,
    required this.tipo,
    this.peso,
    this.descripcion,
    required this.valor,
    required this.origen,
    required this.destino,
    this.remitenteNombre = '',
    this.remitenteTelefono = '',
    this.remitenteDireccion = '',
    this.remitenteRegion = '',
    required this.receptorNombre,
    required this.receptorTelefono,
    required this.receptorDireccion,
    required this.imagenes,
    this.imagenesReferencia = const [],
    this.evidenciasEntrega = const [],
    required this.seguro,
    required this.costoSeguro,
    this.pickupLat,
    this.pickupLng,
    this.deliveryLat,
    this.deliveryLng,
    this.marketplaceScore = 0,
    this.marketplaceTier = 'watch',
    this.offerCount = 0,
    this.marketplaceInsights = const [],
    required this.estado,
  });

  factory ShipmentModel.fromBackendJson(Map<String, dynamic> json) {
    final backendImages = (json['images'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];
    final referenceImages = backendImages
        .where((e) => (e['kind'] ?? 'package_reference').toString() == 'package_reference')
        .map((e) => (e['imageUrl'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final deliveryProofs = backendImages
        .where((e) => (e['kind'] ?? '').toString() == 'delivery_proof')
        .map((e) => (e['imageUrl'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();

    return ShipmentModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['customerId'] ?? json['userId'] ?? '').toString(),
      assignedTravelerId: json['assignedTravelerId']?.toString(),
      tipo: (json['packageType'] ?? json['tipo'] ?? '').toString(),
      peso: _toDouble(json['weightLb'] ?? json['peso']),
      descripcion: json['description']?.toString() ?? json['descripcion']?.toString(),
      valor: _toDouble(json['declaredValue'] ?? json['valor']) ?? 0,
      origen: (json['originCountryCode'] ?? json['origen'] ?? '').toString(),
      destino: (json['destinationCountryCode'] ?? json['destino'] ?? '').toString(),
      remitenteNombre: (json['senderName'] ?? json['remitenteNombre'] ?? '').toString(),
      remitenteTelefono: (json['senderPhone'] ?? json['remitenteTelefono'] ?? '').toString(),
      remitenteDireccion: (json['senderAddress'] ?? json['remitenteDireccion'] ?? '').toString(),
      remitenteRegion: (json['senderStateRegion'] ?? json['remitenteRegion'] ?? '').toString(),
      receptorNombre: (json['receiverName'] ?? json['receptorNombre'] ?? '').toString(),
      receptorTelefono: (json['receiverPhone'] ?? json['receptorTelefono'] ?? '').toString(),
      receptorDireccion: (json['receiverAddress'] ?? json['receptorDireccion'] ?? '').toString(),
      imagenes: (json['imagenes'] as List?)?.map((e) => e.toString()).toList() ??
          backendImages
              .map((e) => (e['imageUrl'] ?? '').toString())
              .where((e) => e.isNotEmpty)
              .toList(),
      imagenesReferencia: referenceImages,
      evidenciasEntrega: deliveryProofs,
      seguro: json['insuranceEnabled'] == true || json['seguro'] == true,
      costoSeguro: _toDouble(json['costoSeguro']) ?? 0,
      pickupLat: _toDouble(json['pickupLat']),
      pickupLng: _toDouble(json['pickupLng']),
      deliveryLat: _toDouble(json['deliveryLat']),
      deliveryLng: _toDouble(json['deliveryLng']),
      marketplaceScore: _toInt(json['marketplaceScore']) ?? 0,
      marketplaceTier: (json['marketplaceTier'] ?? 'watch').toString(),
      offerCount: _toInt(json['offerCount']) ?? 0,
      marketplaceInsights: (json['marketplaceInsights'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      estado: (json['status'] ?? json['estado'] ?? '').toString(),
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
