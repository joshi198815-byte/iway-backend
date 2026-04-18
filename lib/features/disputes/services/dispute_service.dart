import 'package:iway_app/services/api_client.dart';

class DisputeService {
  DisputeService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> createDispute({
    required String shipmentId,
    required String reason,
    String? context,
  }) {
    return _apiClient.post('/disputes', {
      'shipmentId': shipmentId,
      'reason': reason,
      if (context != null && context.trim().isNotEmpty) 'context': context.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> listMine() async {
    final data = await _apiClient.get('/disputes/me');
    if (data is! List) {
      throw ApiException('No se pudieron cargar tus incidencias.');
    }
    return data.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();
  }

  Future<List<Map<String, dynamic>>> getQueue() async {
    final data = await _apiClient.get('/disputes/queue');
    if (data is! List) {
      throw ApiException('No se pudo cargar la cola de disputas.');
    }
    return data.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();
  }

  Future<Map<String, dynamic>> resolve({
    required String disputeId,
    required String status,
    String? resolution,
  }) {
    return _apiClient.put('/disputes/$disputeId/resolve', {
      'status': status,
      if (resolution != null && resolution.trim().isNotEmpty) 'resolution': resolution.trim(),
    });
  }
}
