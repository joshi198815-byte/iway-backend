import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:iway_app/core/app_locale_controller.dart';
import 'package:iway_app/core/services/permission_service.dart';
import 'package:iway_app/features/notifications/services/push_notification_service.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'core/app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await PushNotificationService.ensureFirebaseInitialized();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.ensureFirebaseInitialized();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await SessionService.restoreSession();
  await AppLocaleController.load();
  await PermissionService.requestStartupPermissionsIfNeeded();
  await PushNotificationService.initialize();
  await PushNotificationService.syncTokenIfPossible();
  PushNotificationService.flushPendingNavigation();
  await RealtimeService.instance.ensureConnected();
  runApp(const IwayApp());
}
