import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/features/traveler/services/traveler_workspace_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';
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

  Future<void> _bindRealtime() async {
    await _realtime.ensureConnected();
    _globalSyncSubscription = _realtime.globalEntitySync.listen((_) => _load());
  }

  String get _dismissedStorageKey {
    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty) {
      return _dismissedStoragePrefix;
    }
    return '$_dismissedStoragePrefix:$userId';
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Oportunidad descartada. Ya no se mostrará en tu lista.')),
    );
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
                      AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                      const SizedBox(height: 24),
                      const AppPageIntro(
                        title: 'Oportunidades',
                        subtitle: 'Aquí ves todos los pedidos disponibles. Tú decides si ofertar o descartarlos.',
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _isOnline ? const Color(0xFF32FF84) : const Color(0xFFFF8A7A),
                          ),
                        ),
                        child: Text(
                          _isOnline
                              ? 'Modo En línea activo. Ya puedes revisar cualquier oportunidad y decidir si ofertar o rechazarla.'
                              : 'Ahora mismo estás desconectado. Vuelve al dashboard y activa tu modo En línea para recibir oportunidades.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
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
                                  return AppGlassSection(
                                    title: 'Oportunidad disponible',
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _LineItem(label: 'Origen', value: shipment.remitenteRegion.isEmpty ? shipment.origen : shipment.remitenteRegion),
                                        const SizedBox(height: 8),
                                        _LineItem(label: 'Destino', value: shipment.receptorDireccion.isEmpty ? shipment.destino : shipment.receptorDireccion.split('•').first.trim()),
                                        const SizedBox(height: 8),
                                        _LineItem(label: 'Libras', value: shipment.peso == null ? 'Pendiente' : '${shipment.peso!.toStringAsFixed(1)} lb'),
                                        const SizedBox(height: 8),
                                        _LineItem(label: 'Pago estimado', value: CurrencyPresenter.formatForShipment(shipment, shipment.valor)),
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

class _LineItem extends StatelessWidget {
  const _LineItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: AppTheme.muted)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
    );
  }
}
