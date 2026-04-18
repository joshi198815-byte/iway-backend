import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/matching/models/offer_model.dart';
import 'package:iway_app/features/matching/services/matching_service.dart';
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

  ShipmentModel? shipment;
  List<OfferModel> offers = [];
  bool loading = true;
  bool creatingOffer = false;
  StreamSubscription<dynamic>? offerSubscription;
  StreamSubscription<dynamic>? shipmentStatusSubscription;
  StreamSubscription<dynamic>? notificationSubscription;

  bool get isTraveler => SessionService.currentUser?.tipo == 'traveler';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadOffers();
    bindRealtime();
  }

  Future<void> bindRealtime() async {
    await realtime.joinOffers(widget.shipmentId);
    offerSubscription = realtime.offerUpdated.listen((data) {
      if (data is Map && data['shipmentId']?.toString() == widget.shipmentId) {
        loadOffers();
      }
    });
    shipmentStatusSubscription = realtime.shipmentStatusChanged.listen((data) {
      if (data is Map && data['shipmentId']?.toString() == widget.shipmentId) {
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
    offerSubscription?.cancel();
    shipmentStatusSubscription?.cancel();
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

      priceController.clear();
      await loadOffers();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear la oferta.')),
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

      Navigator.pushNamed(
        context,
        '/tracking',
        arguments: offer.shipmentId,
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
      default:
        return estado.isEmpty ? 'Pendiente' : estado;
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
                            title: isTraveler ? 'Haz tu oferta' : 'Elige la mejor oferta',
                            subtitle: isTraveler
                                ? 'Compite por este envío con un precio claro y directo.'
                                : 'Compara viajeros y acepta la opción que más te convenga.',
                          ),
                          const SizedBox(height: 18),
                          if (shipment != null)
                            AppGlassSection(
                              title: 'Detalle del envío',
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
                                  Text(
                                    'Entrega para: ${shipment!.receptorNombre.isEmpty ? 'No indicado' : shipment!.receptorNombre}',
                                    style: const TextStyle(color: AppTheme.muted),
                                  ),
                                  if (shipment!.receptorTelefono.isNotEmpty)
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
                                    'Valor declarado: US\$${shipment!.valor.toStringAsFixed(2)}',
                                    style: const TextStyle(color: AppTheme.muted),
                                  ),
                                  if (shipment!.peso != null)
                                    Text(
                                      'Peso: ${shipment!.peso!.toStringAsFixed(1)} lb',
                                      style: const TextStyle(color: AppTheme.muted),
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
                                    decoration: const InputDecoration(
                                      labelText: 'Tu oferta (USD)',
                                    ),
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
                              subtitle: isTraveler
                                  ? 'Propón un precio competitivo para entrar en la conversación.'
                                  : 'Cuando lleguen propuestas de viajeros, aparecerán aquí para compararlas.',
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
                                              'US\$${offer.precio.toStringAsFixed(2)}',
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
                                              color: AppTheme.surfaceSoft,
                                              borderRadius: BorderRadius.circular(999),
                                              border: Border.all(color: AppTheme.border),
                                            ),
                                            child: Text(
                                              formatStatus(offer.estado),
                                              style: TextStyle(
                                                color: offer.estado == 'accepted'
                                                    ? AppTheme.accent
                                                    : Colors.white,
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
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _OfferChip(
                                            label: 'Score ${offer.marketplaceScore}',
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
                                            label: 'Verif ${offer.travelerVerificationScore}',
                                            color: const Color(0xFFFFD27A),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        offer.estado == 'accepted'
                                            ? 'Esta oferta ya quedó seleccionada para el envío.'
                                            : 'Oferta activa lista para evaluación.',
                                        style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rating ${offer.travelerRatingAvg.toStringAsFixed(1)} • Cumplimiento ${(offer.acceptanceRate * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        offer.mensaje,
                                        style: const TextStyle(color: AppTheme.muted),
                                      ),
                                      if (offer.marketplaceInsights.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        ...offer.marketplaceInsights.take(3).map(
                                          (insight) => Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Text(
                                              '• $insight',
                                              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                            ),
                                          ),
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

