import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:iway_app/features/notifications/services/device_token_service.dart';
import 'package:iway_app/services/session_service.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await PushNotificationService.ensureFirebaseInitialized();
}

class PushNotificationService {
  PushNotificationService._();

  static const Duration _firebaseOperationTimeout = Duration(seconds: 8);

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'iway_high_importance',
    'iWay Alerts',
    description: 'Alertas operativas y eventos clave de iWay.',
    importance: Importance.max,
  );

  static final navigatorKey = GlobalKey<NavigatorState>();
  static bool _firebaseReady = false;
  static bool _initialized = false;
  static String? _lastHandledMessageId;
  static ({String route, String? shipmentId})? _pendingNavigation;

  static Future<bool> ensureFirebaseInitialized() async {
    if (_firebaseReady) return true;
    if (kIsWeb) return false;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseReady = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();

      await _localNotifications.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: (response) {
          _handlePayload(response.payload);
        },
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      final firebaseReady = await ensureFirebaseInitialized();
      if (!firebaseReady) {
        debugPrint('PushNotificationService.initialize: Firebase no disponible.');
        return;
      }

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('PushNotificationService.initialize: permission=${permission.authorizationStatus.name}');

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await _syncCurrentToken();
      FirebaseMessaging.instance.onTokenRefresh.listen((_) => _syncCurrentToken());

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessage);

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleRemoteMessage(initialMessage);
      }

      _initialized = true;
    } catch (e) {
      debugPrint('PushNotificationService.initialize error: $e');
      _initialized = false;
    }
  }

  static Future<void> syncTokenIfPossible() async {
    try {
      final firebaseReady = await ensureFirebaseInitialized()
          .timeout(_firebaseOperationTimeout, onTimeout: () => false);
      if (!firebaseReady) {
        return;
      }
      await _syncCurrentToken();
    } catch (_) {
      return;
    }
  }

  static Future<void> deactivateCurrentToken() async {
    if (!await ensureFirebaseInitialized()) {
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await DeviceTokenService().deactivateToken(token);
    } catch (_) {}
  }

  static Future<void> _syncCurrentToken() async {
    if (!SessionService.isLoggedIn) return;

    try {
      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(_firebaseOperationTimeout, onTimeout: () => null);
      if (token == null || token.isEmpty) {
        debugPrint('PushNotificationService._syncCurrentToken: token vacío.');
        return;
      }
      debugPrint('PushNotificationService._syncCurrentToken: registrando token ${token.substring(token.length > 12 ? token.length - 12 : 0)}');
      await DeviceTokenService()
          .registerToken(token)
          .timeout(_firebaseOperationTimeout, onTimeout: () => <String, dynamic>{});
    } catch (e) {
      debugPrint('PushNotificationService._syncCurrentToken error: $e');
    }
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final highPriority = (message.data['priority']?.toString().toLowerCase() ?? '') == 'high';

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: highPriority ? Importance.max : Importance.high,
          priority: highPriority ? Priority.max : Priority.high,
          ticker: highPriority ? 'Prioridad alta' : 'iWay',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: highPriority
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      ),
      payload: _payloadFromData(message.data),
    );
  }

  static void _handleRemoteMessage(RemoteMessage message) {
    if (_lastHandledMessageId == message.messageId) {
      return;
    }
    _lastHandledMessageId = message.messageId;
    _navigateFromData(message.data);
  }

  static void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;

    final parts = payload.split('|');
    final route = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first
        : '/notifications';
    final shipmentId = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
    _pushRoute(route, shipmentId: shipmentId);
  }

  static String _payloadFromData(Map<String, dynamic> data) {
    final route = data['route']?.toString().trim();
    final shipmentId = data['shipmentId']?.toString().trim();
    return '${route?.isNotEmpty == true ? route : '/notifications'}|${shipmentId ?? ''}';
  }

  static void _navigateFromData(Map<String, dynamic> data) {
    final route = data['route']?.toString().trim();
    final shipmentId = data['shipmentId']?.toString().trim();
    _pushRoute(
      route?.isNotEmpty == true ? route! : '/notifications',
      shipmentId: shipmentId,
    );
  }

  static Future<void> showLocalVerificationCode(String code) async {
    await _localNotifications.show(
      code.hashCode,
      'i-Way',
      'Tu código es $code',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  static void flushPendingNavigation() {
    final pending = _pendingNavigation;
    if (pending == null) return;
    _pendingNavigation = null;
    _pushRoute(pending.route, shipmentId: pending.shipmentId);
  }

  static void _pushRoute(String route, {String? shipmentId}) {
    final effectiveRoute = route == '/verify_contact' && SessionService.isPhoneVerified
        ? '/home'
        : route;

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _pendingNavigation = (
        route: effectiveRoute,
        shipmentId: shipmentId?.isNotEmpty == true ? shipmentId : null,
      );
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.pushNamed(
        effectiveRoute,
        arguments: shipmentId?.isNotEmpty == true ? shipmentId : null,
      );
    });
  }
}
