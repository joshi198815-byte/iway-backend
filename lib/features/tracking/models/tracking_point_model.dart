class TrackingPointModel {
  final double lat;
  final double lng;
  final double? accuracyM;
  final DateTime recordedAt;

  TrackingPointModel({
    required this.lat,
    required this.lng,
    this.accuracyM,
    required this.recordedAt,
  });

  factory TrackingPointModel.fromBackendJson(Map<String, dynamic> json) {
    return TrackingPointModel(
      lat: _toDouble(json['lat']) ?? 0,
      lng: _toDouble(json['lng']) ?? 0,
      accuracyM: _toDouble(json['accuracyM']),
      recordedAt: DateTime.tryParse(
            (json['recordedAt'] ?? json['createdAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
