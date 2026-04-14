import 'dart:convert';

import 'package:iway_app/features/auth/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  SessionService._();

  static const _sessionUserKey = 'session_user';
  static const _sessionAccessTokenKey = 'session_access_token';

  static UserModel? currentUser;
  static String? currentAccessToken;

  static bool get isLoggedIn => currentUser != null;

  static String? get currentUserId => currentUser?.id;

  static Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionUserKey);
    currentAccessToken = prefs.getString(_sessionAccessTokenKey);

    if (raw == null || raw.isEmpty) {
      currentUser = null;
      currentAccessToken = null;
      await prefs.remove(_sessionAccessTokenKey);
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        currentUser = null;
        currentAccessToken = null;
        await prefs.remove(_sessionUserKey);
        await prefs.remove(_sessionAccessTokenKey);
        return;
      }

      currentUser = UserModel.fromStorageJson(decoded);
    } catch (_) {
      currentUser = null;
      currentAccessToken = null;
      await prefs.remove(_sessionUserKey);
      await prefs.remove(_sessionAccessTokenKey);
    }
  }

  static Future<void> setUser(UserModel user, {String? accessToken}) async {
    currentUser = user;
    currentAccessToken = accessToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionUserKey, jsonEncode(user.toJson()));
    if (accessToken != null && accessToken.isNotEmpty) {
      await prefs.setString(_sessionAccessTokenKey, accessToken);
    }
  }

  static Future<void> clear() async {
    currentUser = null;
    currentAccessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionUserKey);
    await prefs.remove(_sessionAccessTokenKey);
  }
}
