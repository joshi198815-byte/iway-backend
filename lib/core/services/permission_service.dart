import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iway_app/features/notifications/services/push_notification_service.dart';

class PermissionService {
  PermissionService._();

  static const _startupPermissionsKey = 'startup_permissions_requested_v1';

  static Future<void> requestStartupPermissionsIfNeeded() async {
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyRequested = prefs.getBool(_startupPermissionsKey) ?? false;
    if (alreadyRequested) return;

    await requestStartupPermissions(force: true);
    await prefs.setBool(_startupPermissionsKey, true);
  }

  static Future<void> requestStartupPermissions({bool force = false}) async {
    if (kIsWeb) return;

    try {
      if (force || await Permission.notification.isDenied || await Permission.notification.isRestricted) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('PermissionService.notification error: $e');
    }

    try {
      final firebaseReady = await PushNotificationService.ensureFirebaseInitialized();
      if (firebaseReady) {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      }
    } catch (e) {
      debugPrint('PermissionService.fcm notification error: $e');
    }

    try {
      if (force || await Permission.location.isDenied || await Permission.location.isRestricted) {
        await Permission.location.request();
      }
    } catch (e) {
      debugPrint('PermissionService.location error: $e');
    }

    try {
      if (force || await Permission.camera.isDenied || await Permission.camera.isRestricted) {
        await Permission.camera.request();
      }
    } catch (e) {
      debugPrint('PermissionService.camera error: $e');
    }
  }
}
