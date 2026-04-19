import 'dart:convert';

import 'package:iway_app/features/auth/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  SessionService._();

  static const _sessionUserKey = 'session_user';
  static const _sessionAccessTokenKey = 'session_access_token';
  static const _locallyVerifiedUsersKey = 'locally_verified_users';
  static const _sessionSchemaVersionKey = 'session_schema_version';
  static const _sessionSchemaVersion = 2;

  static UserModel? currentUser;
  static String? currentAccessToken;

  static bool get isLoggedIn => currentUser != null;
  static bool get isPhoneVerified => currentUser?.telefonoVerificado == true;

  static String? get currentUserId => currentUser?.id;

  static Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_sessionSchemaVersionKey);

    if (storedVersion != _sessionSchemaVersion) {
      await prefs.remove(_sessionUserKey);
      await prefs.remove(_sessionAccessTokenKey);
      await prefs.remove(_locallyVerifiedUsersKey);
      await prefs.setInt(_sessionSchemaVersionKey, _sessionSchemaVersion);
      currentUser = null;
      currentAccessToken = null;
      return;
    }

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

      final restoredUser = UserModel.fromStorageJson(decoded);
      final verifiedUsers = prefs.getStringList(_locallyVerifiedUsersKey) ?? const [];
      currentUser = verifiedUsers.contains(restoredUser.id)
          ? restoredUser.copyWith(telefonoVerificado: true)
          : restoredUser;
    } catch (_) {
      currentUser = null;
      currentAccessToken = null;
      await prefs.remove(_sessionUserKey);
      await prefs.remove(_sessionAccessTokenKey);
    }
  }

  static Future<void> setUser(UserModel user, {String? accessToken}) async {
    final prefs = await SharedPreferences.getInstance();
    final verifiedUsers = prefs.getStringList(_locallyVerifiedUsersKey) ?? const [];
    final effectiveUser = verifiedUsers.contains(user.id)
        ? user.copyWith(telefonoVerificado: true)
        : user;

    currentUser = effectiveUser;
    currentAccessToken = accessToken;
    await prefs.setInt(_sessionSchemaVersionKey, _sessionSchemaVersion);
    await prefs.setString(_sessionUserKey, jsonEncode(effectiveUser.toJson()));
    if (accessToken != null && accessToken.isNotEmpty) {
      await prefs.setString(_sessionAccessTokenKey, accessToken);
    }
  }

  static Future<void> markCurrentPhoneVerifiedLocally() async {
    final user = currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final verifiedUsers = prefs.getStringList(_locallyVerifiedUsersKey) ?? <String>[];
    if (!verifiedUsers.contains(user.id)) {
      verifiedUsers.add(user.id);
      await prefs.setStringList(_locallyVerifiedUsersKey, verifiedUsers);
    }

    await setUser(user.copyWith(telefonoVerificado: true), accessToken: currentAccessToken);
  }

  static Future<void> clear() async {
    currentUser = null;
    currentAccessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionUserKey);
    await prefs.remove(_sessionAccessTokenKey);
  }
}
