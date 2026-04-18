import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/services/api_client.dart';

class ShipmentService {
  ShipmentService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<ShipmentModel> createShipment(ShipmentModel shipment) async {
    final data = await _apiClient.post('/shipments', {
      'customerId': shipment.userId,
      'originCountryCode': shipment.origen,
      'destinationCountryCode': shipment.destino,
      'packageType': shipment.tipo,
      'packageCategory': shipment.tipo,
      'description': shipment.descripcion,
      'declaredValue': shipment.valor,
      'weightLb': shipment.peso,
      'receiverName': shipment.receptorNombre,
      'receiverPhone': shipment.receptorTelefono,
      'receiverAddress': shipment.receptorDireccion,
      'pickupLat': shipment.pickupLat,
      'pickupLng': shipment.pickupLng,
      'deliveryLat': shipment.deliveryLat,
      'deliveryLng': shipment.deliveryLng,
      'insuranceEnabled': shipment.seguro,
    });

    return ShipmentModel.fromBackendJson(data);
  }

  Future<List<ShipmentModel>> getAvailableShipments() async {
    final data = await _apiClient.get('/shipments/available');
    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(ShipmentModel.fromBackendJson)
        .toList();
  }

  Future<List<ShipmentModel>> getShipments() async {
    final data = await _apiClient.get('/shipments');
    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(ShipmentModel.fromBackendJson)
        .toList();
  }


  Future<List<ShipmentModel>> getMyShipments() async {
    final data = await _apiClient.get('/shipments/mine');
    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(ShipmentModel.fromBackendJson)
        .toList();
  }

  Future<ShipmentModel> getShipmentById(String id) async {
    final data = await _apiClient.get('/shipments/$id');
    if (data is! Map<String, dynamic>) {
      throw ApiException('No se pudo cargar el envío.');
    }
    return ShipmentModel.fromBackendJson(data);
  }

  Future<ShipmentModel> updateStatus(
    String id,
    String status, {
    List<String>? imageUrls,
  }) async {
    final data = await _apiClient.patch('/shipments/$id/status', {
      'status': status,
      'imageUrls': imageUrls,
    });
    return ShipmentModel.fromBackendJson(data);
  }
}
