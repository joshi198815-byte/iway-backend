import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/services/location_service.dart';
import 'package:iway_app/features/tracking/models/tracking_point_model.dart';
import 'package:iway_app/features/tracking/services/tracking_service.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_info_chip.dart';

class MapScreen extends StatefulWidget {
  final String? shipmentId;

  const MapScreen({super.key, this.shipmentId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  GoogleMapController? mapController;

  final locationService = LocationService();
  final trackingService = TrackingService();
  final shipmentService = ShipmentService();

  ShipmentModel? shipment;

  LatLng currentPosition = const LatLng(14.6349, -90.5069);
  StreamSubscription? locationSubscription;
  StreamSubscription<dynamic>? trackingSubscription;
  StreamSubscription<dynamic>? shipmentStatusSubscription;
  final realtime = RealtimeService.instance;
  bool sending = false;
  bool loadingRemote = false;
  String? statusText;
  Set<Marker> routeMarkers = {};
  Set<Polyline> routePolylines = {};
  String? routeSummary;
  String? routeFallbackDetail;
  String routeProvider = 'estimated-segments';
  double? routeDistanceKm;
  int? routeDurationMinutes;

  LatLng? get _pickupPoint {
    final lat = shipment?.pickupLat;
    final lng = shipment?.pickupLng;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? get _deliveryPoint {
    final lat = shipment?.deliveryLat;
    final lng = shipment?.deliveryLng;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    startTracking();
    loadShipment();
    loadLatestTracking();
    loadRoute();
    bindRealtime();
  }

  Future<void> loadShipment() async {
    final shipmentId = widget.shipmentId;
    if (shipmentId == null || shipmentId.isEmpty) return;

    try {
      final data = await shipmentService.getShipmentById(shipmentId);
      if (!mounted) return;
      setState(() => shipment = data);
      await loadRoute();
    } catch (_) {}
  }

  Future<void> bindRealtime() async {
    final shipmentId = widget.shipmentId;
    if (shipmentId == null || shipmentId.isEmpty) return;

    await realtime.joinTracking(shipmentId);
    trackingSubscription = realtime.trackingUpdated.listen((data) {
      if (data is Map && data['shipmentId']?.toString() == shipmentId) {
        loadShipment();
        loadLatestTracking();
        loadRoute();
      }
    });
    shipmentStatusSubscription = realtime.shipmentStatusChanged.listen((data) {
      if (data is Map && data['shipmentId']?.toString() == shipmentId) {
        loadShipment();
        loadRoute();
      }
    });
  }

  Future<void> loadLatestTracking() async {
    final shipmentId = widget.shipmentId;
    if (shipmentId == null || shipmentId.isEmpty) return;

    setState(() => loadingRemote = true);

    try {
      final latest = await trackingService.getLatestLocation(shipmentId);
      _applyTrackingPoint(latest);
    } catch (_) {
      // Ignorar si todavía no existe tracking remoto.
    } finally {
      if (mounted) {
        setState(() => loadingRemote = false);
      }
    }
  }

  Future<void> _fitRouteBounds(List<LatLng> points) async {
    if (points.length < 2 || mapController == null) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 72),
    );
  }

  Future<void> loadRoute() async {
    final shipmentId = widget.shipmentId;
    if (shipmentId == null || shipmentId.isEmpty) return;

    String markerTitleForKind(String kind) {
      switch (kind) {
        case 'pickup':
          return 'Origen';
        case 'current':
          return 'Ubicación actual';
        case 'delivery':
          return 'Destino';
        default:
          return kind;
      }
    }

    BitmapDescriptor markerColorForKind(String kind) {
      switch (kind) {
        case 'pickup':
          return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
        case 'current':
          return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
        case 'delivery':
          return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        default:
          return BitmapDescriptor.defaultMarker;
      }
    }

    ({Set<Marker> markers, Set<Polyline> polylines, List<LatLng> fitPoints, String summary, String detail})
        buildFallback({String? reason}) {
      final fallbackMarkers = <Marker>{};
      final fallbackPoints = <LatLng>[];

      void addPoint(String id, String kind, LatLng? value) {
        if (value == null) return;
        fallbackPoints.add(value);
        fallbackMarkers.add(
          Marker(
            markerId: MarkerId(id),
            position: value,
            infoWindow: InfoWindow(title: markerTitleForKind(kind)),
            icon: markerColorForKind(kind),
          ),
        );
      }

      addPoint('pickup-fallback', 'pickup', _pickupPoint);
      addPoint('current-fallback', 'current', currentPosition);
      addPoint('delivery-fallback', 'delivery', _deliveryPoint);

      final fallbackPolyline = fallbackPoints.length >= 2
          ? {
              Polyline(
                polylineId: const PolylineId('shipment-route-fallback'),
                points: fallbackPoints,
                color: Colors.white70,
                width: 4,
                patterns: [PatternItem.dash(18), PatternItem.gap(10)],
              ),
            }
          : <Polyline>{};

      final detailParts = <String>[];
      if (_pickupPoint == null) detailParts.add('falta origen geolocalizado');
      if (_deliveryPoint == null) detailParts.add('falta destino geolocalizado');
      if (reason != null && reason.trim().isNotEmpty) detailParts.add(reason.trim());

      return (
        markers: fallbackMarkers,
        polylines: fallbackPolyline,
        fitPoints: fallbackPoints,
        summary: fallbackPoints.length >= 2
            ? 'Mostrando el trayecto disponible por ahora.'
            : 'El recorrido se completará cuando el envío tenga más puntos confirmados.',
        detail: detailParts.isEmpty
            ? 'Usando la información confirmada del envío.'
            : 'Seguimiento en preparación.',
      );
    }

    try {
      final route = await trackingService.getRoute(shipmentId);
      final polylinePoints = (route['polyline'] as List?)
              ?.whereType<Map>()
              .map((point) => point.map((k, v) => MapEntry(k.toString(), v)))
              .map(
                (point) => LatLng(
                  (point['lat'] as num).toDouble(),
                  (point['lng'] as num).toDouble(),
                ),
              )
              .toList() ??
          const <LatLng>[];

      final points = (route['points'] as List?)
              ?.whereType<Map>()
              .map((point) => point.map((k, v) => MapEntry(k.toString(), v)))
              .toList() ??
          const <Map<String, dynamic>>[];

      final markers = <Marker>{
        for (final point in points)
          Marker(
            markerId: MarkerId(point['kind']?.toString() ?? 'point'),
            position: LatLng(
              (point['lat'] as num).toDouble(),
              (point['lng'] as num).toDouble(),
            ),
            infoWindow: InfoWindow(title: markerTitleForKind(point['kind']?.toString() ?? 'point')),
            icon: markerColorForKind(point['kind']?.toString() ?? 'point'),
          ),
      };

      final polylines = polylinePoints.length >= 2
          ? {
              Polyline(
                polylineId: const PolylineId('shipment-route'),
                points: polylinePoints,
                color: AppTheme.accent,
                width: 5,
              ),
            }
          : <Polyline>{};

      final distanceKm = route['distanceKm'];
      final durationMinutes = route['durationMinutes'];
      final provider = route['provider']?.toString() ?? 'estimated-segments';
      final hasUsableRoute = markers.isNotEmpty || polylines.isNotEmpty;
      final fallback = buildFallback(reason: route['reason']?.toString());

      if (!mounted) return;
      setState(() {
        routeProvider = provider;
        routeDistanceKm = distanceKm is num ? distanceKm.toDouble() : null;
        routeDurationMinutes = durationMinutes is num ? durationMinutes.round() : null;
        routeMarkers = hasUsableRoute ? markers : fallback.markers;
        routePolylines = polylines.isNotEmpty ? polylines : fallback.polylines;
        routeSummary = distanceKm is num
            ? 'Recorrido ${distanceKm.toStringAsFixed(1)} km${durationMinutes is num ? ' · ${durationMinutes.round()} min' : ''}'
            : fallback.summary;
        routeFallbackDetail = distanceKm is num && hasUsableRoute ? null : fallback.detail;
      });

      await _fitRouteBounds(
        polylinePoints.length >= 2
            ? polylinePoints
            : (hasUsableRoute ? markers.map((e) => e.position).toList() : fallback.fitPoints),
      );
    } catch (_) {
      final fallback = buildFallback();
      if (!mounted) return;
      setState(() {
        routeMarkers = fallback.markers;
        routePolylines = fallback.polylines;
        routeSummary = fallback.summary;
        routeFallbackDetail = fallback.detail;
      });
      await _fitRouteBounds(fallback.fitPoints);
    }
  }

  void _applyTrackingPoint(TrackingPointModel point) {
    final newPos = LatLng(point.lat, point.lng);
    if (!mounted) return;

    setState(() {
      currentPosition = newPos;
      statusText = 'Última ubicación remota cargada';
    });
  }

  Future<void> startTracking() async {
    final initialPosition = await locationService.getLocation();

    if (initialPosition != null && mounted) {
      final newPos = LatLng(initialPosition.latitude, initialPosition.longitude);

      setState(() {
        currentPosition = newPos;
      });
    }

    locationSubscription = locationService.getLocationStream().listen(
      (position) async {
        final newPos = LatLng(position.latitude, position.longitude);

        if (!mounted) return;

        setState(() {
          currentPosition = newPos;
          statusText = 'Ubicación local actualizada';
        });

        mapController?.animateCamera(CameraUpdate.newLatLng(newPos));

        final shipmentId = widget.shipmentId;
        if (shipmentId == null || shipmentId.isEmpty || sending) return;
        if (SessionService.currentUser?.tipo != 'traveler') return;

        try {
          sending = true;
          await trackingService.sendTracking(
            shipmentId: shipmentId,
            lat: position.latitude,
            lng: position.longitude,
            accuracyM: position.accuracy,
          );

          await loadRoute();

          if (!mounted) return;
          setState(() {
            statusText = 'Tracking enviado al servidor';
          });
        } on ApiException catch (e) {
          if (!mounted) return;
          setState(() {
            statusText = e.message;
          });
        } catch (_) {
          if (!mounted) return;
          setState(() {
            statusText = 'No se pudo enviar el tracking';
          });
        } finally {
          sending = false;
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          statusText = 'Error leyendo ubicación';
        });
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    locationSubscription?.cancel();
    trackingSubscription?.cancel();
    shipmentStatusSubscription?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadShipment();
      loadLatestTracking();
      loadRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: currentPosition,
                zoom: 14,
              ),
              onMapCreated: (controller) {
                mapController = controller;
                if (routePolylines.isNotEmpty) {
                  final points = routePolylines.first.points;
                  _fitRouteBounds(points);
                }
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              markers: {
                Marker(
                  markerId: const MarkerId('yo'),
                  position: currentPosition,
                ),
                ...routeMarkers,
              },
              polylines: routePolylines,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.background.withValues(alpha: 0.78),
                    Colors.transparent,
                    AppTheme.background.withValues(alpha: 0.18),
                    AppTheme.background,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TopAction(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.shipmentId == null ? 'Mapa en vivo' : 'Tracking en vivo',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.shipmentId == null
                                  ? 'Explora tu ubicación actual.'
                                  : 'Envío vinculado: ${widget.shipmentId}',
                              style: const TextStyle(color: AppTheme.muted),
                            ),
                            if (loadingRemote) ...[
                              const SizedBox(height: 4),
                              const Text(
                                'Cargando última ubicación remota...',
                                style: TextStyle(color: AppTheme.muted, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _TopAction(
                        icon: Icons.my_location_rounded,
                        onTap: () {
                          mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(currentPosition, 14.5),
                          );
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 30,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estado del mapa',
                          style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          statusText ?? 'Esperando ubicación...',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        if (shipment != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Destino: ${shipment!.receptorDireccion.isEmpty ? 'No definido' : shipment!.receptorDireccion}',
                            style: const TextStyle(color: AppTheme.muted),
                          ),
                          if (shipment!.receptorNombre.isNotEmpty)
                            Text(
                              'Recibe: ${shipment!.receptorNombre}',
                              style: const TextStyle(color: AppTheme.muted),
                            ),
                          if ((SessionService.currentUser?.tipo != 'traveler' || shipment!.assignedTravelerId == SessionService.currentUserId) && shipment!.receptorTelefono.isNotEmpty)
                            Text(
                              'Teléfono: ${shipment!.receptorTelefono}',
                              style: const TextStyle(color: AppTheme.muted),
                            ),
                        ],
                        if (routeSummary != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            routeSummary!,
                            style: const TextStyle(color: AppTheme.muted, height: 1.35),
                          ),
                        ],
                        if (routeFallbackDetail != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            routeFallbackDetail!,
                            style: const TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.35),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            AppInfoChip(
                              icon: Icons.pin_drop_outlined,
                              label: widget.shipmentId == null ? 'Mapa general' : 'Envío en curso',
                            ),
                            AppInfoChip(
                              icon: Icons.gps_fixed,
                              label: sending ? 'Enviando...' : 'Ubicación activa',
                            ),
                            AppInfoChip(
                              icon: Icons.sync,
                              label: loadingRemote ? 'Sincronizando' : 'Mapa listo',
                            ),
                            AppInfoChip(
                              icon: Icons.alt_route,
                              label: routePolylines.isNotEmpty ? 'Trayecto visible' : 'Ubicación activa',
                            ),
                            AppInfoChip(
                              icon: Icons.verified_outlined,
                              label: 'Seguimiento en vivo',
                            ),
                            AppInfoChip(
                              icon: Icons.route_rounded,
                              label: 'Entrega final',
                            ),
                          ],
                        ),
                        if (routeDistanceKm != null || routeDurationMinutes != null) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              if (routeDistanceKm != null)
                                Expanded(
                                  child: _MetricCard(
                                    label: 'Distancia',
                                    value: '${routeDistanceKm!.toStringAsFixed(1)} km',
                                  ),
                                ),
                              if (routeDistanceKm != null && routeDurationMinutes != null)
                                const SizedBox(width: 10),
                              if (routeDurationMinutes != null)
                                Expanded(
                                  child: _MetricCard(
                                    label: 'Tiempo estimado',
                                    value: '${routeDurationMinutes!} min',
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          widget.shipmentId == null
                              ? 'Usa esta vista para validar ubicación y contexto antes de entrar al tracking.'
                              : 'Esta vista actualiza ubicación local y, cuando aplica, la sincroniza con el envío.',
                          style: const TextStyle(color: AppTheme.muted, height: 1.35),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}

class _TopAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onTap,
      ),
    );
  }
}

