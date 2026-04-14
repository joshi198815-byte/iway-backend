class NotificationModel {
  final String id;
  final String titulo;
  final String mensaje;
  final DateTime fecha;
  final bool leido;
  final String? tipo;
  final String? shipmentId;

  NotificationModel({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.fecha,
    this.leido = false,
    this.tipo,
    this.shipmentId,
  });

  factory NotificationModel.fromBackendJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] ?? '').toString(),
      titulo: (json['title'] ?? json['titulo'] ?? '').toString(),
      mensaje: (json['body'] ?? json['mensaje'] ?? '').toString(),
      fecha: DateTime.tryParse((json['createdAt'] ?? json['fecha'] ?? '').toString()) ?? DateTime.now(),
      leido: json['readAt'] != null || json['leido'] == true,
      tipo: json['type']?.toString(),
      shipmentId: json['shipmentId']?.toString(),
    );
  }
}
