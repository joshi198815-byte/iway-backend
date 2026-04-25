class OfferModel {
  final String id;
  final String shipmentId;
  final String travelerId;
  final double precio;
  final String mensaje;
  final String estado;
  final String travelerName;
  final int marketplaceScore;
  final String marketplaceTier;
  final double travelerRatingAvg;
  final int travelerVerificationScore;
  final int deliveredCount;
  final double acceptanceRate;
  final List<String> marketplaceInsights;
  final String travelerRegion;
  final String travelerCity;
  final DateTime? pickupAt;
  final DateTime? createdAt;

  OfferModel({
    required this.id,
    required this.shipmentId,
    required this.travelerId,
    required this.precio,
    required this.mensaje,
    required this.estado,
    this.travelerName = '',
    this.marketplaceScore = 0,
    this.marketplaceTier = 'watch',
    this.travelerRatingAvg = 0,
    this.travelerVerificationScore = 0,
    this.deliveredCount = 0,
    this.acceptanceRate = 0,
    this.marketplaceInsights = const [],
    this.travelerRegion = '',
    this.travelerCity = '',
    this.pickupAt,
    this.createdAt,
  });

  factory OfferModel.fromBackendJson(Map<String, dynamic> json) {
    return OfferModel(
      id: (json['id'] ?? '').toString(),
      shipmentId: (json['shipmentId'] ?? '').toString(),
      travelerId: (json['travelerId'] ?? '').toString(),
      precio: _toDouble(json['price'] ?? json['precio']) ?? 0,
      mensaje: (json['message'] ?? json['mensaje'] ?? 'Oferta disponible').toString(),
      estado: (json['status'] ?? json['estado'] ?? '').toString(),
      travelerName: (json['travelerName'] ?? '').toString(),
      marketplaceScore: _toInt(json['marketplaceScore']) ?? 0,
      marketplaceTier: (json['marketplaceTier'] ?? 'watch').toString(),
      travelerRatingAvg: _toDouble(json['travelerRatingAvg']) ?? 0,
      travelerVerificationScore: _toInt(json['travelerVerificationScore']) ?? 0,
      deliveredCount: _toInt(json['deliveredCount']) ?? 0,
      acceptanceRate: _toDouble(json['acceptanceRate']) ?? 0,
      marketplaceInsights: (json['marketplaceInsights'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      travelerRegion: (json['travelerRegion'] ?? '').toString(),
      travelerCity: (json['travelerCity'] ?? '').toString(),
      pickupAt: _toDateTime(json['pickupAt']),
      createdAt: _toDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shipmentId': shipmentId,
      'travelerId': travelerId,
      'precio': precio,
      'mensaje': mensaje,
      'estado': estado,
      'travelerName': travelerName,
      'marketplaceScore': marketplaceScore,
      'marketplaceTier': marketplaceTier,
      'travelerRatingAvg': travelerRatingAvg,
      'travelerVerificationScore': travelerVerificationScore,
      'deliveredCount': deliveredCount,
      'acceptanceRate': acceptanceRate,
      'marketplaceInsights': marketplaceInsights,
      'travelerRegion': travelerRegion,
      'travelerCity': travelerCity,
      'pickupAt': pickupAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
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

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
