import 'package:flutter/material.dart';
import 'package:iway_app/features/notifications/services/push_notification_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'core/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionService.restoreSession();
  await PushNotificationService.initialize();
  await PushNotificationService.syncTokenIfPossible();
  runApp(const IwayApp());
}
