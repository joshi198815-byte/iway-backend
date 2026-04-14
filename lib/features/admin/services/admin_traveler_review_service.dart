import 'package:iway_app/services/api_client.dart';

class AdminTravelerReviewService {
  AdminTravelerReviewService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> getReviewQueue() async {
    final data = await _apiClient.get('/travelers/review-queue');
    if (data is! List) {
      throw ApiException('No se pudo cargar la cola de revisión de viajeros.');
    }

    return data
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  Future<Map<String, dynamic>> reviewTraveler({
    required String userId,
    required String action,
    String? reason,
  }) {
    return _apiClient.post('/travelers/$userId/review', {
      'action': action,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  Future<Map<String, dynamic>> updatePayoutHold({
    required String userId,
    required bool enabled,
    String? reason,
  }) {
    return _apiClient.post('/travelers/$userId/payout-hold', {
      'enabled': enabled,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  Future<Map<String, dynamic>> runKycAnalysis(String userId) {
    return _apiClient.post('/travelers/$userId/run-kyc-analysis', {});
  }
}
