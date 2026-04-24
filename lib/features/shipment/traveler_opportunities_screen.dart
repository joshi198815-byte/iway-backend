import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/features/traveler/services/traveler_workspace_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/utils/currency_presenter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TravelerOpportunitiesScreen extends StatefulWidget {
  const TravelerOpportunitiesScreen({super.key});

  @override
  State<TravelerOpportunitiesScreen> createState() => _TravelerOpportunitiesScreenState();
}

class _TravelerOpportunitiesScreenState extends State<TravelerOpportunitiesScreen> with WidgetsBindingObserver {
  final _shipmentService = ShipmentService();
  final _workspaceService = TravelerWorkspaceService();
  final _realtime = RealtimeService.instance;

  static const _dismissedStoragePrefix = 'traveler_dismissed_opportunities';

  List<ShipmentModel> _shipments = [];
  Set<String> _dismissedShipmentIds = <String>{};
  bool _loading = true;
  bool _isOnline = true;
  StreamSubscription<dynamic>? _globalSyncSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _bindRealtime();
  }

  String _maskedShipmentId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '------';
    final suffix = trimmed.length <= 6 ? trimmed : trimmed.substring(trimmed.length - 6);
    return '#...${suffix.toUpperCase()}';
  }

  String _cleanSegment(String value) {
    final parts = value
        .split(RegExp(r'[|,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return parts.isEmpty ? value.trim() : parts.first;
  }

  String _originLabel(ShipmentModel shipment) {
    final candidate = shipment.remitenteRegion.isNotEmpty ? shipment.remitenteRegion : shipment.remitenteDireccion;
    final origin = _cleanSegment(candidate);
    if (origin.isNotEmpty) return origin;
    final country = shipment.origen.trim().toUpperCase();
    return country == 'GT' ? 'Guatemala' : country == 'US' ? 'Estados Unidos' : 'Origen pendiente';
  }

  String _destinationLabel(ShipmentModel shipment) {
    final address = shipment.receptorDireccion.trim();
    if (address.isNotEmpty) {
      final parts = address.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
      if (parts.length >= 2) {
        return '${parts[parts.length - 2]}, ${parts.last}';
      }
      if (parts.isNotEmpty) return parts.first;
    }
    final country = shipment.destino.trim().toUpperCase();
    return country == 'US' ? 'Estados Unidos' : country == 'GT' ? 'Guatemala' : 'Destino pendiente';
  }

  String _routeLabel(ShipmentModel shipment) {
    final origin = _originLabel(shipment);
    final destination = _destinationLabel(shipment);
    return 'Origen: $origin → Destino: $destination';
  }

  String get _dismissedStorageKey {
    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty) return _dismissedStoragePrefix;
    return '$_dismissedStoragePrefix:$userId';
  }

  Future<void> _bindRealtime() async {
    await _realtime.ensureConnected();
    _globalSyncSubscription = _realtime.globalEntitySync.listen((_) => _load());
  }

  Future<Set<String>> _readDismissedShipmentIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_dismissedStorageKey) ?? const <String>[]).toSet();
  }

  Future<void> _dismissOpportunity(String shipmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final nextIds = {..._dismissedShipmentIds, shipmentId};
    await prefs.setStringList(_dismissedStorageKey, nextIds.toList());
    if (!mounted) return;
    setState(() {
      _dismissedShipmentIds = nextIds;
      _shipments = _shipments.where((shipment) => shipment.id != shipmentId).toList();
    });
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _shipmentService.getAvailableShipments(),
        _workspaceService.getWorkspace(),
        _readDismissedShipmentIds(),
      ]);
      if (!mounted) return;
      final dismissedIds = results[2] as Set<String>;
      final shipments = (results[0] as List<ShipmentModel>)
          .where((shipment) => !dismissedIds.contains(shipment.id))
          .toList();
      setState(() {
        _dismissedShipmentIds = dismissedIds;
        _shipments = shipments;
        _isOnline = (results[1] as TravelerWorkspaceState).isOnline;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar las oportunidades.')),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _globalSyncSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.background, Color(0xFF111216), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Oportunidades',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isOnline
                            ? 'Revisa pedidos disponibles y decide si ofertar o descartarlos.'
                            : 'Activa tu modo En línea para recibir nuevas oportunidades.',
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _shipments.isEmpty
                            ? const Center(
                                child: Text(
                                  'No hay oportunidades activas en este momento.',
                                  style: TextStyle(color: AppTheme.muted),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _shipments.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final shipment = _shipments[index];
                                  final title = shipment.descripcion?.trim().isNotEmpty == true
                                      ? shipment.descripcion!.trim()
                                      : shipment.tipo;
                                  return Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(color: AppTheme.border, width: 0.5),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _maskedShipmentId(shipment.id),
                                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF2563EB).withValues(alpha: 0.14),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: const Text(
                                                'Disponible',
                                                style: TextStyle(color: Color(0xFF8AB4FF), fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          CurrencyPresenter.formatForShipment(shipment, shipment.valor),
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF34D399),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 10),
                                        Text(
                                          _routeLabel(shipment),
                                          style: const TextStyle(color: AppTheme.muted),
                                        ),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () async {
                                                  await Navigator.pushNamed(context, '/offers', arguments: shipment.id);
                                                  await _load();
                                                },
                                                child: const Text('Ofertar'),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () => _dismissOpportunity(shipment.id),
                                                child: const Text('Rechazar'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
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
