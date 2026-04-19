import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/services/location_service.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';
import 'package:iway_app/shared/utils/currency_presenter.dart';
import 'package:iway_app/shared/ui/app_operational_banner.dart';

class TravelerOpportunitiesScreen extends StatefulWidget {
  const TravelerOpportunitiesScreen({super.key});

  @override
  State<TravelerOpportunitiesScreen> createState() => _TravelerOpportunitiesScreenState();
}

class _TravelerOpportunitiesScreenState extends State<TravelerOpportunitiesScreen> with WidgetsBindingObserver {
  final shipmentService = ShipmentService();
  final realtime = RealtimeService.instance;
  final locationService = LocationService();

  Position? currentPosition;

  List<ShipmentModel> shipments = [];
  bool loading = true;
  StreamSubscription<dynamic>? notificationSubscription;
  StreamSubscription<dynamic>? globalSyncSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentPosition();
    loadShipments();
    _bindRealtime();
  }

  Future<void> _bindRealtime() async {
    await realtime.ensureConnected();
    notificationSubscription = realtime.notificationUpdated.listen((_) => loadShipments());
    globalSyncSubscription = realtime.globalEntitySync.listen((_) => loadShipments());
  }

  Future<void> _loadCurrentPosition() async {
    final position = await locationService.getLocation();
    if (!mounted) return;
    setState(() => currentPosition = position);
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
    globalSyncSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadShipments();
    }
  }

  bool _matchesTravelerRoute(ShipmentModel shipment) {
    final routes = SessionService.currentUser?.rutas ?? const <String>[];
    final pickupRegion = shipment.remitenteRegion.trim().toLowerCase();
    if (pickupRegion.isEmpty) return false;
    return routes.any((route) => route.trim().toLowerCase() == pickupRegion);
  }

  String _pickupFitLabel(ShipmentModel shipment) {
    if (shipment.remitenteRegion.trim().isEmpty) {
      return 'Aún no hay departamento confirmado para medir cercanía.';
    }
    return _matchesTravelerRoute(shipment)
        ? 'Esta recogida sí coincide con una de tus rutas activas.'
        : 'Esta recogida no coincide exacto con tus rutas guardadas. Revísala antes de pujar.';
  }

  String _recommendedPickupPoint(ShipmentModel shipment) {
    if (shipment.remitenteDireccion.trim().isNotEmpty) {
      return shipment.remitenteDireccion.trim();
    }
    if (shipment.pickupLat != null && shipment.pickupLng != null) {
      return 'Punto geolocalizado listo para verse en mapa al tomar el envío.';
    }
    return 'Todavía no hay punto exacto confirmado.';
  }

  String? _distanceToPickupLabel(ShipmentModel shipment) {
    final origin = currentPosition;
    if (origin == null || shipment.pickupLat == null || shipment.pickupLng == null) {
      return null;
    }

    final meters = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      shipment.pickupLat!,
      shipment.pickupLng!,
    );

    if (meters < 1000) {
      return '${meters.round()} m de tu ubicación actual';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km de tu ubicación actual';
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
                                          'Valor: ${CurrencyPresenter.formatForShipment(shipment, shipment.valor)} • Tipo: ${shipment.tipo}',
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
                                              const SizedBox(height: 4),
                                              Text(
                                                _pickupFitLabel(shipment),
                                                style: TextStyle(
                                                  color: _matchesTravelerRoute(shipment) ? const Color(0xFF59D38C) : const Color(0xFFFFD27A),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Punto sugerido: ${_recommendedPickupPoint(shipment)}',
                                                style: const TextStyle(color: AppTheme.muted),
                                              ),
                                              if (_distanceToPickupLabel(shipment) != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Distancia aproximada: ${_distanceToPickupLabel(shipment)!}',
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
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () {
                                                Navigator.pushNamed(
                                                  context,
                                                  '/map',
                                                  arguments: shipment.id,
                                                );
                                              },
                                              icon: const Icon(Icons.map_outlined),
                                              label: const Text('Ver mapa'),
                                            ),
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
