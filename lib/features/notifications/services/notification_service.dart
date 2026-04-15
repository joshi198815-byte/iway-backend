import 'package:iway_app/features/notifications/models/notification_model.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';

class NotificationService {
  NotificationService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<NotificationModel>> getAll() async {
    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty) {
      return const [];
    }

    final data = await _apiClient.get('/notifications/user/$userId');
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(NotificationModel.fromBackendJson)
        .toList();
  }

  Future<void> markRead(String id) async {
    await _apiClient.post('/notifications/$id/read', {});
  }

  Future<void> markAllRead() async {
    await _apiClient.patch('/notifications/read-all', {});
  }
}
