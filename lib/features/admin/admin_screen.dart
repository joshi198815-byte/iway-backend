import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/admin/services/admin_pricing_service.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/insurance_service.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_action_cards.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final shipmentService = ShipmentService();
  final pricingService = AdminPricingService();
  final insuranceService = InsuranceService();
  final commissionPerLbController = TextEditingController();
  final groundCommissionPercentController = TextEditingController();
  final shipmentSearchController = TextEditingController();

  List<ShipmentModel> shipments = [];
  List<Map<String, dynamic>> pricingHistory = [];
  bool loading = true;
  bool savingPricing = false;
  String? pricingSavedMessage;
  double activeCommissionPerLb = 0;
  double activeGroundCommissionPercent = 0;
  final Set<String> expandedShipmentIds = <String>{};
  String selectedStatusFilter = 'all';
  String selectedRouteFilter = 'all';

  bool get hasSession => SessionService.currentUser != null;
  bool get canAccessAdmin => SessionService.currentUser?.tipo != 'traveler';

  @override
  void initState() {
    super.initState();
    if (hasSession && canAccessAdmin) {
      loadData();
    } else {
      loading = false;
    }
  }

  @override
  void dispose() {
    commissionPerLbController.dispose();
    groundCommissionPercentController.dispose();
    shipmentSearchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    try {
      final shipmentData = await shipmentService.getShipments();
      final pricing = await pricingService.getSettings();

      if (!mounted) return;

      setState(() {
        shipments = shipmentData;
        activeCommissionPerLb = _toDouble(pricing['commissionPerLb']);
        activeGroundCommissionPercent = _toDouble(pricing['groundCommissionPercent']);
        commissionPerLbController.text = _formatDecimal(pricing['commissionPerLb']);
        groundCommissionPercentController.text = _formatPercent(pricing['groundCommissionPercent']);
        pricingHistory = _parseHistory(pricing['history']);
        pricingSavedMessage = null;
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar el panel admin.')),
      );
    }
  }

  double _toDouble(dynamic value) {
    return value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
  }

  String _formatDecimal(dynamic value) {
    return _toDouble(value).toStringAsFixed(2);
  }

  String _formatPercent(dynamic value) {
    return (_toDouble(value) * 100).toStringAsFixed(2);
  }

  List<Map<String, dynamic>> _parseHistory(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();
  }

  double get previewCommissionPerLb => double.tryParse(commissionPerLbController.text.trim()) ?? 0;
  double get previewGroundPercent => double.tryParse(groundCommissionPercentController.text.trim()) ?? 0;
  bool get hasUnsavedPricingChanges =>
      (previewCommissionPerLb - activeCommissionPerLb).abs() > 0.0001 ||
      ((previewGroundPercent / 100) - activeGroundCommissionPercent).abs() > 0.0001;

  Future<void> savePricing() async {
    final commissionPerLb = double.tryParse(commissionPerLbController.text.trim());
    final groundPercent = double.tryParse(groundCommissionPercentController.text.trim());

    if (commissionPerLb == null || commissionPerLb < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una comisión válida por libra.')),
      );
      return;
    }

    if (groundPercent == null || groundPercent < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una comisión válida para tierra.')),
      );
      return;
    }

    setState(() => savingPricing = true);

    try {
      final updated = await pricingService.updateSettings(
        commissionPerLb: commissionPerLb,
        groundCommissionPercent: groundPercent / 100,
      );

      if (!mounted) return;

      setState(() {
        activeCommissionPerLb = _toDouble(updated['commissionPerLb']);
        activeGroundCommissionPercent = _toDouble(updated['groundCommissionPercent']);
        commissionPerLbController.text = _formatDecimal(updated['commissionPerLb']);
        groundCommissionPercentController.text = _formatPercent(updated['groundCommissionPercent']);
        pricingHistory = _parseHistory(updated['history']);
        pricingSavedMessage = 'Tarifa activa: \$${_formatDecimal(updated['commissionPerLb'])}/lb y ${_formatPercent(updated['groundCommissionPercent'])}% sobre valor declarado en USD.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarifas de comisión actualizadas.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron guardar las tarifas.')),
      );
    } finally {
      if (mounted) {
        setState(() => savingPricing = false);
      }
    }
  }

  Future<void> cambiarEstado(String id, String estado) async {
    try {
      await shipmentService.updateStatus(id, estado);
      await loadData();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el estado.')),
      );
    }
  }

  String formatStatus(String estado) {
    switch (estado) {
      case 'published':
        return 'Publicado';
      case 'offered':
        return 'Con ofertas';
      case 'assigned':
        return 'Asignado';
      case 'delivered':
        return 'Entregado';
      default:
        return estado;
    }
  }

  bool canAssign(String estado) => estado != 'assigned' && estado != 'delivered';
  bool canDeliver(String estado) => estado != 'delivered';

  List<ShipmentModel> get filteredShipments {
    return shipments.where((shipment) {
      final matchesStatus = selectedStatusFilter == 'all' || shipment.estado == selectedStatusFilter;
      final routeLabel = '${shipment.origen}_${shipment.destino}'.toLowerCase();
      final matchesRoute = selectedRouteFilter == 'all' || routeLabel == selectedRouteFilter;
      final query = shipmentSearchController.text.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          shipment.id.toLowerCase().contains(query) ||
          shipment.receptorNombre.toLowerCase().contains(query) ||
          shipment.receptorTelefono.toLowerCase().contains(query);
      return matchesStatus && matchesRoute && matchesSearch;
    }).toList();
  }

  Widget _buildProtectedGallery(List<String> images) {
    final token = SessionService.currentAccessToken;
    if (images.isEmpty) {
      return const Text(
        'Sin imágenes disponibles.',
        style: TextStyle(color: AppTheme.muted, fontSize: 13),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: images.map((imageUrl) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            '${ApiClient.baseUrl}$imageUrl',
            width: 82,
            height: 82,
            fit: BoxFit.cover,
            headers: token == null || token.isEmpty ? null : {'Authorization': 'Bearer $token'},
            errorBuilder: (_, __, ___) => Container(
              width: 82,
              height: 82,
              color: AppTheme.surfaceSoft,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined, color: AppTheme.muted),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _ruleTile({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppTheme.muted, height: 1.35)),
              ],
            ),
          ),
        ],
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
              Color(0xFF101116),
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                      const SizedBox(height: 24),
                      const AppPageIntro(
                        title: 'Panel admin',
                        subtitle: 'Control operativo de envíos, estados y parámetros de negocio.',
                      ),
                      const SizedBox(height: 20),
                      if (!hasSession)
                        AppGlassSection(
                          title: 'Acceso requerido',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Necesitas iniciar sesión para abrir el panel operativo.',
                                style: TextStyle(color: AppTheme.muted),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                                },
                                child: const Text('Ir a login'),
                              ),
                            ],
                          ),
                        )
                      else if (!canAccessAdmin)
                        const AppGlassSection(
                          title: 'Acceso restringido',
                          child: Text(
                            'Esta vista operativa no está disponible para cuentas de viajero.',
                            style: TextStyle(color: AppTheme.muted),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView(
                            children: [
                              AppQuickActionWide(
                                icon: Icons.account_balance_outlined,
                                title: 'Revisar transferencias',
                                subtitle: 'Aprueba, rechaza y concilia pagos pendientes en una sola bandeja.',
                                onTap: () => Navigator.pushNamed(context, '/admin_transfers'),
                              ),
                              const SizedBox(height: 12),
                              AppQuickActionWide(
                                icon: Icons.verified_user_outlined,
                                title: 'Revisar viajeros',
                                subtitle: 'Abre la cola antifraude y toma decisiones de verificación manual.',
                                onTap: () => Navigator.pushNamed(context, '/admin_travelers_review'),
                              ),
                              const SizedBox(height: 12),
                              AppQuickActionWide(
                                icon: Icons.receipt_long_outlined,
                                title: 'Ledger financiero',
                                subtitle: 'Consulta deuda, movimientos y registra ajustes manuales por traveler.',
                                onTap: () => Navigator.pushNamed(context, '/admin_ledger'),
                              ),
                              const SizedBox(height: 12),
                              AppQuickActionWide(
                                icon: Icons.shield_moon_outlined,
                                title: 'Antifraude avanzado',
                                subtitle: 'Revisa cola de riesgo, duplicados, velocidad y señales operativas.',
                                onTap: () => Navigator.pushNamed(context, '/admin_antifraud'),
                              ),
                              const SizedBox(height: 12),
                              AppQuickActionWide(
                                icon: Icons.support_agent_outlined,
                                title: 'Disputas y soporte',
                                subtitle: 'Gestiona incidentes, escalaciones y cierres operativos por envío.',
                                onTap: () => Navigator.pushNamed(context, '/admin_disputes'),
                              ),
                              const SizedBox(height: 16),
                              AppGlassSection(
                                title: 'Reglas de negocio',
                                child: Column(
                                  children: [
                                    _ruleTile(
                                      icon: Icons.scale_outlined,
                                      title: 'Libra',
                                      value: '\$${previewCommissionPerLb.toStringAsFixed(2)} por lb',
                                      subtitle: 'Activo: \$${activeCommissionPerLb.toStringAsFixed(2)} por lb.',
                                    ),
                                    const SizedBox(height: 12),
                                    _ruleTile(
                                      icon: Icons.local_shipping_outlined,
                                      title: 'Tierra',
                                      value: '${previewGroundPercent.toStringAsFixed(2)}%',
                                      subtitle: 'Activo: ${(activeGroundCommissionPercent * 100).toStringAsFixed(2)}% sobre valor declarado en USD.',
                                    ),
                                    const SizedBox(height: 12),
                                    _ruleTile(
                                      icon: Icons.verified_user_outlined,
                                      title: 'Seguro',
                                      value: 'Referencia operativa',
                                      subtitle: 'Hasta \$1000 = \$${insuranceService.calcularSeguro(1000).toStringAsFixed(2)}, hasta \$5000 = \$${insuranceService.calcularSeguro(5000).toStringAsFixed(2)}, mayor = \$${insuranceService.calcularSeguro(6000).toStringAsFixed(2)}.',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              AppGlassSection(
                                title: 'Tarifas y comisiones',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (hasUnsavedPricingChanges) ...[
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2A2112),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: const Color(0xFF6C5325)),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.pending_outlined, color: Color(0xFFFFD27A), size: 18),
                                            SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'Tienes cambios en edición sin guardar.',
                                                style: TextStyle(color: Color(0xFFFFF0CC)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                    TextField(
                                      controller: commissionPerLbController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(
                                        labelText: 'Comisión por libra (USD)',
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: groundCommissionPercentController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(
                                        labelText: 'Comisión tierra / carga (%)',
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'La comisión por libra aplica a envíos tipo libra y se cobra en USD. La comisión de tierra aplica como porcentaje del valor declarado en USD para carga general.',
                                      style: TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.35),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceSoft,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Vista previa rápida',
                                            style: TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '1 lb = \$${previewCommissionPerLb.toStringAsFixed(2)}',
                                            style: const TextStyle(color: AppTheme.muted),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '\$100 declarados por tierra = \$${(100 * (previewGroundPercent / 100)).toStringAsFixed(2)}',
                                            style: const TextStyle(color: AppTheme.muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: savingPricing ? null : savePricing,
                                      child: savingPricing
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Text('Guardar tarifas'),
                                    ),
                                    if (pricingSavedMessage != null) ...[
                                      const SizedBox(height: 14),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF13261C),
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(color: const Color(0xFF2D6A4F)),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Padding(
                                              padding: EdgeInsets.only(top: 1),
                                              child: Icon(Icons.check_circle_outline, color: Color(0xFF7DFFB2), size: 18),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                pricingSavedMessage!,
                                                style: const TextStyle(color: Color(0xFFD9FFE8), height: 1.35),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              AppGlassSection(
                                title: 'Historial reciente de tarifas',
                                child: pricingHistory.isEmpty
                                    ? const Text(
                                        'Aún no hay cambios registrados.',
                                        style: TextStyle(color: AppTheme.muted),
                                      )
                                    : Column(
                                        children: pricingHistory.map((item) {
                                          final payload = item['payload'];
                                          final next = payload is Map ? payload['next'] : null;
                                          final commission = next is Map ? _toDouble(next['commissionPerLb']) : 0;
                                          final ground = next is Map ? _toDouble(next['groundCommissionPercent']) : 0;
                                          final createdAt = item['createdAt']?.toString() ?? '';
                                          final actorName = item['actorName']?.toString();
                                          final actorEmail = item['actorEmail']?.toString();
                                          final actorId = item['actorId']?.toString();
                                          final actorLabel = (actorName != null && actorName.isNotEmpty)
                                              ? actorName
                                              : (actorEmail != null && actorEmail.isNotEmpty)
                                                  ? actorEmail
                                                  : actorId;

                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: AppTheme.surfaceSoft,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: AppTheme.border),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '\$${commission.toStringAsFixed(2)}/lb • ${(ground * 100).toStringAsFixed(2)}%',
                                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Actualizado: $createdAt',
                                                    style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                                                  ),
                                                  if (actorLabel != null && actorLabel.isNotEmpty)
                                                    Text(
                                                      'Por: $actorLabel',
                                                      style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              AppGlassSection(
                                title: 'Filtros operativos',
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: shipmentSearchController,
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(
                                        labelText: 'Buscar por shipment ID, receptor o teléfono',
                                        prefixIcon: Icon(Icons.search),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    DropdownButtonFormField<String>(
                                      initialValue: selectedStatusFilter,
                                      decoration: const InputDecoration(labelText: 'Estado'),
                                      items: const [
                                        DropdownMenuItem(value: 'all', child: Text('Todos')),
                                        DropdownMenuItem(value: 'published', child: Text('Publicado')),
                                        DropdownMenuItem(value: 'offered', child: Text('Con ofertas')),
                                        DropdownMenuItem(value: 'assigned', child: Text('Asignado')),
                                        DropdownMenuItem(value: 'delivered', child: Text('Entregado')),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() => selectedStatusFilter = value);
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    DropdownButtonFormField<String>(
                                      initialValue: selectedRouteFilter,
                                      decoration: const InputDecoration(labelText: 'Ruta'),
                                      items: const [
                                        DropdownMenuItem(value: 'all', child: Text('Todas')),
                                        DropdownMenuItem(value: 'gt_us', child: Text('GT → US')),
                                        DropdownMenuItem(value: 'us_gt', child: Text('US → GT')),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() => selectedRouteFilter = value);
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${filteredShipments.length} envío(s) visibles con el filtro actual.',
                                        style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (filteredShipments.isEmpty)
                                const Center(child: Text('No hay envíos para este filtro.'))
                              else
                                ...filteredShipments.map(
                                  (s) {
                                    final isExpanded = expandedShipmentIds.contains(s.id);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Container(
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface,
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Shipment ${s.id}',
                                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                              IconButton(
                                                onPressed: () {
                                                  setState(() {
                                                    if (isExpanded) {
                                                      expandedShipmentIds.remove(s.id);
                                                    } else {
                                                      expandedShipmentIds.add(s.id);
                                                    }
                                                  });
                                                },
                                                icon: Icon(
                                                  isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                color: AppTheme.surface,
                                                onSelected: (value) => cambiarEstado(s.id, value),
                                                itemBuilder: (context) => [
                                                  if (canAssign(s.estado))
                                                    const PopupMenuItem(
                                                      value: 'assigned',
                                                      child: Text('Marcar asignado'),
                                                    ),
                                                  if (canDeliver(s.estado))
                                                    const PopupMenuItem(
                                                      value: 'delivered',
                                                      child: Text('Marcar entregado'),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text('Estado: ${formatStatus(s.estado)}'),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Ruta: ${s.origen} → ${s.destino}',
                                            style: const TextStyle(color: AppTheme.muted),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Valor declarado: \$${s.valor.toStringAsFixed(2)}',
                                            style: const TextStyle(color: AppTheme.muted),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Fotos del paquete: ${s.imagenesReferencia.length} • Evidencias de entrega: ${s.evidenciasEntrega.length}',
                                            style: const TextStyle(color: AppTheme.muted),
                                          ),
                                          if (s.seguro)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                'Seguro: \$${s.costoSeguro.toStringAsFixed(2)}',
                                                style: const TextStyle(color: AppTheme.muted),
                                              ),
                                            ),
                                          if (isExpanded) ...[
                                            const SizedBox(height: 14),
                                            Text(
                                              s.descripcion?.isNotEmpty == true
                                                  ? s.descripcion!
                                                  : 'Sin descripción adicional.',
                                              style: const TextStyle(color: AppTheme.muted, height: 1.35),
                                            ),
                                            const SizedBox(height: 14),
                                            const Text(
                                              'Fotos del paquete',
                                              style: TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                            const SizedBox(height: 10),
                                            _buildProtectedGallery(s.imagenesReferencia),
                                            const SizedBox(height: 14),
                                            const Text(
                                              'Evidencias de entrega',
                                              style: TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                            const SizedBox(height: 10),
                                            _buildProtectedGallery(s.evidenciasEntrega),
                                            const SizedBox(height: 14),
                                            OutlinedButton(
                                              onPressed: () {
                                                Navigator.pushNamed(
                                                  context,
                                                  '/admin_shipment',
                                                  arguments: s.id,
                                                );
                                              },
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                side: const BorderSide(color: AppTheme.border),
                                                minimumSize: const Size(double.infinity, 50),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                              ),
                                              child: const Text('Abrir detalle operativo'),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                ),
                            ],
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
