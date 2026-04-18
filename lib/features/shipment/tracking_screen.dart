import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/services/image_service.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/features/disputes/services/dispute_service.dart';
import 'package:iway_app/features/tracking/models/tracking_timeline_item.dart';
import 'package:iway_app/features/tracking/services/tracking_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/services/upload_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';
import 'package:iway_app/shared/ui/app_skeleton.dart';

class TrackingScreen extends StatefulWidget {
  final String shipmentId;

  const TrackingScreen({super.key, required this.shipmentId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final shipmentService = ShipmentService();
  final trackingService = TrackingService();
  final imageService = ImageService();
  final uploadService = UploadService();
  final realtime = RealtimeService.instance;
  final disputeService = DisputeService();

  List<File> deliveryProofImages = [];

  ShipmentModel? shipment;
  List<TrackingTimelineItem> timeline = [];
  Map<String, dynamic> eta = const {};
  bool loading = true;
  bool updatingStatus = false;
  StreamSubscription<dynamic>? trackingSubscription;
  StreamSubscription<dynamic>? shipmentStatusSubscription;

  bool get _isPrivilegedOperator {
    final role = SessionService.currentUser?.tipo;
    return role == 'admin' || role == 'support';
  }

  bool get _isAssignedTraveler {
    final currentUserId = SessionService.currentUserId;
    if (shipment == null || currentUserId == null || currentUserId.isEmpty) return false;
    return shipment!.assignedTravelerId == currentUserId;
  }

  @override
  void initState() {
    super.initState();
    loadTrackingData();
    bindRealtime();
  }

  Future<void> bindRealtime() async {
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
  }

  Future<void> loadTrackingData() async {
    try {
      final shipmentData = await shipmentService.getShipmentById(widget.shipmentId);
      final timelineData = await trackingService.getTimeline(widget.shipmentId);
      final etaData = await trackingService.getEta(widget.shipmentId);

      if (!mounted) return;

      setState(() {
        shipment = shipmentData;
        timeline = timelineData;
        eta = etaData;
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
        const SnackBar(content: Text('No se pudo cargar el tracking.')),
      );
    }
  }

  Future<void> openDispute() async {
    final reasonController = TextEditingController();
    final contextController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Reportar incidente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Qué pasó'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contextController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Contexto operativo adicional'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Abrir disputa')),
        ],
      ),
    );

    if (confirmed != true || reasonController.text.trim().length < 8) return;

    try {
      await disputeService.createDispute(
        shipmentId: widget.shipmentId,
        reason: reasonController.text.trim(),
        context: contextController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disputa abierta. El equipo operativo la revisará.')),
      );
      await loadTrackingData();
      if (!mounted) return;
      Navigator.pushNamed(context, '/support');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> addDeliveryProofImage() async {
    final image = await imageService.takePhoto();
    if (image == null) return;

    setState(() {
      deliveryProofImages.add(image);
    });
  }

  Future<void> updateStatus(String status) async {
    if (status == 'delivered' && deliveryProofImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos una evidencia de entrega antes de marcarlo como entregado.')),
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

      final updated = await shipmentService.updateStatus(
        widget.shipmentId,
        status,
        imageUrls: uploadedProofUrls,
      );

      if (!mounted) return;

      setState(() {
        shipment = updated;
        if (status == 'delivered') {
          deliveryProofImages = [];
        }
      });

      await loadTrackingData();
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
    } finally {
      if (mounted) {
        setState(() => updatingStatus = false);
      }
    }
  }

  String formatTimelineItem(TrackingTimelineItem item) {
    if (item.kind == 'tracking') {
      final lat = item.payload['lat'];
      final lng = item.payload['lng'];
      return 'Ubicación reportada: $lat, $lng';
    }

    return item.type.replaceAll('_', ' ');
  }

  String formatStatus(String estado) {
    switch (estado) {
      case 'published':
        return 'Publicado';
      case 'offered':
        return 'Con ofertas';
      case 'assigned':
        return 'Asignado';
      case 'picked_up':
        return 'Recogido';
      case 'in_transit':
        return 'En ruta';
      case 'in_delivery':
        return 'Por entregar';
      case 'delivered':
        return 'Entregado';
      default:
        return estado;
    }
  }

  int statusIndex(String estado) {
    switch (estado) {
      case 'published':
        return 0;
      case 'offered':
        return 1;
      case 'assigned':
        return 2;
      case 'picked_up':
        return 3;
      case 'in_transit':
        return 4;
      case 'in_delivery':
        return 5;
      case 'delivered':
        return 6;
      default:
        return 0;
    }
  }

  ({String status, String label})? nextOperationalAction(String estado) {
    switch (estado) {
      case 'assigned':
        return (status: 'picked_up', label: 'Marcar recogido');
      case 'picked_up':
        return (status: 'in_transit', label: 'Marcar en ruta');
      case 'in_transit':
        return (status: 'in_delivery', label: 'Marcar por entregar');
      case 'in_delivery':
        return (status: 'delivered', label: 'Marcar entregado');
      default:
        return null;
    }
  }

  Widget buildStep(String title, bool active) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active ? Colors.white : AppTheme.surfaceSoft,
            shape: BoxShape.circle,
            border: Border.all(color: active ? Colors.white : AppTheme.border),
          ),
          child: Icon(
            active ? Icons.check_rounded : Icons.circle,
            size: active ? 16 : 8,
            color: active ? Colors.black : AppTheme.muted,
          ),
        ),
        const SizedBox(width: 12),
        Text(title),
      ],
    );
  }

  String _resolveImageUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '${ApiClient.baseUrl}$value';
  }

  void openImagePreview({String? networkUrl, File? localFile, String? title}) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                color: Colors.black,
                constraints: const BoxConstraints(maxHeight: 620),
                width: double.infinity,
                child: InteractiveViewer(
                  child: networkUrl != null
                      ? Image.network(
                          _resolveImageUrl(networkUrl),
                          fit: BoxFit.contain,
                          headers: SessionService.currentAccessToken == null || SessionService.currentAccessToken!.isEmpty
                              ? null
                              : {'Authorization': 'Bearer ${SessionService.currentAccessToken!}'},
                        )
                      : Image.file(localFile!, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              right: 64,
              child: Text(
                title ?? 'Vista previa',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildRemoteGallery(String title, List<String> images) {
    if (images.isEmpty) {
      return AppGlassSection(
        title: title,
        child: const Text(
          'Aún no hay imágenes disponibles en esta sección.',
          style: TextStyle(color: AppTheme.muted),
        ),
      );
    }

    final token = SessionService.currentAccessToken;
    return AppGlassSection(
      title: title,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: images.map((imageUrl) {
          return InkWell(
            onTap: () => openImagePreview(networkUrl: imageUrl, title: title),
            borderRadius: BorderRadius.circular(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                _resolveImageUrl(imageUrl),
                width: 92,
                height: 92,
                fit: BoxFit.cover,
                headers: token == null || token.isEmpty
                    ? null
                    : {'Authorization': 'Bearer $token'},
                errorBuilder: (_, __, ___) => Container(
                  width: 92,
                  height: 92,
                  color: AppTheme.surfaceSoft,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined, color: AppTheme.muted),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    trackingSubscription?.cancel();
    shipmentStatusSubscription?.cancel();
    super.dispose();
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
              AppSkeletonBlock(height: 16, width: 280),
              SizedBox(height: 24),
              AppSkeletonBlock(height: 140, radius: 28),
              SizedBox(height: 16),
              AppSkeletonBlock(height: 160, radius: 28),
              SizedBox(height: 16),
              AppSkeletonBlock(height: 220, radius: 28),
            ],
          ),
        ),
      );
    }

    if (shipment == null) {
      return Scaffold(
        body: Container(
          color: AppTheme.background,
          child: const Center(
            child: Text('No se encontró el envío.'),
          ),
        ),
      );
    }

    final estado = shipment!.estado;
    final currentStep = statusIndex(estado);
    final etaMinutes = eta['etaMinutes'];
    final etaLabel = etaMinutes == null
        ? (eta['reason']?.toString() ?? 'ETA no disponible')
        : '$etaMinutes min';

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                const SizedBox(height: 24),
                const AppPageIntro(
                  title: 'Tracking del envío',
                  subtitle: 'Estado, ETA y eventos relevantes en una sola vista.',
                ),
                const SizedBox(height: 20),
                AppGlassSection(
                  title: 'Estado actual',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          formatStatus(estado),
                          key: ValueKey(estado),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          'ETA: $etaLabel',
                          key: ValueKey(etaLabel),
                          style: const TextStyle(color: AppTheme.muted),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        currentStep >= 6
                            ? 'Este envío ya fue marcado como entregado.'
                            : currentStep >= 2
                                ? 'El envío ya va en operación. Avánzalo por fases para que el cliente vea progreso real.'
                                : 'Todavía puedes avanzar el estado cuando el envío cambie de fase.',
                        style: const TextStyle(color: AppTheme.muted, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppGlassSection(
                  title: 'Progreso',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildStep('Publicado', currentStep >= 0),
                      const SizedBox(height: 12),
                      buildStep('Con ofertas', currentStep >= 1),
                      const SizedBox(height: 12),
                      buildStep('Asignado', currentStep >= 2),
                      const SizedBox(height: 12),
                      buildStep('Recogido', currentStep >= 3),
                      const SizedBox(height: 12),
                      buildStep('En ruta', currentStep >= 4),
                      const SizedBox(height: 12),
                      buildStep('Por entregar', currentStep >= 5),
                      const SizedBox(height: 12),
                      buildStep('Entregado', currentStep >= 6),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppGlassSection(
                  title: 'Acciones rápidas',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (currentStep < 6) ...[
                        const Text(
                          'Evidencia de entrega',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          deliveryProofImages.isEmpty
                              ? 'Agrega al menos una foto antes de cerrar el envío como entregado.'
                              : '${deliveryProofImages.length} evidencia(s) listas para subir.',
                          style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: updatingStatus ? null : addDeliveryProofImage,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Agregar evidencia'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppTheme.border),
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        if (deliveryProofImages.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: deliveryProofImages.asMap().entries.map((entry) {
                              final index = entry.key;
                              final img = entry.value;
                              return Stack(
                                children: [
                                  InkWell(
                                    onTap: () => openImagePreview(localFile: img, title: 'Evidencia de entrega'),
                                    borderRadius: BorderRadius.circular(16),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.file(
                                        img,
                                        height: 82,
                                        width: 82,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: updatingStatus
                                          ? null
                                          : () {
                                              setState(() {
                                                deliveryProofImages.removeAt(index);
                                              });
                                            },
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.black87,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (_isPrivilegedOperator) ...[
                          ElevatedButton(
                            onPressed: updatingStatus || currentStep >= 2
                                ? null
                                : () => updateStatus('assigned'),
                            child: const Text('Marcar asignado'),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Builder(
                          builder: (context) {
                            final nextAction = nextOperationalAction(estado);
                            return ElevatedButton(
                              onPressed: updatingStatus || nextAction == null || (!_isPrivilegedOperator && !_isAssignedTraveler)
                                  ? null
                                  : () => updateStatus(nextAction.status),
                              child: Text(nextAction?.label ?? 'Sin acción disponible'),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        if (updatingStatus) ...[
                          const Text(
                            'Actualizando estado del envío...',
                            style: TextStyle(color: AppTheme.muted, fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                        ],
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/map',
                              arguments: widget.shipmentId,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppTheme.border),
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('Ver ruta y ubicación'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/chat',
                              arguments: widget.shipmentId,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppTheme.border),
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('Abrir chat'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: openDispute,
                          icon: const Icon(Icons.report_problem_outlined),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppTheme.border),
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          label: const Text('Reportar incidente'),
                        ),
                      ] else ...[
                        const Text(
                          'Este envío ya fue cerrado. Solo queda consultar la evidencia guardada, la ruta final y dejar una calificación.',
                          style: TextStyle(color: AppTheme.muted, height: 1.35),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/map',
                              arguments: widget.shipmentId,
                            );
                          },
                          child: const Text('Ver ruta final'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/rating',
                              arguments: widget.shipmentId,
                            );
                          },
                          icon: const Icon(Icons.star_outline_rounded),
                          label: const Text('Calificar experiencia'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                buildRemoteGallery('Fotos del paquete', shipment!.imagenesReferencia),
                const SizedBox(height: 16),
                buildRemoteGallery('Evidencias de entrega guardadas', shipment!.evidenciasEntrega),
                const SizedBox(height: 16),
                AppGlassSection(
                  title: 'Timeline',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (timeline.isEmpty)
                        const Text(
                          'Todavía no hay eventos de tracking. Cuando empiecen los reportes o cambios de estado, aparecerán aquí.',
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
                                Icon(
                                  item.kind == 'tracking' ? Icons.place_rounded : Icons.event_note_rounded,
                                  color: AppTheme.accent,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formatTimelineItem(item),
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.at.toString(),
                                        style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                                      ),
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

