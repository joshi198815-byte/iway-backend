class RatingModel {
  final String id;
  final String shipmentId;
  final String fromUserId;
  final String toUserId;
  final int estrellas;
  final String comentario;
  final String fromUserName;
  final String fromUserRole;
  final DateTime? createdAt;

  RatingModel({
    required this.id,
    required this.shipmentId,
    required this.fromUserId,
    required this.toUserId,
    required this.estrellas,
    required this.comentario,
    this.fromUserName = '',
    this.fromUserRole = '',
    this.createdAt,
  });

  factory RatingModel.fromBackendJson(Map<String, dynamic> json) {
    return RatingModel(
      id: (json['id'] ?? '').toString(),
      shipmentId: (json['shipmentId'] ?? '').toString(),
      fromUserId: (json['fromUserId'] ?? '').toString(),
      toUserId: (json['toUserId'] ?? '').toString(),
      estrellas: json['stars'] is int ? json['stars'] as int : int.tryParse('${json['stars']}') ?? 0,
      comentario: (json['comment'] ?? json['comentario'] ?? '').toString(),
      fromUserName: (json['fromUser']?['fullName'] ?? '').toString(),
      fromUserRole: (json['fromUser']?['role'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}
