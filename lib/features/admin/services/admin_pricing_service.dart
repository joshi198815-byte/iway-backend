import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';

class AdminPricingService {
  AdminPricingService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getSettings() async {
    final data = await _apiClient.get('/commissions/settings');
    if (data is! Map<String, dynamic>) {
      throw ApiException('No se pudo cargar la configuración de comisiones.');
    }
    return data;
  }

  Future<Map<String, dynamic>> updateSettings({
    required double commissionPerLb,
    required double groundCommissionPercent,
  }) async {
    return _apiClient.put('/commissions/settings', {
      'commissionPerLb': commissionPerLb,
      'groundCommissionPercent': groundCommissionPercent,
      'actorId': SessionService.currentUserId,
    });
  }
}
