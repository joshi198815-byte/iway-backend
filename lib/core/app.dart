import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:iway_app/core/app_locale_controller.dart';
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

    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocaleController.notifier,
      builder: (context, locale, _) {
        return MaterialApp(
          navigatorKey: PushNotificationService.navigatorKey,
          title: 'IWAY',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: locale,
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: AppRoutes.initial,
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
