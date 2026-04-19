import 'package:flutter/material.dart';
import 'package:iway_app/core/app_locale_controller.dart';
import 'package:iway_app/features/notifications/services/push_notification_service.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'core/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionService.restoreSession();
  await AppLocaleController.load();
  await PushNotificationService.initialize();
  await PushNotificationService.syncTokenIfPossible();
  await RealtimeService.instance.ensureConnected();
  runApp(const IwayApp());
}
