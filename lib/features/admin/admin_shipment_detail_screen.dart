import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/matching/models/offer_model.dart';
import 'package:iway_app/features/matching/services/matching_service.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/features/tracking/models/tracking_timeline_item.dart';
import 'package:iway_app/features/tracking/services/tracking_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class AdminShipmentDetailScreen extends StatefulWidget {
  final String shipmentId;

  const AdminShipmentDetailScreen({super.key, required this.shipmentId});

  @override
  State<AdminShipmentDetailScreen> createState() => _AdminShipmentDetailScreenState();
}

class _AdminShipmentDetailScreenState extends State<AdminShipmentDetailScreen> {
  final shipmentService = ShipmentService();
  final matchingService = MatchingService();
  final trackingService = TrackingService();

  ShipmentModel? shipment;
  List<OfferModel> offers = [];
  List<TrackingTimelineItem> timeline = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final shipmentData = await shipmentService.getShipmentById(widget.shipmentId);
      final offersData = await matchingService.getOffers(widget.shipmentId);
      final timelineData = await trackingService.getTimeline(widget.shipmentId);
      if (!mounted) return;
      setState(() {
        shipment = shipmentData;
        offers = offersData;
        timeline = timelineData;
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar el detalle operativo.')),
      );
    }
  }

  Widget buildGallery(List<String> images) {
    final token = SessionService.currentAccessToken;
    if (images.isEmpty) {
      return const Text('Sin imágenes.', style: TextStyle(color: AppTheme.muted));
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: images.map((imageUrl) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            '${ApiClient.baseUrl}$imageUrl',
            width: 90,
            height: 90,
            fit: BoxFit.cover,
            headers: token == null || token.isEmpty ? null : {'Authorization': 'Bearer $token'},
            errorBuilder: (_, __, ___) => Container(
              width: 90,
              height: 90,
              color: AppTheme.surfaceSoft,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined, color: AppTheme.muted),
            ),
          ),
        );
      }).toList(),
    );
  }

  String formatEvent(TrackingTimelineItem item) {
    if (item.kind == 'tracking') {
      return 'Ubicación: ${item.payload['lat']}, ${item.payload['lng']}';
    }
    return item.type.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = shipment;
    if (data == null) {
      return const Scaffold(
        body: Center(child: Text('No se encontró el envío.')),
      );
    }

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                const SizedBox(height: 24),
                AppPageIntro(
                  title: 'Shipment ${data.id}',
                  subtitle: 'Vista operativa unificada para soporte y administración.',
                ),
                const SizedBox(height: 18),
                AppGlassSection(
                  title: 'Resumen',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estado: ${data.estado}'),
                      const SizedBox(height: 6),
                      Text('Ruta: ${data.origen} → ${data.destino}'),
                      const SizedBox(height: 6),
                      Text('Receptor: ${data.receptorNombre} • ${data.receptorTelefono}'),
                      const SizedBox(height: 6),
                      Text('Valor declarado: \$${data.valor.toStringAsFixed(2)}'),
                      if (data.descripcion?.isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        Text(data.descripcion!, style: const TextStyle(color: AppTheme.muted)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppGlassSection(title: 'Fotos del paquete', child: buildGallery(data.imagenesReferencia)),
                const SizedBox(height: 16),
                AppGlassSection(title: 'Evidencias de entrega', child: buildGallery(data.evidenciasEntrega)),
                const SizedBox(height: 16),
                AppGlassSection(
                  title: 'Ofertas (${offers.length})',
                  child: offers.isEmpty
                      ? const Text('Sin ofertas todavía.', style: TextStyle(color: AppTheme.muted))
                      : Column(
                          children: offers.map((offer) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
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
                                    Text('Q${offer.precio.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text('Traveler: ${offer.travelerId}', style: const TextStyle(color: AppTheme.muted)),
                                    const SizedBox(height: 4),
                                    Text('Estado: ${offer.estado}', style: const TextStyle(color: AppTheme.muted)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 16),
                AppGlassSection(
                  title: 'Timeline (${timeline.length})',
                  child: timeline.isEmpty
                      ? const Text('Sin eventos todavía.', style: TextStyle(color: AppTheme.muted))
                      : Column(
                          children: timeline.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.event_note_outlined, color: AppTheme.accent),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(formatEvent(item), style: const TextStyle(fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(item.at.toString(), style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
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
