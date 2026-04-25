import 'dart:async';
import 'dart:io';

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/services/image_service.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/features/shipment/services/shipment_ticket_service.dart';
import 'package:iway_app/features/tracking/models/tracking_timeline_item.dart';
import 'package:iway_app/features/tracking/services/tracking_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/services/upload_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_skeleton.dart';
import 'package:iway_app/shared/utils/shipment_status_presenter.dart';

class TrackingScreen extends StatefulWidget {
  final String shipmentId;
  final ShipmentModel? initialShipment;

  const TrackingScreen({
    super.key,
    required this.shipmentId,
    this.initialShipment,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> with WidgetsBindingObserver {
  final shipmentService = ShipmentService();
  final trackingService = TrackingService();
  final imageService = ImageService();
  final uploadService = UploadService();
  final realtime = RealtimeService.instance;
  final ticketService = const ShipmentTicketService();

  ShipmentModel? shipment;
  List<TrackingTimelineItem> timeline = [];
  Map<String, dynamic> eta = const {};
  bool loading = true;
  bool updatingStatus = false;
  double? routeDistanceKm;
  int? routeDurationMinutes;
  List<File> deliveryProofImages = [];
  StreamSubscription<dynamic>? trackingSubscription;
  StreamSubscription<dynamic>? shipmentStatusSubscription;
  StreamSubscription<dynamic>? globalSyncSubscription;

  bool get _isTraveler => SessionService.currentUser?.tipo == 'traveler';
  bool get _isCustomer => !_isTraveler;

  bool get _isAssignedTraveler {
    final currentUserId = SessionService.currentUserId;
    if (shipment == null || currentUserId == null || currentUserId.isEmpty) return false;
    return shipment!.assignedTravelerId == currentUserId;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    shipment = widget.initialShipment;
    loading = widget.initialShipment == null;
    loadTrackingData();
    bindRealtime();
  }

  Future<void> bindRealtime() async {
    await realtime.ensureConnected();
    await realtime.joinTracking(widget.shipmentId);
    trackingSubscription = realtime.trackingUpdated.listen((data) {
      if (data is Map && data['shipmentId']?.toString() == widget.shipmentId) {
        loadTrackingData();
      }
    });
    shipmentStatusSubscription = realtime.shipmentStatusChanged.listen((data) {
      if (data is Map && data['shipmentId']?.toString() == widget.shipmentId) {
        loadTrackingData();
      }
    });
    globalSyncSubscription = realtime.globalEntitySync.listen((event) {
      if (event is! Map) return;
      final payload = event['payload'];
      if (payload is Map && payload['shipmentId']?.toString() == widget.shipmentId) {
        loadTrackingData();
      }
    });
  }

  Future<void> loadTrackingData() async {
    try {
      final shipmentData = await shipmentService.getShipmentById(widget.shipmentId);
      final timelineData = await trackingService.getTimeline(widget.shipmentId);
      final etaData = await trackingService.getEta(widget.shipmentId);
      final routeData = await trackingService.getRoute(widget.shipmentId);

      if (!mounted) return;
      setState(() {
        shipment = shipmentData;
        timeline = timelineData;
        eta = etaData;
        routeDistanceKm = routeData['distanceKm'] is num ? (routeData['distanceKm'] as num).toDouble() : null;
        routeDurationMinutes = routeData['durationMinutes'] is num ? (routeData['durationMinutes'] as num).round() : null;
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
        const SnackBar(content: Text('No se pudo cargar el envío.')),
      );
    }
  }

  bool get _hasLiveTrackingData {
    final etaMinutes = eta['etaMinutes'];
    return routeDistanceKm != null || routeDurationMinutes != null || etaMinutes is num;
  }

  int _customerStepperIndex(String estado) {
    switch (estado) {
      case 'assigned':
        return 0;
      case 'picked_up':
        return 1;
      case 'in_transit':
      case 'arrived':
      case 'in_delivery':
        return 2;
      case 'delivered':
        return 3;
      default:
        return -1;
    }
  }

  String _maskedShipmentId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '------';
    final suffix = trimmed.length <= 6 ? trimmed : trimmed.substring(trimmed.length - 6);
    return '...${suffix.toUpperCase()}';
  }

  String _packageTitle() {
    return shipment?.descripcion?.trim().isNotEmpty == true ? shipment!.descripcion!.trim() : shipment?.tipo ?? 'Paquete';
  }

  String _routeLabel() {
    final current = shipment;
    if (current == null) return 'Ruta pendiente';
    final origin = current.remitenteRegion.trim().isNotEmpty ? current.remitenteRegion.trim() : current.origen;
    final destination = current.receptorDireccion.trim().isNotEmpty ? current.receptorDireccion.trim() : current.destino;
    return '$origin → $destination';
  }

  String _taskTitle(String estado) {
    switch (estado) {
      case 'assigned':
        return 'Tarea actual: Recoger paquete #${_maskedShipmentId(widget.shipmentId)}';
      case 'picked_up':
      case 'in_transit':
      case 'arrived':
      case 'in_delivery':
        return 'Tarea actual: Entregar paquete #${_maskedShipmentId(widget.shipmentId)}';
      case 'delivered':
        return 'Entrega completada';
      default:
        return 'Seguimiento del envío';
    }
  }

  ({String status, String label})? _nextOperationalAction(String estado) {
    switch (estado) {
      case 'assigned':
        return (status: 'picked_up', label: 'Confirmar carga');
      case 'picked_up':
      case 'in_transit':
      case 'arrived':
      case 'in_delivery':
        return (status: 'delivered', label: 'Confirmar entrega');
      default:
        return null;
    }
  }

  Future<void> addDeliveryProofImage() async {
    final image = await imageService.takePhoto();
    if (image == null) return;
    setState(() => deliveryProofImages.add(image));
  }

  Future<void> updateStatus(String status) async {
    if (status == 'delivered' && deliveryProofImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos una evidencia antes de confirmar la entrega.')),
      );
      return;
    }

    setState(() => updatingStatus = true);

    try {
      List<String>? uploadedProofUrls;
      if (status == 'delivered') {
        uploadedProofUrls = [];
        for (var i = 0; i < deliveryProofImages.length; i++) {
          final imageUrl = await uploadService.uploadImage(
            file: deliveryProofImages[i],
            bucket: 'shipment-images',
            fileName: 'delivery-proof-${widget.shipmentId}-$i-${DateTime.now().millisecondsSinceEpoch}',
          );
          uploadedProofUrls.add(imageUrl);
        }
      }

      await shipmentService.updateStatus(widget.shipmentId, status, imageUrls: uploadedProofUrls);
      if (!mounted) return;
      if (status == 'delivered') {
        setState(() => deliveryProofImages = []);
      }
      await loadTrackingData();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el estado del envío.')),
      );
    } finally {
      if (mounted) {
        setState(() => updatingStatus = false);
      }
    }
  }

  String formatTimelineItem(TrackingTimelineItem item) {
    if (item.kind == 'tracking') {
      final checkpoint = item.payload['checkpoint']?.toString();
      if (checkpoint != null && checkpoint.trim().isNotEmpty) {
        return 'Ubicación reportada en $checkpoint';
      }
      return 'Ubicación actualizada';
    }

    switch (item.type) {
      case 'shipment_created':
        return 'Envío creado';
      case 'offer_created':
        return 'Oferta recibida';
      case 'offer_accepted':
        return 'Oferta aceptada';
      case 'status_changed':
        final nextStatus = item.payload['toStatus']?.toString();
        return nextStatus == null || nextStatus.isEmpty
            ? 'Estado actualizado'
            : 'Estado actualizado a ${ShipmentStatusPresenter.label(nextStatus)}';
      default:
        return item.type.replaceAll('_', ' ');
    }
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year - $hour:$minute';
  }

  Future<void> _openReceiptPdf() async {
    final currentShipment = shipment;
    if (currentShipment == null) return;
    await ticketService.openReceiptPdf(currentShipment);
  }

  Future<void> _addPickupToCalendar() async {
    final currentShipment = shipment;
    final pickupAt = currentShipment?.pickupScheduledAt;
    if (currentShipment == null || pickupAt == null) return;

    final reference = currentShipment.travelerAnnouncementProducts.isNotEmpty
        ? 'Permitidos por viajero: ${currentShipment.travelerAnnouncementProducts.join(', ')}'
        : '';

    final event = Event(
      title: 'Recolección IWAY ${_maskedShipmentId(currentShipment.id)}',
      description: [currentShipment.descripcion ?? currentShipment.tipo, reference]
          .where((item) => item.trim().isNotEmpty)
          .join(' • '),
      location: currentShipment.remitenteDireccion,
      startDate: pickupAt,
      endDate: pickupAt.add(const Duration(minutes: 45)),
    );

    await Add2Calendar.addEvent2Cal(event);
  }

  Widget _buildCustomerStepper(String estado) {
    const steps = ['Asignado', 'Recogido', 'En ruta', 'Entregado'];
    final current = _customerStepperIndex(estado);

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final activeConnector = current >= (index ~/ 2) + 1;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: activeConnector ? Colors.white : AppTheme.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        }

        final stepIndex = index ~/ 2;
        final active = current >= stepIndex;
        return Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: active ? Colors.white : AppTheme.surfaceSoft,
                shape: BoxShape.circle,
                border: Border.all(color: active ? Colors.white : AppTheme.border, width: 0.5),
              ),
              child: Icon(
                stepIndex == 0
                    ? Icons.assignment_turned_in_outlined
                    : stepIndex == 1
                        ? Icons.inventory_2_outlined
                        : stepIndex == 2
                            ? Icons.local_shipping_outlined
                            : Icons.check_circle_outline_rounded,
                color: active ? Colors.black : AppTheme.muted,
                size: 18,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 70,
              child: Text(
                steps[stepIndex],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: active ? Colors.white : AppTheme.muted,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTravelerTaskCard() {
    final current = shipment!;
    final nextAction = _nextOperationalAction(current.estado);
    final canOperate = _isAssignedTraveler;

    return AppGlassSection(
      title: _taskTitle(current.estado),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_packageTitle(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(ShipmentStatusPresenter.label(current.estado), style: const TextStyle(color: AppTheme.muted)),
          if (nextAction != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: updatingStatus || !canOperate ? null : () => updateStatus(nextAction.status),
              child: Text(nextAction.label),
            ),
          ],
          if (!canOperate) ...[
            const SizedBox(height: 8),
            const Text(
              'Solo el viajero asignado puede avanzar esta tarea.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPickupPointsCard() {
    final current = shipment!;
    final showOperationalData = _isTraveler && _isAssignedTraveler && current.estado != 'offered';
    if (!showOperationalData) return const SizedBox.shrink();

    final enRuta = current.estado == 'picked_up' || current.estado == 'in_transit' || current.estado == 'arrived' || current.estado == 'in_delivery' || current.estado == 'delivered';
    final title = enRuta ? 'Punto de entrega' : 'Puntos de recolección';
    final chatDraft = enRuta
        ? 'Hola, voy en camino a entregar el paquete #${_maskedShipmentId(widget.shipmentId)}.'
        : 'Hola, voy en camino por el paquete #${_maskedShipmentId(widget.shipmentId)}.';

    return AppGlassSection(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!enRuta) ...[
            _DetailRow(label: 'Recoger a', value: current.remitenteNombre.isEmpty ? 'Pendiente' : current.remitenteNombre),
            const SizedBox(height: 10),
            _DetailRow(label: 'Dirección exacta', value: current.remitenteDireccion.isEmpty ? 'Pendiente' : current.remitenteDireccion),
            const SizedBox(height: 10),
            _DetailRow(label: 'Teléfono', value: current.remitenteTelefono.isEmpty ? 'Pendiente' : current.remitenteTelefono),
          ] else ...[
            _DetailRow(label: 'Entregar a', value: current.receptorNombre.isEmpty ? 'Pendiente' : current.receptorNombre),
            const SizedBox(height: 10),
            _DetailRow(label: 'Dirección exacta', value: current.receptorDireccion.isEmpty ? 'Pendiente' : current.receptorDireccion),
            const SizedBox(height: 10),
            _DetailRow(label: 'Teléfono', value: current.receptorTelefono.isEmpty ? 'Pendiente' : current.receptorTelefono),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: {
                      'shipmentId': widget.shipmentId,
                      'initialDraft': chatDraft,
                    },
                  ),
                  child: const Text('Abrir chat'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/map',
                    arguments: {
                      'shipmentId': widget.shipmentId,
                      'focus': enRuta ? 'delivery' : 'pickup',
                      'title': enRuta ? 'Ruta a entrega' : 'Ruta a recolección',
                    },
                  ),
                  child: Text(enRuta ? 'Ir a entrega' : 'Ver ruta'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerProgressCard() {
    final current = shipment!;
    final inTransit = current.estado == 'in_transit' || current.estado == 'arrived' || current.estado == 'in_delivery' || current.estado == 'delivered';
    final etaMinutes = eta['etaMinutes'];
    final etaLabel = etaMinutes is num ? '${etaMinutes.round()} min' : null;

    return AppGlassSection(
      title: 'Estado de tu envío',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCustomerStepper(current.estado),
          if (inTransit) ...[
            const SizedBox(height: 16),
            if (_hasLiveTrackingData) ...[
              Row(
                children: [
                  if (etaLabel != null) Expanded(child: _MetricCard(label: 'ETA', value: etaLabel)),
                  if (etaLabel != null && routeDistanceKm != null) const SizedBox(width: 10),
                  if (routeDistanceKm != null)
                    Expanded(
                      child: _MetricCard(
                        label: 'Ruta',
                        value: '${routeDistanceKm!.toStringAsFixed(1)} km',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/map',
                  arguments: {
                    'shipmentId': widget.shipmentId,
                    'focus': 'delivery',
                    'title': 'Ruta de entrega',
                  },
                ),
                child: const Text('Ver mapa'),
              ),
            ] else
              const Text(
                'El seguimiento iniciará cuando el viajero recoja el paquete.',
                style: TextStyle(color: AppTheme.muted, height: 1.35),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfferReviewCard() {
    if (shipment!.estado != 'offered' || !_isCustomer) return const SizedBox.shrink();
    return AppGlassSection(
      title: 'Oferta del viajero',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revisa y acepta la oferta desde la lista. Aquí no verás resumen técnico innecesario.'),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/offers', arguments: widget.shipmentId),
            child: const Text('Revisar ofertas'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryProofSection() {
    if (!_isTraveler || _nextOperationalAction(shipment!.estado)?.status != 'delivered') {
      return const SizedBox.shrink();
    }

    return AppGlassSection(
      title: 'Evidencia de entrega',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deliveryProofImages.isEmpty
                ? 'Agrega al menos una foto antes de confirmar la entrega.'
                : '${deliveryProofImages.length} evidencia(s) listas para subir.',
            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: updatingStatus ? null : addDeliveryProofImage,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Agregar evidencia'),
          ),
          if (deliveryProofImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: deliveryProofImages.asMap().entries.map((entry) {
                final index = entry.key;
                final image = entry.value;
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(image, height: 82, width: 82, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: updatingStatus
                            ? null
                            : () => setState(() {
                                  deliveryProofImages.removeAt(index);
                                }),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    trackingSubscription?.cancel();
    shipmentStatusSubscription?.cancel();
    globalSyncSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadTrackingData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        body: Container(
          color: AppTheme.background,
          padding: const EdgeInsets.fromLTRB(22, 48, 22, 22),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeletonBlock(height: 42, width: 42, radius: 14),
              SizedBox(height: 24),
              AppSkeletonBlock(height: 26, width: 220),
              SizedBox(height: 12),
              AppSkeletonBlock(height: 160, radius: 28),
              SizedBox(height: 16),
              AppSkeletonBlock(height: 180, radius: 28),
            ],
          ),
        ),
      );
    }

    if (shipment == null) {
      return const Scaffold(body: Center(child: Text('No se encontró el envío.')));
    }

    final delivered = shipment!.estado == 'delivered';
    final pickupPointsCard = _buildPickupPointsCard();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.background, Color(0xFF101116), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                const SizedBox(height: 18),
                Text('Envío #${_maskedShipmentId(widget.shipmentId)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(ShipmentStatusPresenter.label(shipment!.estado), style: const TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 18),
                if (_isTraveler) _buildTravelerTaskCard() else _buildCustomerProgressCard(),
                if (_isCustomer) ...[
                  const SizedBox(height: 16),
                  _buildOfferReviewCard(),
                ],
                const SizedBox(height: 16),
                pickupPointsCard,
                if (pickupPointsCard is! SizedBox) const SizedBox(height: 16),
                AppGlassSection(
                  title: 'Detalles esenciales',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(label: 'Paquete', value: _packageTitle()),
                      const SizedBox(height: 10),
                      _DetailRow(label: 'Ruta', value: _routeLabel()),
                      const SizedBox(height: 10),
                      _DetailRow(label: 'Destinatario', value: shipment!.receptorNombre.isEmpty ? 'Pendiente' : shipment!.receptorNombre),
                      if (shipment!.pickupScheduledAt != null) ...[
                        const SizedBox(height: 10),
                        _DetailRow(label: 'Cita de recolección', value: _formatDate(shipment!.pickupScheduledAt!)),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _addPickupToCalendar,
                          icon: const Icon(Icons.event_outlined),
                          label: const Text('Añadir al calendario'),
                        ),
                      ],
                      if (shipment!.travelerAnnouncementProducts.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _DetailRow(
                          label: 'Referencia del servicio',
                          value: shipment!.travelerAnnouncementProducts.join(', '),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildDeliveryProofSection(),
                if (_isTraveler && _nextOperationalAction(shipment!.estado)?.status == 'delivered') const SizedBox(height: 16),
                AppGlassSection(
                  title: delivered ? 'Recibo' : 'Acciones',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (delivered) ...[
                        ElevatedButton.icon(
                          onPressed: _openReceiptPdf,
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Ver recibo'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/rating', arguments: widget.shipmentId),
                          icon: const Icon(Icons.star_outline_rounded),
                          label: const Text('Calificar entrega'),
                        ),
                      ] else ...[
                        if (_isTraveler)
                          OutlinedButton(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/chat',
                              arguments: {
                                'shipmentId': widget.shipmentId,
                                'initialDraft': 'Hola, escribo por el paquete #${_maskedShipmentId(widget.shipmentId)}.',
                              },
                            ),
                            child: const Text('Abrir chat'),
                          ),
                        if (_isTraveler) const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/map',
                            arguments: {
                              'shipmentId': widget.shipmentId,
                              'focus': _isTraveler && (shipment!.estado == 'assigned') ? 'pickup' : 'delivery',
                              'title': _isTraveler && (shipment!.estado == 'assigned') ? 'Ruta a recolección' : 'Ruta de entrega',
                            },
                          ),
                          child: Text(_isTraveler ? 'Abrir ruta' : 'Ver mapa'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppGlassSection(
                  title: 'Historial del envío',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (timeline.isEmpty)
                        const Text(
                          'Todavía no hay eventos para este envío.',
                          style: TextStyle(color: AppTheme.muted, height: 1.35),
                        )
                      else
                        ...timeline.map(
                          (item) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceSoft,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(item.kind == 'tracking' ? Icons.place_rounded : Icons.event_note_rounded, color: AppTheme.accent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(formatTimelineItem(item), style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text(_formatDate(item.at), style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
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

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppTheme.muted))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
    );
  }
}
