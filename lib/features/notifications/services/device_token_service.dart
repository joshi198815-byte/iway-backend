import 'package:flutter/foundation.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';

class DeviceTokenService {
  DeviceTokenService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  String _platform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'android';
    }
  }

  String _deviceLabel() {
    if (kIsWeb) return 'web-session';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios-primary';
      default:
        return 'android-primary';
    }
  }

  Future<void> registerToken(String token) async {
    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty || token.isEmpty) {
      return;
    }

    await _apiClient.post('/notifications/device-token', {
      'token': token,
      'platform': _platform(),
      'deviceLabel': _deviceLabel(),
      'installationId': '${_platform()}-${token.substring(token.length > 24 ? token.length - 24 : 0)}',
    });
  }

  Future<void> deactivateToken(String token) async {
    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty || token.isEmpty) {
      return;
    }

    await _apiClient.post('/notifications/device-token/deactivate', {
      'token': token,
    });
  }
}
