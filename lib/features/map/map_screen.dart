import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/services/location_service.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/features/tracking/services/tracking_service.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  final String? shipmentId;
  final double? previewOriginLat;
  final double? previewOriginLng;
  final String focus;
  final String? title;

  const MapScreen({
    super.key,
    this.shipmentId,
    this.previewOriginLat,
    this.previewOriginLng,
    this.focus = 'delivery',
    this.title,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  GoogleMapController? mapController;
  final shipmentService = ShipmentService();
  final trackingService = TrackingService();
  final realtime = RealtimeService.instance;
  final locationService = LocationService();

  ShipmentModel? shipment;
  Set<Marker> routeMarkers = {};
  Set<Polyline> routePolylines = {};
  StreamSubscription<dynamic>? trackingSubscription;
  StreamSubscription<dynamic>? shipmentStatusSubscription;
  bool loading = true;
  String? _mapStyle;
  LatLng? _currentDevicePoint;

  bool get _focusPickup => widget.focus == 'pickup';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMapStyle();
    _loadCurrentLocation();
    _load();
    _bindRealtime();
  }

  Future<void> _loadMapStyle() async {
    try {
      _mapStyle = await rootBundle.loadString('assets/map_style.json');
      if (mapController != null && _mapStyle != null) {
        await mapController!.setMapStyle(_mapStyle);
      }
    } catch (_) {}
  }

  Future<void> _loadCurrentLocation() async {
    if (widget.previewOriginLat != null && widget.previewOriginLng != null) {
      setState(() {
        _currentDevicePoint = LatLng(widget.previewOriginLat!, widget.previewOriginLng!);
      });
      return;
    }

    final position = await locationService.getLocation();
    if (!mounted || position == null) return;
    setState(() {
      _currentDevicePoint = LatLng(position.latitude, position.longitude);
    });
  }

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

  LatLng? get _targetPoint => _focusPickup ? _pickupPoint : _deliveryPoint;

  Future<void> _bindRealtime() async {
    final shipmentId = widget.shipmentId;
    if (shipmentId == null || shipmentId.isEmpty) return;

    await realtime.ensureConnected();
    await realtime.joinTracking(shipmentId);
    trackingSubscription = realtime.trackingUpdated.listen((data) {
      if (data is Map && data['shipmentId']?.toString() == shipmentId) {
        _load();
      }
    });
    shipmentStatusSubscription = realtime.shipmentStatusChanged.listen((data) {
      if (data is Map && data['shipmentId']?.toString() == shipmentId) {
        _load();
      }
    });
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

    await mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        72,
      ),
    );
  }

  Future<void> _load() async {
    final shipmentId = widget.shipmentId;
    if (shipmentId == null || shipmentId.isEmpty) {
      if (!mounted) return;
      setState(() => loading = false);
      return;
    }

    try {
      final shipmentData = await shipmentService.getShipmentById(shipmentId);
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

      final markers = <Marker>{};
      if (_currentDevicePoint != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('current-device'),
            position: _currentDevicePoint!,
            infoWindow: const InfoWindow(title: 'Tu ubicación'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          ),
        );
      }
      if (shipmentData.pickupLat != null && shipmentData.pickupLng != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: LatLng(shipmentData.pickupLat!, shipmentData.pickupLng!),
            infoWindow: const InfoWindow(title: 'Punto de recolección'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );
      }
      if (shipmentData.deliveryLat != null && shipmentData.deliveryLng != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('delivery'),
            position: LatLng(shipmentData.deliveryLat!, shipmentData.deliveryLng!),
            infoWindow: const InfoWindow(title: 'Punto de entrega'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        );
      }

      final localPickupPoint = shipmentData.pickupLat != null && shipmentData.pickupLng != null
          ? LatLng(shipmentData.pickupLat!, shipmentData.pickupLng!)
          : null;
      final localDeliveryPoint = shipmentData.deliveryLat != null && shipmentData.deliveryLng != null
          ? LatLng(shipmentData.deliveryLat!, shipmentData.deliveryLng!)
          : null;
      final localTargetPoint = _focusPickup ? localPickupPoint : localDeliveryPoint;

      final fallbackPoints = [
        if (_currentDevicePoint != null) _currentDevicePoint!,
        if (localTargetPoint != null) localTargetPoint,
      ];

      final polylineSource = polylinePoints.length >= 2 ? polylinePoints : fallbackPoints;
      final polylines = polylineSource.length >= 2
          ? {
              Polyline(
                polylineId: const PolylineId('shipment-route'),
                points: polylineSource,
                color: AppTheme.accent,
                width: 5,
                patterns: polylinePoints.length >= 2 ? [] : [PatternItem.dash(18), PatternItem.gap(10)],
              ),
            }
          : <Polyline>{};

      if (!mounted) return;
      setState(() {
        shipment = shipmentData;
        routeMarkers = markers;
        routePolylines = polylines;
        loading = false;
      });

      final fitPoints = polylineSource.isNotEmpty
          ? polylineSource
          : [if (_pickupPoint != null) _pickupPoint!, if (_deliveryPoint != null) _deliveryPoint!];
      await _fitRouteBounds(fitPoints);
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _openGoogleMaps() async {
    final point = _targetPoint;
    if (point == null) return;
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openWaze() async {
    final point = _targetPoint;
    if (point == null) return;
    final primary = Uri.parse('waze://?ll=${point.latitude},${point.longitude}&navigate=yes');
    final fallback = Uri.parse('https://waze.com/ul?ll=${point.latitude},${point.longitude}&navigate=yes');
    final opened = await launchUrl(primary, mode: LaunchMode.externalApplication);
    if (!opened) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  String _panelMessage() {
    if (routePolylines.isEmpty) {
      return 'Ruta disponible cuando existan coordenadas válidas.';
    }
    if (routePolylines.first.patterns.isEmpty) {
      return _focusPickup
          ? 'Ruta real hacia el punto exacto de recolección.'
          : 'Ruta real hacia el punto actual de entrega.';
    }
    return _focusPickup
        ? 'Vista previa de decisión desde tu ubicación hasta la recolección.'
        : 'Ruta visual estimada hacia el destino.';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    trackingSubscription?.cancel();
    shipmentStatusSubscription?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCurrentLocation();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _targetPoint ?? _currentDevicePoint ?? const LatLng(14.6349, -90.5069);

    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(target: initialTarget, zoom: 11.8),
                    onMapCreated: (controller) async {
                      mapController = controller;
                      if (_mapStyle != null) {
                        await controller.setMapStyle(_mapStyle);
                      }
                      final fitPoints = [if (_currentDevicePoint != null) _currentDevicePoint!, if (_targetPoint != null) _targetPoint!];
                      await _fitRouteBounds(fitPoints);
                    },
                    myLocationEnabled: _currentDevicePoint != null,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: true,
                    buildingsEnabled: false,
                    indoorViewEnabled: false,
                    markers: routeMarkers,
                    polylines: routePolylines,
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.surface.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.maybePop(context),
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppTheme.surface.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.border, width: 0.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title ?? (_focusPickup ? 'Ruta a recolección' : 'Ruta a entrega'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _panelMessage(),
                                style: const TextStyle(color: AppTheme.muted),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _targetPoint == null ? null : _openWaze,
                                  icon: const Icon(Icons.navigation_outlined),
                                  label: const Text('Abrir en Waze'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _targetPoint == null ? null : _openGoogleMaps,
                                  icon: const Icon(Icons.map_outlined),
                                  label: const Text('Abrir en Google Maps'),
                                ),
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
