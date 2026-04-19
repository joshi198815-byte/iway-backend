import 'dart:async';

import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class RealtimeService {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  io.Socket? _socket;
  bool _coreListenersBound = false;
  final Set<String> _chatRooms = <String>{};
  final Set<String> _trackingRooms = <String>{};

  final _chatMessagesController = StreamController<dynamic>.broadcast();
  final _trackingUpdatedController = StreamController<dynamic>.broadcast();
  final _offerUpdatedController = StreamController<dynamic>.broadcast();
  final _shipmentStatusController = StreamController<dynamic>.broadcast();
  final _notificationUpdatedController = StreamController<dynamic>.broadcast();
  final _globalEntitySyncController = StreamController<dynamic>.broadcast();

  Stream<dynamic> get chatMessages => _chatMessagesController.stream;
  Stream<dynamic> get trackingUpdated => _trackingUpdatedController.stream;
  Stream<dynamic> get offerUpdated => _offerUpdatedController.stream;
  Stream<dynamic> get shipmentStatusChanged => _shipmentStatusController.stream;
  Stream<dynamic> get notificationUpdated => _notificationUpdatedController.stream;
  Stream<dynamic> get globalEntitySync => _globalEntitySyncController.stream;

  Future<void> ensureConnected() async {
    final token = SessionService.currentAccessToken;
    if (token == null || token.isEmpty) return;

    if (_socket?.connected == true) return;

    _socket?.dispose();
    _socket = null;
    _coreListenersBound = false;

    final base = ApiClient.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final socket = io.io(
      '$base/realtime',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(1000000)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setAuth({'token': 'Bearer $token'})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    final completer = Completer<void>();
    socket.onConnect((_) {
      _resubscribeRooms();
      if (!completer.isCompleted) completer.complete();
    });
    socket.onConnectError((_) {
      if (!completer.isCompleted) completer.complete();
    });
    socket.connect();

    _socket = socket;
    _bindCoreListeners();
    await completer.future.timeout(ApiClient.requestTimeout, onTimeout: () {});
  }

  Future<void> joinChat(String shipmentId) async {
    _chatRooms.add(shipmentId);
    await ensureConnected();
    _socket?.emit('join_chat', {'shipmentId': shipmentId});
  }

  Future<void> joinTracking(String shipmentId) async {
    _trackingRooms.add(shipmentId);
    await ensureConnected();
    _socket?.emit('join_tracking', {'shipmentId': shipmentId});
  }

  void _bindCoreListeners() {
    if (_coreListenersBound || _socket == null) return;
    _coreListenersBound = true;

    _socket!.onReconnect((_) => _resubscribeRooms());
    _socket!.on('chat_message', (data) => _chatMessagesController.add(data));
    _socket!.on('tracking_updated', (data) => _trackingUpdatedController.add(data));
    _socket!.on('offer_updated', (data) {
      _offerUpdatedController.add(data);
      _globalEntitySyncController.add({
        'event': 'offer_updated',
        'payload': data,
      });
    });
    _socket!.on('shipment_status_changed', (data) {
      _shipmentStatusController.add(data);
      _globalEntitySyncController.add({
        'event': 'shipment_status_changed',
        'payload': data,
      });
    });
    _socket!.on('notification_updated', (data) => _notificationUpdatedController.add(data));
  }

  void _resubscribeRooms() {
    for (final shipmentId in _chatRooms) {
      _socket?.emit('join_chat', {'shipmentId': shipmentId});
    }
    for (final shipmentId in _trackingRooms) {
      _socket?.emit('join_tracking', {'shipmentId': shipmentId});
    }
  }
}
