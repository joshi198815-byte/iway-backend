import 'dart:async';

import 'package:flutter/material.dart';

import 'package:iway_app/config/theme.dart';
import 'package:iway_app/services/realtime_service.dart';

class SearchingTravelerScreen extends StatefulWidget {
  final String shipmentId;

  const SearchingTravelerScreen({super.key, required this.shipmentId});

  @override
  State<SearchingTravelerScreen> createState() => _SearchingTravelerScreenState();
}

class _SearchingTravelerScreenState extends State<SearchingTravelerScreen> {
  final _realtime = RealtimeService.instance;
  StreamSubscription<dynamic>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  Future<void> _bind() async {
    await _realtime.ensureConnected();
    _syncSubscription = _realtime.globalEntitySync.listen((event) {
      if (event is! Map) return;
      final payload = event['payload'];
      if (payload is! Map) return;
      if (payload['shipmentId']?.toString() != widget.shipmentId) return;

      final type = event['event']?.toString();
      if (type == 'offer_updated' && mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/offers',
          arguments: widget.shipmentId,
        );
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.background,
              Color(0xFF101116),
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 5),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Buscando viajero',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tu envío ya fue publicado. Puedes salir de esta pantalla, te avisaremos por notificación apenas llegue una oferta.',
                  style: TextStyle(color: AppTheme.muted, height: 1.45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Qué sigue', style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 10),
                      Text('1. Viajero compatible recibe la alerta.'),
                      SizedBox(height: 6),
                      Text('2. Tú recibes la oferta en tiempo real.'),
                      SizedBox(height: 6),
                      Text('3. Aceptas y el chat interno se activa.'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      '/my_orders',
                    ),
                    child: const Text('Ir a mis envíos'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
