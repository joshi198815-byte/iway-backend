class RatingModel {
  final String id;
  final String shipmentId;
  final String fromUserId;
  final String toUserId;
  final int estrellas;
  final String comentario;

  RatingModel({
    required this.id,
    required this.shipmentId,
    required this.fromUserId,
    required this.toUserId,
    required this.estrellas,
    required this.comentario,
  });

  factory RatingModel.fromBackendJson(Map<String, dynamic> json) {
    return RatingModel(
      id: (json['id'] ?? '').toString(),
      shipmentId: (json['shipmentId'] ?? '').toString(),
      fromUserId: (json['fromUserId'] ?? '').toString(),
      toUserId: (json['toUserId'] ?? '').toString(),
      estrellas: json['stars'] is int ? json['stars'] as int : int.tryParse('${json['stars']}') ?? 0,
      comentario: (json['comment'] ?? json['comentario'] ?? '').toString(),
    );
  }
}
