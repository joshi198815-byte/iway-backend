import 'package:iway_app/services/api_client.dart';

class AdminLedgerService {
  AdminLedgerService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getTravelerSummary(String travelerId) async {
    final data = await _apiClient.get('/commissions/traveler/$travelerId/summary');
    if (data is! Map<String, dynamic>) {
      throw ApiException('No se pudo cargar el resumen financiero del traveler.');
    }
    return data;
  }

  Future<Map<String, dynamic>> getTravelerLedger(String travelerId) async {
    final data = await _apiClient.get('/commissions/traveler/$travelerId/ledger');
    if (data is! Map<String, dynamic>) {
      throw ApiException('No se pudo cargar el ledger del traveler.');
    }
    return data;
  }

  Future<Map<String, dynamic>> createAdjustment({
    required String travelerId,
    required String direction,
    required double amount,
    required String description,
    String? weeklySettlementId,
  }) async {
    return _apiClient.post('/commissions/traveler/$travelerId/ledger-adjustments', {
      'direction': direction,
      'amount': amount,
      'description': description,
      if (weeklySettlementId != null && weeklySettlementId.isNotEmpty) 'weeklySettlementId': weeklySettlementId,
    });
  }
}
