import 'package:iway_app/services/api_client.dart';

class AdminAntiFraudService {
  AdminAntiFraudService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> getReviewQueue() async {
    final data = await _apiClient.get('/anti-fraud/review-queue');
    if (data is! List) {
      throw ApiException('No se pudo cargar la cola antifraude.');
    }
    return data.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();
  }

  Future<Map<String, dynamic>> recompute(String userId) {
    return _apiClient.post('/anti-fraud/user/$userId/recompute', {});
  }

  Future<Map<String, dynamic>> createFlag({
    required String userId,
    required String flagType,
    required String severity,
    Map<String, dynamic>? details,
  }) {
    return _apiClient.post('/anti-fraud/user/$userId/flags', {
      'flagType': flagType,
      'severity': severity,
      if (details != null) 'details': details,
    });
  }
}
