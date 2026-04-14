import 'package:iway_app/features/rating/models/rating_model.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';

class RatingService {
  RatingService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<void> addRating({
    required String shipmentId,
    required int estrellas,
    required String comentario,
  }) async {
    final fromUserId = SessionService.currentUserId;
    if (fromUserId == null || fromUserId.isEmpty) {
      throw ApiException('Debes iniciar sesión para calificar.');
    }

    await _apiClient.post('/ratings', {
      'shipmentId': shipmentId,
      'fromUserId': fromUserId,
      'stars': estrellas,
      'comment': comentario,
    });
  }

  Future<List<RatingModel>> getRatings(String userId) async {
    final data = await _apiClient.get('/ratings/user/$userId');
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(RatingModel.fromBackendJson)
        .toList();
  }
}
