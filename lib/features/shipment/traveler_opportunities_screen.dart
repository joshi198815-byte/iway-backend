import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';
import 'package:iway_app/shared/ui/app_operational_banner.dart';

class TravelerOpportunitiesScreen extends StatefulWidget {
  const TravelerOpportunitiesScreen({super.key});

  @override
  State<TravelerOpportunitiesScreen> createState() => _TravelerOpportunitiesScreenState();
}

class _TravelerOpportunitiesScreenState extends State<TravelerOpportunitiesScreen> with WidgetsBindingObserver {
  final shipmentService = ShipmentService();
  final realtime = RealtimeService.instance;

  List<ShipmentModel> shipments = [];
  bool loading = true;
  StreamSubscription<dynamic>? notificationSubscription;
  StreamSubscription<dynamic>? offerSubscription;
  StreamSubscription<dynamic>? shipmentStatusSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadShipments();
    _bindRealtime();
  }

  Future<void> _bindRealtime() async {
    await realtime.ensureConnected();
    notificationSubscription = realtime.notificationUpdated.listen((_) => loadShipments());
    offerSubscription = realtime.offerUpdated.listen((_) => loadShipments());
    shipmentStatusSubscription = realtime.shipmentStatusChanged.listen((_) => loadShipments());
  }

  Future<void> loadShipments() async {
    try {
      final data = await shipmentService.getAvailableShipments();
      if (!mounted) return;
      setState(() {
        shipments = data;
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
        const SnackBar(content: Text('No se pudieron cargar las oportunidades.')),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    notificationSubscription?.cancel();
    offerSubscription?.cancel();
    shipmentStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadShipments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;
    final isBlocked = user?.bloqueado == true;
    final isVerified = user?.verificado == true;

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
                        title: 'Oportunidades',
                        subtitle: 'Envíos disponibles para tu ruta y listos para recibir ofertas.',
                      ),
                      const SizedBox(height: 18),
                      if (isBlocked) ...[
                        AppOperationalBanner(
                          icon: Icons.lock_outline_rounded,
                          title: 'No puedes ofertar por ahora',
                          message: 'Tu perfil tiene una restricción operativa activa. Regulariza tu estado antes de tomar nuevos envíos.',
                          tone: const Color(0xFFFF8A7A),
                          onTap: () => Navigator.pushNamed(context, '/debts'),
                          ctaLabel: 'Ir a pagos',
                        ),
                        const SizedBox(height: 14),
                      ] else if (!isVerified) ...[
                        AppOperationalBanner(
                          icon: Icons.verified_user_outlined,
                          title: 'Perfil en revisión',
                          message: 'Puedes explorar oportunidades, pero tu aprobación final depende de tu verificación.',
                          tone: const Color(0xFFFFD27A),
                          onTap: () => Navigator.pushNamed(context, '/profile'),
                          ctaLabel: 'Ver perfil',
                        ),
                        const SizedBox(height: 14),
                      ],
                      Expanded(
                        child: shipments.isEmpty
                            ? const Center(
                                child: Text(
                                  'No hay envíos disponibles por ahora.',
                                  style: TextStyle(color: AppTheme.muted),
                                ),
                              )
                            : ListView.separated(
                                itemCount: shipments.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final shipment = shipments[index];
                                  return AppGlassSection(
                                    title: '${shipment.origen} → ${shipment.destino}',
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          shipment.descripcion?.isNotEmpty == true
                                              ? shipment.descripcion!
                                              : 'Envío sin descripción adicional.',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Valor: \$${shipment.valor.toStringAsFixed(2)} • Tipo: ${shipment.tipo}',
                                          style: const TextStyle(color: AppTheme.muted),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _MarketChip(
                                              label: 'Score ${shipment.marketplaceScore}',
                                              color: shipment.marketplaceScore >= 80
                                                  ? const Color(0xFF59D38C)
                                                  : shipment.marketplaceScore >= 65
                                                      ? const Color(0xFF8AB4FF)
                                                      : const Color(0xFFFFD27A),
                                            ),
                                            _MarketChip(
                                              label: shipment.offerCount == 0
                                                  ? 'Sin competencia'
                                                  : '${shipment.offerCount} oferta${shipment.offerCount == 1 ? '' : 's'}',
                                              color: const Color(0xFF8AB4FF),
                                            ),
                                          ],
                                        ),
                                        if (shipment.peso != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Peso: ${shipment.peso!.toStringAsFixed(1)} lb',
                                            style: const TextStyle(color: AppTheme.muted),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceSoft,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: AppTheme.border),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Recogida / cercanía',
                                                style: TextStyle(fontWeight: FontWeight.w700),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                shipment.remitenteRegion.isNotEmpty
                                                    ? 'Departamento o estado de recogida: ${shipment.remitenteRegion}'
                                                    : 'Todavía no hay departamento confirmado para la recogida.',
                                                style: const TextStyle(color: AppTheme.muted),
                                              ),
                                              if (shipment.remitenteDireccion.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Punto aproximado: ${shipment.remitenteDireccion}',
                                                  style: const TextStyle(color: AppTheme.muted),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Entrega para: ${shipment.receptorNombre.isEmpty ? 'No indicado' : shipment.receptorNombre}',
                                          style: const TextStyle(color: AppTheme.muted),
                                        ),
                                        if (shipment.receptorTelefono.isNotEmpty)
                                          Text(
                                            'Teléfono: ${shipment.receptorTelefono}',
                                            style: const TextStyle(color: AppTheme.muted),
                                          ),
                                        if (shipment.receptorDireccion.isNotEmpty)
                                          Text(
                                            'Dirección: ${shipment.receptorDireccion}',
                                            style: const TextStyle(color: AppTheme.muted),
                                          ),
                                        if (shipment.marketplaceInsights.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          ...shipment.marketplaceInsights.take(2).map(
                                            (insight) => Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Text(
                                                '• $insight',
                                                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        ElevatedButton(
                                          onPressed: isBlocked
                                              ? null
                                              : () async {
                                                  await Navigator.pushNamed(
                                                    context,
                                                    '/offers',
                                                    arguments: shipment.id,
                                                  );
                                                  await loadShipments();
                                                },
                                          child: const Text('Ver y ofertar'),
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

class _MarketChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MarketChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
