import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iway_app/common/widgets/shipment_ticket.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/label_history_service.dart';
import 'package:iway_app/features/shipment/services/traveler_orders_controller.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';
import 'package:iway_app/shared/utils/currency_presenter.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> with WidgetsBindingObserver {
  final _controller = TravelerOrdersController();
  final _realtime = RealtimeService.instance;
  final _searchController = TextEditingController();

  List<ShipmentModel> _shipments = [];
  bool _loading = true;
  String _tab = 'pickup';
  String _query = '';
  final Set<String> _selectedIds = <String>{};
  StreamSubscription<dynamic>? _notificationSubscription;
  StreamSubscription<dynamic>? _shipmentStatusSubscription;
  StreamSubscription<dynamic>? _offerSubscription;

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
    _controller.loadHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    _shipmentStatusSubscription?.cancel();
    _offerSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bindRealtime() async {
    await _realtime.ensureConnected();
    _notificationSubscription = _realtime.notificationUpdated.listen((_) => _load());
    _shipmentStatusSubscription = _realtime.shipmentStatusChanged.listen((_) => _load());
    _offerSubscription = _realtime.offerUpdated.listen((_) => _load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final data = await _controller.loadShipments();
      if (!mounted) return;
      setState(() {
        _shipments = data;
        _loading = false;
        _selectedIds.removeWhere((id) => !_shipments.any((shipment) => shipment.id == id));
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudieron cargar tus pedidos.')));
    }
  }

  String _maskedShipmentId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '----';
    final suffix = trimmed.length <= 4 ? trimmed : trimmed.substring(trimmed.length - 4);
    return '#${suffix.toUpperCase()}';
  }

  String _cityCountry(String cityOrRegion, String countryCode) {
    final city = cityOrRegion.trim();
    final country = countryCode.trim().toUpperCase();
    if (city.isEmpty && country.isEmpty) return 'Ubicación reservada';
    if (city.isEmpty) return country;
    if (country.isEmpty) return city;
    return '$city, $country';
  }

  String _routeLabel(ShipmentModel shipment) {
    final origin = _cityCountry(shipment.remitenteRegion, shipment.origen);
    final destination = _cityCountry('', shipment.destino);
    return '$origin ➔ $destination';
  }

  _StatusUi _statusUi(String status) {
    switch (status) {
      case 'assigned':
        return const _StatusUi('Por recoger', Color(0xFF2563EB));
      case 'picked_up':
      case 'in_transit':
      case 'in_delivery':
      case 'arrived':
        return const _StatusUi('En ruta', Color(0xFFF59E0B));
      case 'delivered':
        return const _StatusUi('Entregado', Color(0xFF10B981));
      default:
        return const _StatusUi('Activo', Color(0xFF71717A));
    }
  }

  List<ShipmentModel> get _travelerShipments {
    return _shipments.where((item) => (item.assignedTravelerId ?? '').isNotEmpty).toList();
  }

  List<ShipmentModel> get _customerShipments {
    switch (_tab) {
      case 'publicados':
        return _shipments.where((item) => item.assignedTravelerId == null || item.assignedTravelerId!.isEmpty).toList();
      case 'ruta':
        return _shipments.where((item) {
          final hasAcceptedOffer = item.assignedTravelerId != null && item.assignedTravelerId!.isNotEmpty;
          return hasAcceptedOffer && item.estado != 'delivered';
        }).toList();
      case 'completados':
        return _shipments.where((item) => item.estado == 'delivered').toList();
      default:
        return _shipments;
    }
  }

  List<ShipmentModel> get _tabShipments {
    final base = _isTraveler
        ? _travelerShipments.where((item) {
            switch (_tab) {
              case 'pickup':
                return item.estado == 'assigned';
              case 'route':
                return item.estado == 'picked_up' || item.estado == 'in_transit' || item.estado == 'in_delivery' || item.estado == 'arrived';
              case 'delivered':
                return item.estado == 'delivered';
              default:
                return true;
            }
          }).toList()
        : _customerShipments;

    if (_query.isEmpty) return base;
    return base.where((shipment) {
      final recipient = shipment.receptorNombre.toLowerCase();
      final id = _maskedShipmentId(shipment.id).toLowerCase();
      return recipient.contains(_query) || id.contains(_query) || shipment.id.toLowerCase().contains(_query);
    }).toList();
  }

  bool get _allSelectedInView => _tabShipments.isNotEmpty && _tabShipments.every((item) => _selectedIds.contains(item.id));

  void _toggleSelectAll(bool value) {
    setState(() {
      if (value) {
        _selectedIds.addAll(_tabShipments.map((e) => e.id));
      } else {
        _selectedIds.removeAll(_tabShipments.map((e) => e.id));
      }
    });
  }

  Future<void> _printSelection() async {
    final selected = _travelerShipments.where((shipment) => _selectedIds.contains(shipment.id)).toList();
    if (selected.isEmpty) return;

    try {
      await _controller.printAllSelected(selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Etiquetas enviadas a impresión.')));
      setState(() => _selectedIds.clear());
      await _load();
      await _controller.loadHistory();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo imprimir la selección.')));
    }
  }

  Future<void> _printSingle(ShipmentModel shipment) async {
    try {
      await _controller.printAllSelected([shipment]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Etiqueta enviada a impresión.')));
      await _load();
      await _controller.loadHistory();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo imprimir la etiqueta.')));
    }
  }

  Future<void> _confirmLoad(ShipmentModel shipment) async {
    try {
      await _controller.confirmLoad(shipment);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carga confirmada. El envío ya pasó a En ruta.')));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _isTraveler
        ? const [
            _HistoryTab(keyValue: 'pickup', label: 'Por recoger'),
            _HistoryTab(keyValue: 'route', label: 'En ruta'),
            _HistoryTab(keyValue: 'delivered', label: 'Entregados'),
          ]
        : const [
            _HistoryTab(keyValue: 'publicados', label: 'Publicados'),
            _HistoryTab(keyValue: 'ruta', label: 'En ruta'),
            _HistoryTab(keyValue: 'completados', label: 'Completados'),
          ];

    return Scaffold(
      floatingActionButton: _selectedIds.isEmpty || !_isTraveler
          ? null
          : FloatingActionButton.extended(
              onPressed: _printSelection,
              icon: const Icon(Icons.print_outlined),
              label: Text('Imprimir selección (${_selectedIds.length})'),
            ),
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
                      AppPageIntro(
                        title: _isTraveler ? 'Gestión de carga' : 'Historial',
                        subtitle: _isTraveler
                            ? 'Organiza tu inventario por bandejas, imprime etiquetas y confirma carga.'
                            : 'Tus envíos publicados, en ruta y entregados.',
                      ),
                      const SizedBox(height: 18),
                      SearchBar(
                        controller: _searchController,
                        hintText: 'Buscar por destinatario o ID del paquete',
                        leading: const Icon(Icons.search_rounded),
                        backgroundColor: WidgetStateProperty.all(AppTheme.surface),
                        side: WidgetStateProperty.all(const BorderSide(color: AppTheme.border, width: 0.5)),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: tabs.map((tab) {
                          final selected = _tab == tab.keyValue;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _FilterButton(
                                label: tab.label,
                                selected: selected,
                                onTap: () => setState(() => _tab = tab.keyValue),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_isTraveler) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Checkbox(
                              value: _allSelectedInView,
                              onChanged: (value) => _toggleSelectAll(value ?? false),
                            ),
                            const Text('Marcar todo'),
                            const Spacer(),
                            ValueListenableBuilder<List<LabelHistoryEntry>>(
                              valueListenable: _controller.historyNotifier,
                              builder: (context, history, _) {
                                if (history.isEmpty) return const SizedBox.shrink();
                                return Text(
                                  'Historial: ${history.length}/5 PDFs',
                                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Expanded(
                        child: _tabShipments.isEmpty
                            ? const Center(
                                child: Text('No hay pedidos en esta bandeja.', style: TextStyle(color: AppTheme.muted)),
                              )
                            : ListView.separated(
                                itemCount: _tabShipments.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final shipment = _tabShipments[index];
                                  final statusUi = _statusUi(shipment.estado);
                                  final selected = _selectedIds.contains(shipment.id);
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppTheme.border, width: 0.5),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (_isTraveler)
                                                Checkbox(
                                                  value: selected,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      if (value ?? false) {
                                                        _selectedIds.add(shipment.id);
                                                      } else {
                                                        _selectedIds.remove(shipment.id);
                                                      }
                                                    });
                                                  },
                                                ),
                                              Expanded(
                                                child: ShipmentTicket(
                                                  shipment: shipment,
                                                  onOpenChat: _isTraveler
                                                      ? () {
                                                          Navigator.pushNamed(
                                                            context,
                                                            '/chat',
                                                            arguments: {
                                                              'shipmentId': shipment.id,
                                                              'initialDraft': 'Hola, escribo por el paquete ${_maskedShipmentId(shipment.id)}.',
                                                            },
                                                          );
                                                        }
                                                      : null,
                                                  onPrint: _isTraveler ? () => _printSingle(shipment) : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _StatusChip(label: statusUi.label, color: statusUi.color),
                                              _StatusChip(label: _maskedShipmentId(shipment.id), color: const Color(0xFF3F3F46)),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          _TravelerLineItem(label: 'Ruta', value: _routeLabel(shipment)),
                                          const SizedBox(height: 8),
                                          _TravelerLineItem(label: 'Cobro', value: CurrencyPresenter.usd(shipment.valor)),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            children: [
                                              if (_isTraveler && shipment.estado == 'assigned')
                                                ElevatedButton.icon(
                                                  onPressed: () => _confirmLoad(shipment),
                                                  icon: const Icon(Icons.inventory_2_outlined),
                                                  label: const Text('Confirmar carga'),
                                                ),
                                              OutlinedButton(
                                                onPressed: () => Navigator.pushNamed(
                                                  context,
                                                  shipment.estado == 'offered' ? '/offers' : '/tracking',
                                                  arguments: shipment.id,
                                                ),
                                                child: Text(shipment.estado == 'delivered' ? 'Ver recibo' : 'Ver detalle'),
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

class _HistoryTab {
  final String keyValue;
  final String label;

  const _HistoryTab({required this.keyValue, required this.label});
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent.withValues(alpha: 0.14) : AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppTheme.accent : AppTheme.border),
        ),
        child: Center(
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? AppTheme.accent : Colors.white)),
        ),
      ),
    );
  }
}

class _TravelerLineItem extends StatelessWidget {
  const _TravelerLineItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: const TextStyle(color: AppTheme.muted)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatusUi {
  final String label;
  final Color color;

  const _StatusUi(this.label, this.color);
}
