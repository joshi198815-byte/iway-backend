class MessageModel {
  final String id;
  final String shipmentId;
  final String senderId;
  final String mensaje;
  final DateTime fecha;

  MessageModel({
    required this.id,
    required this.shipmentId,
    required this.senderId,
    required this.mensaje,
    required this.fecha,
  });

  factory MessageModel.fromBackendJson(Map<String, dynamic> json, {required String shipmentId}) {
    return MessageModel(
      id: (json['id'] ?? '').toString(),
      shipmentId: shipmentId,
      senderId: (json['senderId'] ?? '').toString(),
      mensaje: (json['body'] ?? json['mensaje'] ?? '').toString(),
      fecha: DateTime.tryParse((json['createdAt'] ?? json['fecha'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
