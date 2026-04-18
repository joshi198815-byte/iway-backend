import 'package:iway_app/features/tracking/models/tracking_point_model.dart';
import 'package:iway_app/features/tracking/models/tracking_timeline_item.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';

class TrackingService {
  TrackingService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<void> sendTracking({
    required String shipmentId,
    required double lat,
    required double lng,
    double? accuracyM,
    String? checkpoint,
  }) async {
    final travelerId = SessionService.currentUserId;

    if (travelerId == null || travelerId.isEmpty) {
      throw ApiException('Debes iniciar sesión como viajero para reportar tracking.');
    }

    await _apiClient.post('/tracking', {
      'shipmentId': shipmentId,
      'lat': lat,
      'lng': lng,
      'accuracyM': accuracyM,
      'checkpoint': checkpoint,
    });
  }

  Future<TrackingPointModel> getLatestLocation(String shipmentId) async {
    final data = await _apiClient.get('/tracking/shipment/$shipmentId/latest');
    if (data is! Map<String, dynamic>) {
      throw ApiException('No se pudo cargar la ubicación más reciente.');
    }
    return TrackingPointModel.fromBackendJson(data);
  }

  Future<List<TrackingTimelineItem>> getTimeline(String shipmentId) async {
    final data = await _apiClient.get('/tracking/shipment/$shipmentId/timeline');
    if (data is! Map<String, dynamic>) {
      return const [];
    }

    final timeline = data['timeline'];
    if (timeline is! List) {
      return const [];
    }

    return timeline
        .whereType<Map<String, dynamic>>()
        .map(TrackingTimelineItem.fromBackendJson)
        .toList();
  }

  Future<Map<String, dynamic>> getEta(String shipmentId) async {
    final data = await _apiClient.get('/tracking/shipment/$shipmentId/eta');
    if (data is! Map<String, dynamic>) {
      return const {};
    }
    return data;
  }

  Future<Map<String, dynamic>> getRoute(String shipmentId) async {
    final data = await _apiClient.get('/tracking/shipment/$shipmentId/route');
    if (data is! Map<String, dynamic>) {
      return const {};
    }
    return data;
  }
}
