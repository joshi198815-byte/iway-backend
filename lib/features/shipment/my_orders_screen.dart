import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final _shipmentService = ShipmentService();
  List<ShipmentModel> _shipments = [];
  bool _loading = true;
  String _filter = 'ruta';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _shipmentService.getMyShipments();
      if (!mounted) return;
      setState(() {
        _shipments = data;
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
        const SnackBar(content: Text('No se pudieron cargar tus pedidos.')),
      );
    }
  }

  List<ShipmentModel> get _filteredShipments {
    if (_filter == 'completados') {
      return _shipments.where((item) => item.estado == 'delivered').toList();
    }

    return _shipments.where((item) => item.estado != 'delivered').toList();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'Asignado';
      case 'picked_up':
        return 'Recogido';
      case 'in_transit':
        return 'En ruta';
      case 'in_delivery':
        return 'Por entregar';
      case 'delivered':
        return 'Completado';
      case 'published':
        return 'Publicado';
      default:
        return status;
    }
  }

  void _showSupport() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Soporte técnico',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Si ves un pedido con datos incorrectos o un problema de entrega, avisa al soporte de iWay con el número del pedido.',
              style: TextStyle(color: AppTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/notifications');
                },
                child: const Text('Contactar soporte'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.background,
              Color(0xFF111216),
              AppTheme.background,
            ],
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
                        title: 'Mis pedidos',
                        subtitle: 'Revisa lo que llevas en ruta y lo que ya completaste.',
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _FilterButton(
                              label: 'En ruta',
                              selected: _filter == 'ruta',
                              onTap: () => setState(() => _filter = 'ruta'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _FilterButton(
                              label: 'Completados',
                              selected: _filter == 'completados',
                              onTap: () => setState(() => _filter = 'completados'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: _filteredShipments.isEmpty
                            ? const Center(
                                child: Text(
                                  'No hay pedidos en esta sección.',
                                  style: TextStyle(color: AppTheme.muted),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _filteredShipments.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final shipment = _filteredShipments[index];
                                  final imageUrl = shipment.imagenesReferencia.isNotEmpty
                                      ? shipment.imagenesReferencia.first
                                      : shipment.imagenes.isNotEmpty
                                          ? shipment.imagenes.first
                                          : null;
                                  return AppGlassSection(
                                    title: '${shipment.origen} → ${shipment.destino}',
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (imageUrl != null && imageUrl.isNotEmpty) ...[
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(18),
                                            child: Image.network(
                                              '${ApiClient.baseUrl}$imageUrl',
                                              height: 160,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        Text(
                                          shipment.descripcion?.isNotEmpty == true
                                              ? shipment.descripcion!
                                              : 'Pedido sin descripción adicional.',
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Estado: ${_statusLabel(shipment.estado)}',
                                          style: const TextStyle(color: AppTheme.muted),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Valor declarado: \$${shipment.valor.toStringAsFixed(2)}',
                                          style: const TextStyle(color: AppTheme.muted),
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            ElevatedButton(
                                              onPressed: () => Navigator.pushNamed(
                                                context,
                                                '/tracking',
                                                arguments: shipment.id,
                                              ),
                                              child: const Text('Ver seguimiento'),
                                            ),
                                            OutlinedButton(
                                              onPressed: _showSupport,
                                              child: const Text('Soporte técnico'),
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
          color: selected ? AppTheme.accent : AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppTheme.accent : AppTheme.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? AppTheme.background : Colors.white,
          ),
        ),
      ),
    );
  }
}
