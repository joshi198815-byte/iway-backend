import 'package:flutter/material.dart';
import 'package:iway_app/features/notifications/services/push_notification_service.dart';
import '../routes/app_routes.dart';
import '../config/theme.dart';

class IwayApp extends StatelessWidget {
  const IwayApp({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.flushPendingNavigation();
    });

    return MaterialApp(
      navigatorKey: PushNotificationService.navigatorKey,
      title: 'IWAY',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.initial,
      routes: AppRoutes.routes,
    );
  }
}