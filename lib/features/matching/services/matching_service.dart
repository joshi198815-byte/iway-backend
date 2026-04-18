import 'package:iway_app/features/matching/models/offer_model.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';

class MatchingService {
  MatchingService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<OfferModel>> getOffers(String shipmentId) async {
    final data = await _apiClient.get('/offers/shipment/$shipmentId');

    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(OfferModel.fromBackendJson)
        .toList();
  }

  Future<OfferModel> createOffer({
    required String shipmentId,
    required double price,
  }) async {
    final travelerId = SessionService.currentUserId;

    if (travelerId == null || travelerId.isEmpty) {
      throw ApiException('Debes iniciar sesión como viajero para ofertar.');
    }

    final data = await _apiClient.post('/offers', {
      'shipmentId': shipmentId,
      'price': price,
    });

    return OfferModel.fromBackendJson(data);
  }

  Future<void> acceptOffer(OfferModel offer) async {
    final customerId = SessionService.currentUserId;

    if (customerId == null || customerId.isEmpty) {
      throw ApiException('Debes iniciar sesión como cliente para aceptar una oferta.');
    }

    await _apiClient.post('/offers/${offer.id}/accept', {});
  }

  Future<void> rejectOffer(OfferModel offer) async {
    final customerId = SessionService.currentUserId;

    if (customerId == null || customerId.isEmpty) {
      throw ApiException('Debes iniciar sesión como cliente para rechazar una oferta.');
    }

    await _apiClient.post('/offers/${offer.id}/reject', {});
  }
}
