import 'package:iway_app/features/chat/models/message_model.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';

class ChatService {
  ChatService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<String> getOrCreateChatId(String shipmentId) async {
    final data = await _apiClient.post('/chat/shipment/$shipmentId', {});
    return (data['id'] ?? '').toString();
  }

  Future<List<MessageModel>> getMessages(String shipmentId) async {
    final chatId = await getOrCreateChatId(shipmentId);
    final data = await _apiClient.get('/chat/$chatId/messages');

    if (data is! List) {
      return const [];
    }

    final messages = data
        .whereType<Map<String, dynamic>>()
        .map((item) => MessageModel.fromBackendJson(item, shipmentId: shipmentId))
        .toList();

    messages.sort((a, b) => a.fecha.compareTo(b.fecha));
    return messages;
  }

  Future<void> sendMessage(String shipmentId, String text) async {
    final senderId = SessionService.currentUserId;
    if (senderId == null || senderId.isEmpty) {
      throw ApiException('Debes iniciar sesión para enviar mensajes.');
    }

    final chatId = await getOrCreateChatId(shipmentId);

    await _apiClient.post('/chat/messages', {
      'chatId': chatId,
      'body': text,
    });
  }
}
