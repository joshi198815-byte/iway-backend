import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/features/shipment/services/shipment_ticket_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';
import 'package:iway_app/shared/utils/shipment_status_presenter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with WidgetsBindingObserver {
  final _shipmentService = ShipmentService();
  final _ticketService = const ShipmentTicketService();
  final _realtime = RealtimeService.instance;
  final _searchController = TextEditingController();

  List<ShipmentModel> _shipments = [];
  bool _loading = true;
  String _query = '';
  StreamSubscription<dynamic>? _syncSubscription;

  bool get _isTraveler => SessionService.currentUser?.tipo == 'traveler';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _load();
    _bindRealtime();
  }

  Future<void> _bindRealtime() async {
    await _realtime.ensureConnected();
    _syncSubscription = _realtime.globalEntitySync.listen((_) => _load());
  }

  Future<void> _load() async {
    try {
      final shipments = await _shipmentService.getMyShipments();
      if (!mounted) return;
      setState(() {
        _shipments = shipments;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo cargar el historial.')));
    }
  }

  List<ShipmentModel> get _historyShipments {
    final travelerBase = _shipments.where((item) => (item.assignedTravelerId ?? '').isNotEmpty).toList();
    final base = _isTraveler ? travelerBase : _shipments;
    if (_query.isEmpty) return base;
    return base.where((shipment) {
      final id = _maskedShipmentId(shipment.id).toLowerCase();
      final title = _title(shipment).toLowerCase();
      final recipient = shipment.receptorNombre.toLowerCase();
      return id.contains(_query) || title.contains(_query) || recipient.contains(_query) || shipment.id.toLowerCase().contains(_query);
    }).toList();
  }

  String _maskedShipmentId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '------';
    final suffix = trimmed.length <= 6 ? trimmed : trimmed.substring(trimmed.length - 6);
    return '#...${suffix.toUpperCase()}';
  }

  String _title(ShipmentModel shipment) {
    return shipment.descripcion?.trim().isNotEmpty == true ? shipment.descripcion!.trim() : shipment.tipo;
  }

  String _routeLabel(ShipmentModel shipment) {
    final origin = shipment.remitenteRegion.trim().isNotEmpty ? shipment.remitenteRegion.trim() : shipment.origen;
    final destination = shipment.receptorDireccion.trim().isNotEmpty ? shipment.receptorDireccion.trim() : shipment.destino;
    return '$origin → $destination';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Fecha pendiente';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year - $hour:$minute';
  }

  Future<void> _openShipment(ShipmentModel shipment) async {
    if (shipment.estado == 'delivered') {
      await _ticketService.openReceiptPdf(shipment);
      return;
    }

    if (!mounted) return;
    await Navigator.pushNamed(
      context,
      '/tracking',
      arguments: {
        'shipmentId': shipment.id,
        'initialShipment': shipment,
      },
    );
    await _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncSubscription?.cancel();
    _searchController.dispose();
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                const SizedBox(height: 24),
                const AppPageIntro(
                  title: 'Mis envíos / Recibos',
                  subtitle: 'Abre tracking para lo activo y recibo digital para lo entregado.',
                ),
                const SizedBox(height: 18),
                SearchBar(
                  controller: _searchController,
                  hintText: 'Buscar por ID, paquete o destinatario',
                  leading: const Icon(Icons.search_rounded),
                  backgroundColor: WidgetStateProperty.all(AppTheme.surface),
                  side: WidgetStateProperty.all(const BorderSide(color: AppTheme.border, width: 0.5)),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _historyShipments.isEmpty
                          ? const Center(
                              child: Text('Todavía no hay envíos en tu historial.', style: TextStyle(color: AppTheme.muted)),
                            )
                          : ListView.separated(
                              itemCount: _historyShipments.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final shipment = _historyShipments[index];
                                final delivered = shipment.estado == 'delivered';
                                return InkWell(
                                  onTap: () => _openShipment(shipment),
                                  borderRadius: BorderRadius.circular(22),
                                  child: Container(
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
                                              child: Text(_title(shipment), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                                            ),
                                            Text(
                                              delivered ? 'Recibo' : 'Tracking',
                                              style: TextStyle(
                                                color: delivered ? const Color(0xFF34D399) : AppTheme.accent,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(_maskedShipmentId(shipment.id), style: const TextStyle(color: AppTheme.muted)),
                                        const SizedBox(height: 6),
                                        Text(_routeLabel(shipment), style: const TextStyle(color: AppTheme.muted)),
                                        const SizedBox(height: 6),
                                        Text(_formatDate(shipment.createdAt ?? shipment.updatedAt), style: const TextStyle(color: AppTheme.muted)),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                ShipmentStatusPresenter.label(shipment.estado),
                                                style: const TextStyle(fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () => _openShipment(shipment),
                                              child: Text(delivered ? 'Abrir recibo' : 'Abrir seguimiento'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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
