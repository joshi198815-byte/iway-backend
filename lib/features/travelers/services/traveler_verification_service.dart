import 'package:iway_app/services/api_client.dart';

class TravelerVerificationService {
  TravelerVerificationService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getMySummary() async {
    final data = await _apiClient.get('/travelers/me/verification-summary');
    if (data is! Map<String, dynamic>) {
      throw ApiException('No se pudo cargar tu estado de verificación.');
    }
    return data;
  }
}
