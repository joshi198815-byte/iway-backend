import 'package:iway_app/services/api_client.dart';

class AdminTransferService {
  AdminTransferService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> getReviewQueue() async {
    final data = await _apiClient.get('/transfers/review-queue');
    if (data is! List) {
      throw ApiException('No se pudo cargar la cola de transferencias.');
    }

    return data
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  Future<Map<String, dynamic>> reviewTransfer({
    required String transferId,
    required String status,
    String? reason,
  }) {
    return _apiClient.put('/transfers/$transferId/review', {
      'status': status,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }
}
