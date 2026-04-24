import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/services/location_service.dart';
import 'package:iway_app/features/matching/models/offer_model.dart';
import 'package:iway_app/features/matching/services/matching_service.dart';
import 'package:iway_app/features/payments/services/payment_service.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';
import 'package:iway_app/shared/ui/app_empty_state.dart';
import 'package:iway_app/shared/ui/app_skeleton.dart';
import 'package:iway_app/shared/utils/currency_presenter.dart';

class OffersScreen extends StatefulWidget {
  final String shipmentId;

  const OffersScreen({super.key, required this.shipmentId});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> with WidgetsBindingObserver {
  final matchingService = MatchingService();
  final shipmentService = ShipmentService();
  final priceController = TextEditingController();
  final realtime = RealtimeService.instance;
  final locationService = LocationService();
  final paymentService = PaymentService();

  Position? currentPosition;

  ShipmentModel? shipment;
  List<OfferModel> offers = [];
  bool loading = true;
  bool creatingOffer = false;
  double commissionPerLb = 0;
  double groundCommissionPercent = 0;
  StreamSubscription<dynamic>? globalSyncSubscription;
  StreamSubscription<dynamic>? notificationSubscription;

  bool get isTraveler => SessionService.currentUser?.tipo == 'traveler';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentPosition();
    loadOffers();
    _loadPricing();
    bindRealtime();
  }

  Future<void> _loadPricing() async {
    if (!isTraveler) return;
    try {
      final summary = await paymentService.getDebtSummary();
      final pricing = summary['pricingSettings'];
      if (!mounted || pricing is! Map<String, dynamic>) return;
      setState(() {
        commissionPerLb = (pricing['commissionPerLb'] as num?)?.toDouble() ?? 0;
        groundCommissionPercent = (pricing['groundCommissionPercent'] as num?)?.toDouble() ?? 0;
      });
    } catch (_) {}
  }

  Future<void> bindRealtime() async {
    await realtime.ensureConnected();
    globalSyncSubscription = realtime.globalEntitySync.listen((event) {
      if (event is! Map) return;
      final payload = event['payload'];
      if (payload is Map && payload['shipmentId']?.toString() == widget.shipmentId) {
        loadOffers();
      }
    });
    notificationSubscription = realtime.notificationUpdated.listen((data) {
      if (data is Map && data['shipmentId']?.toString() == widget.shipmentId) {
        loadOffers();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    globalSyncSubscription?.cancel();
    notificationSubscription?.cancel();
    priceController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadOffers();
    }
  }

  Future<void> _loadCurrentPosition() async {
    final position = await locationService.getLocation();
    if (!mounted) return;
    setState(() => currentPosition = position);
  }

  Future<void> loadOffers() async {
    try {
      final results = await Future.wait([
        matchingService.getOffers(widget.shipmentId),
        shipmentService.getShipmentById(widget.shipmentId),
      ]);

      if (!mounted) return;

      setState(() {
        offers = results[0] as List<OfferModel>;
        shipment = results[1] as ShipmentModel;
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
        const SnackBar(content: Text('No se pudieron cargar las ofertas.')),
      );
    }
  }

  double _estimatedCommission(double offerPrice) {
    if (shipment == null) return 0;
    if ((shipment!.peso ?? 0) > 0 && commissionPerLb > 0) {
      return shipment!.peso! * commissionPerLb;
    }
    if (groundCommissionPercent > 0) {
      return offerPrice * groundCommissionPercent;
    }
    return 0;
  }

  Future<void> createOffer() async {
    final price = double.tryParse(priceController.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un precio válido.')),
      );
      return;
    }

    setState(() => creatingOffer = true);

    try {
      await matchingService.createOffer(
        shipmentId: widget.shipmentId,
        price: price,
      );

      if (!mounted) return;
      priceController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oferta enviada con éxito.')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      final message = e.message.contains('Internal Server Error')
          ? 'No se pudo enviar la oferta. Revisa tu estado en línea y vuelve a intentarlo.'
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar la oferta.')),
      );
    } finally {
      if (mounted) {
        setState(() => creatingOffer = false);
      }
    }
  }

  Future<void> accept(OfferModel offer) async {
    try {
      await matchingService.acceptOffer(offer);

      if (!mounted) return;

      final initialShipment = shipment?.copyWith(
        assignedTravelerId: offer.travelerId,
        estado: 'assigned',
      );

      Navigator.pushReplacementNamed(
        context,
        '/tracking',
        arguments: {
          'shipmentId': offer.shipmentId,
          'initialShipment': initialShipment,
        },
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo aceptar la oferta.')),
      );
    }
  }

  Future<void> reject(OfferModel offer) async {
    try {
      await matchingService.rejectOffer(offer);
      await loadOffers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oferta rechazada. El viajero puede enviar otra propuesta.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo rechazar la oferta.')),
      );
    }
  }

  String formatStatus(String estado) {
    switch (estado) {
      case 'accepted':
        return 'Aceptada';
      case 'pending':
        return 'Pendiente';
      case 'rejected':
        return 'Rechazada';
      case 'withdrawn':
        return 'Retirada';
      default:
        return estado.isEmpty ? 'Pendiente' : estado;
    }
  }

  Color statusTone(String estado) {
    switch (estado) {
      case 'accepted':
        return AppTheme.accent;
      case 'rejected':
        return const Color(0xFFFF9A8B);
      case 'withdrawn':
        return AppTheme.muted;
      default:
        return const Color(0xFFFFD27A);
    }
  }

  String statusHelper(String estado, {required bool isTravelerView}) {
    switch (estado) {
      case 'accepted':
        return 'Esta oferta ya quedó seleccionada para el envío.';
      case 'rejected':
        return isTravelerView
            ? 'El cliente pidió una nueva propuesta o descartó esta oferta.'
            : 'Esta propuesta ya no seguirá en competencia.';
      case 'withdrawn':
        return 'La propuesta fue retirada y ya no está activa.';
      default:
        return isTravelerView
            ? 'Tu propuesta está activa y esperando decisión del cliente.'
            : 'Oferta activa lista para evaluación.';
    }
  }

  String? emptyStateHint() {
    final status = shipment?.estado ?? '';
    if (isTraveler) {
      if (status == 'assigned' || status == 'picked_up' || status == 'in_transit' || status == 'arrived' || status == 'delivered') {
        return 'Este envío ya avanzó demasiado para recibir nuevas propuestas.';
      }
      return 'Propón un precio competitivo para entrar en la conversación.';
    }

    if (status == 'pending') {
      return 'Cuando lleguen propuestas de viajeros, aparecerán aquí para compararlas.';
    }
    if (status == 'assigned') {
      return 'Este envío ya tiene viajero asignado. Si esperabas más opciones, revisa tracking.';
    }
    return 'Todavía no hay propuestas visibles para este envío.';
  }

  String? disabledActionHint(OfferModel offer) {
    if (SessionService.currentUserId == null) {
      return 'Debes iniciar sesión otra vez para tomar una decisión.';
    }
    if (offer.estado == 'accepted') {
      return 'Esta propuesta ya fue aceptada.';
    }
    if (offer.estado == 'rejected' || offer.estado == 'withdrawn') {
      return 'Esta oferta ya no está activa.';
    }
    return null;
  }

  bool _matchesTravelerRoute(ShipmentModel shipment) {
    final routes = SessionService.currentUser?.rutas ?? const <String>[];
    final pickupRegion = shipment.remitenteRegion.trim().toLowerCase();
    if (pickupRegion.isEmpty) return false;
    return routes.any((route) => route.trim().toLowerCase() == pickupRegion);
  }

  String _recommendedPickupPoint(ShipmentModel shipment) {
    if (shipment.remitenteDireccion.trim().isNotEmpty) {
      return shipment.remitenteDireccion.trim();
    }
    if (shipment.pickupLat != null && shipment.pickupLng != null) {
      return 'Hay ubicación cargada para ver en tracking/mapa.';
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

  String _pickupChatDraft(ShipmentModel shipment) {
    final pickupPoint = _recommendedPickupPoint(shipment);
    final region = shipment.remitenteRegion.isNotEmpty ? shipment.remitenteRegion : 'la zona de recogida';
    return 'Hola, ya vi el envío. Propongo coordinar la recogida en $region. Punto sugerido: $pickupPoint.';
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
          child: loading
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                  children: const [
                    AppSkeletonBlock(height: 120, margin: EdgeInsets.only(bottom: 14), radius: 24),
                    AppSkeletonBlock(height: 160, margin: EdgeInsets.only(bottom: 14), radius: 24),
                    AppSkeletonBlock(height: 160, radius: 24),
                  ],
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                          const SizedBox(height: 24),
                          AppPageIntro(
                            title: isTraveler ? 'Haz tu oferta' : 'Aceptar oferta',
                            subtitle: isTraveler
                                ? 'Compite por este envío con un precio claro y directo.'
                                : 'Revisa precios y elige una oferta. Por ahora el cliente puede aceptar o rechazar, no contraofertar.',
                          ),
                          const SizedBox(height: 18),
                          if (shipment != null)
                            AppGlassSection(
                              title: isTraveler ? 'Detalle del envío' : 'Resumen del envío',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${shipment!.origen} → ${shipment!.destino}',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  if ((shipment!.descripcion ?? '').isNotEmpty)
                                    Text(
                                      shipment!.descripcion!,
                                      style: const TextStyle(color: AppTheme.muted),
                                    ),
                                  const SizedBox(height: 8),
                                  if (shipment!.remitenteRegion.isNotEmpty || shipment!.remitenteDireccion.isNotEmpty) ...[
                                    Text(
                                      shipment!.remitenteRegion.isNotEmpty
                                          ? 'Recogida en: ${shipment!.remitenteRegion}'
                                          : 'Recogida pendiente de región exacta',
                                      style: const TextStyle(color: AppTheme.muted),
                                    ),
                                    if (isTraveler)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          _matchesTravelerRoute(shipment!)
                                              ? 'Sí coincide con una de tus rutas activas.'
                                              : 'No coincide exacto con tus rutas guardadas. Revisa cercanía antes de ofertar.',
                                          style: TextStyle(
                                            color: _matchesTravelerRoute(shipment!) ? const Color(0xFF59D38C) : const Color(0xFFFFD27A),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    if (isTraveler) ...[
                                      Text(
                                        'Punto sugerido de encuentro: ${_recommendedPickupPoint(shipment!)}',
                                        style: const TextStyle(color: AppTheme.muted),
                                      ),
                                      if (_distanceToPickupLabel(shipment!) != null)
                                        Text(
                                          'Distancia aproximada: ${_distanceToPickupLabel(shipment!)}',
                                          style: const TextStyle(color: AppTheme.muted),
                                        ),
                                      if (shipment!.remitenteNombre.isNotEmpty)
                                        Text(
                                          'Remitente: ${shipment!.remitenteNombre}',
                                          style: const TextStyle(color: AppTheme.muted),
                                        ),
                                      if (shipment!.remitenteTelefono.isNotEmpty)
                                        Text(
                                          'Contacto de recogida: ${shipment!.remitenteTelefono}',
                                          style: const TextStyle(color: AppTheme.muted),
                                        ),
                                    ],
                                    const SizedBox(height: 8),
                                  ],
                                  Text(
                                    'Entrega para: ${shipment!.receptorNombre.isEmpty ? 'No indicado' : shipment!.receptorNombre}',
                                    style: const TextStyle(color: AppTheme.muted),
                                  ),
                                  if (shipment!.receptorTelefono.isNotEmpty && isTraveler)
                                    Text(
                                      'Teléfono: ${shipment!.receptorTelefono}',
                                      style: const TextStyle(color: AppTheme.muted),
                                    ),
                                  if (shipment!.receptorDireccion.isNotEmpty)
                                    Text(
                                      'Dirección: ${shipment!.receptorDireccion}',
                                      style: const TextStyle(color: AppTheme.muted),
                                    ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Valor declarado: ${CurrencyPresenter.formatForShipment(shipment!, shipment!.valor)}',
                                    style: const TextStyle(color: AppTheme.muted),
                                  ),
                                  if (shipment!.peso != null)
                                    Text(
                                      'Peso: ${shipment!.peso!.toStringAsFixed(1)} lb',
                                      style: const TextStyle(color: AppTheme.muted),
                                    ),
                                  const SizedBox(height: 12),
                                  if (isTraveler)
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.pushNamed(
                                              context,
                                              '/map',
                                              arguments: widget.shipmentId,
                                            );
                                          },
                                          icon: const Icon(Icons.map_outlined),
                                          label: const Text('Abrir mapa'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.pushNamed(
                                              context,
                                              '/chat',
                                              arguments: {
                                                'shipmentId': widget.shipmentId,
                                                'initialDraft': _pickupChatDraft(shipment!),
                                              },
                                            );
                                          },
                                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                                          label: const Text('Coordinar pickup'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          if (shipment != null) const SizedBox(height: 14),
                          if (isTraveler)
                            AppGlassSection(
                              title: 'Tu propuesta',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: priceController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Tu oferta (${shipment == null ? 'USD' : CurrencyPresenter.symbolForShipment(shipment!)})',
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  const SizedBox(height: 12),
                                  Builder(
                                    builder: (context) {
                                      final offerPrice = double.tryParse(priceController.text.trim());
                                      final estimatedCommission = offerPrice == null ? 0 : _estimatedCommission(offerPrice);
                                      final estimatedNet = offerPrice == null ? 0 : (offerPrice - estimatedCommission);
                                      return Container(
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
                                            const Text('Desglose estimado', style: TextStyle(fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 8),
                                            Text('Precio ofertado: US\$${(offerPrice ?? 0).toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.muted)),
                                            Text('Comisión app: US\$${estimatedCommission.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.muted)),
                                            Text('Recibes aprox.: US\$${estimatedNet.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton(
                                    onPressed: creatingOffer ? null : createOffer,
                                    child: creatingOffer
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('Enviar oferta'),
                                  ),
                                  const SizedBox(height: 10),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: Text(
                                      creatingOffer
                                          ? 'Enviando tu propuesta al cliente...'
                                          : 'Una oferta clara y rápida mejora la tasa de aceptación.',
                                      key: ValueKey(creatingOffer),
                                      style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: offers.isEmpty
                          ? AppEmptyState(
                              icon: Icons.local_offer_outlined,
                              title: isTraveler
                                  ? 'Todavía no has enviado una oferta'
                                  : 'Todavía no hay ofertas',
                              subtitle: emptyStateHint() ?? '',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                              itemCount: offers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final offer = offers[index];

                                return Container(
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
                                              shipment == null
                                                  ? 'US\$${offer.precio.toStringAsFixed(2)}'
                                                  : CurrencyPresenter.formatForShipment(shipment!, offer.precio),
                                              style: const TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.8,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: statusTone(offer.estado).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(999),
                                              border: Border.all(color: statusTone(offer.estado).withValues(alpha: 0.26)),
                                            ),
                                            child: Text(
                                              formatStatus(offer.estado),
                                              style: TextStyle(
                                                color: statusTone(offer.estado),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        offer.travelerName.isNotEmpty ? offer.travelerName : 'Viajero ${offer.travelerId}',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _OfferChip(
                                            label: 'Puntaje ${offer.marketplaceScore}',
                                            color: offer.marketplaceScore >= 80
                                                ? const Color(0xFF59D38C)
                                                : offer.marketplaceScore >= 65
                                                    ? const Color(0xFF8AB4FF)
                                                    : const Color(0xFFFFD27A),
                                          ),
                                          _OfferChip(
                                            label: '${offer.deliveredCount} entregas',
                                            color: const Color(0xFF8AB4FF),
                                          ),
                                          _OfferChip(
                                            label: 'Calificación ${offer.travelerRatingAvg.toStringAsFixed(1)}',
                                            color: const Color(0xFFFFD27A),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        statusHelper(offer.estado, isTravelerView: isTraveler),
                                        style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                                      ),
                                      if (isTraveler && offer.mensaje.trim().isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          offer.mensaje,
                                          style: const TextStyle(color: AppTheme.muted),
                                        ),
                                      ],
                                      if (!isTraveler && offer.marketplaceInsights.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          offer.marketplaceInsights.first,
                                          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                        ),
                                      ],
                                      if (!isTraveler) ...[
                                        const SizedBox(height: 16),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            ElevatedButton(
                                              onPressed: offer.estado == 'accepted' || SessionService.currentUserId == null
                                                  ? null
                                                  : () => accept(offer),
                                              child: const Text('Aceptar oferta'),
                                            ),
                                            OutlinedButton(
                                              onPressed: offer.estado != 'pending' || SessionService.currentUserId == null
                                                  ? null
                                                  : () => reject(offer),
                                              child: const Text('Rechazar / pedir nueva'),
                                            ),
                                          ],
                                        ),
                                        if (disabledActionHint(offer) != null) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            disabledActionHint(offer)!,
                                            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                          ),
                                        ],
                                      ],
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
    );
  }
}

class _OfferChip extends StatelessWidget {
  final String label;
  final Color color;

  const _OfferChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

