import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';

class PaymentService {
  PaymentService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getDebtSummary() async {
    final travelerId = SessionService.currentUserId;

    if (travelerId == null || travelerId.isEmpty) {
      throw ApiException('Debes iniciar sesión para consultar tus deudas.');
    }

    final data = await _apiClient.get('/commissions/traveler/$travelerId/summary');

    if (data is! Map<String, dynamic>) {
      throw ApiException('No se pudo cargar el resumen de comisiones.');
    }

    return data;
  }

  Future<Map<String, dynamic>> updateCutoffPreference(int preferredCutoffDay) async {
    final data = await _apiClient.put('/commissions/me/cutoff-preference', {
      'preferredCutoffDay': preferredCutoffDay,
    });

    return data;
  }

  Future<Map<String, dynamic>> submitTransfer({
    required double amount,
    String? weeklySettlementId,
    String? bankReference,
    String? proofUrl,
  }) {
    return _apiClient.post('/transfers', {
      'amount': amount,
      if (weeklySettlementId != null && weeklySettlementId.isNotEmpty) 'weeklySettlementId': weeklySettlementId,
      if (bankReference != null && bankReference.trim().isNotEmpty) 'bankReference': bankReference.trim(),
      if (proofUrl != null && proofUrl.trim().isNotEmpty) 'proofUrl': proofUrl.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> getMyTransfers() async {
    final data = await _apiClient.get('/transfers/me');
    if (data is! List) {
      throw ApiException('No se pudo cargar tu historial de transferencias.');
    }

    return data
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getMyLedger() async {
    final data = await _apiClient.get('/commissions/me/ledger');
    if (data is! Map<String, dynamic>) {
      throw ApiException('No se pudo cargar tu ledger financiero.');
    }

    final entries = data['entries'];
    if (entries is! List) return [];
    return entries
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  Future<Map<String, dynamic>> getMyPayoutPolicy() async {
    final data = await _apiClient.get('/transfers/me/payout-policy');
    if (data is! Map<String, dynamic>) {
      throw ApiException('No se pudo cargar tu política de payout.');
    }
    return data;
  }
}
