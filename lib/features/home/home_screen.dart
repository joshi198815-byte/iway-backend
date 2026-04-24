import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/home/services/home_banner_service.dart';
import 'package:iway_app/features/notifications/models/notification_model.dart';
import 'package:iway_app/features/notifications/services/notification_service.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/features/traveler/services/traveler_workspace_service.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/utils/shipment_status_presenter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _shipmentService = ShipmentService();
  final _notificationService = NotificationService();
  final _bannerService = HomeBannerService();
  final _travelerWorkspaceService = TravelerWorkspaceService();
  final _realtime = RealtimeService.instance;

  late Future<List<ShipmentModel>> _myShipmentsFuture;
  late Future<List<HomeBannerItem>> _bannersFuture;
  List<NotificationModel> _notifications = [];
  StreamSubscription<dynamic>? _globalSyncSubscription;
  bool _travelerOnline = true;
  bool _updatingTravelerOnline = false;

  bool get _isTraveler => SessionService.currentUser?.tipo == 'traveler';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _myShipmentsFuture = _shipmentService.getMyShipments();
    _bannersFuture = _bannerService.getHomeBanners(traveler: _isTraveler);
    _loadTravelerWorkspace();
    _loadNotifications();
    _bindRealtime();
  }

  Future<void> _loadTravelerWorkspace() async {
    if (!_isTraveler) return;
    try {
      final workspace = await _travelerWorkspaceService.getWorkspace();
      if (!mounted) return;
      setState(() => _travelerOnline = workspace.isOnline);
    } catch (_) {}
  }

  Future<void> _setTravelerOnline(bool value) async {
    if (!_isTraveler || _updatingTravelerOnline) return;
    setState(() => _updatingTravelerOnline = true);
    try {
      final workspace = await _travelerWorkspaceService.updateWorkspace(isOnline: value);
      if (!mounted) return;
      setState(() => _travelerOnline = workspace.isOnline);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            workspace.isOnline
                ? 'Modo En línea activado. Ya puedes recibir oportunidades.'
                : 'Modo Desconectado activado. Dejaste de recibir oportunidades.',
          ),
        ),
      );
      await _refreshShipments();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar tu estado de trabajo.')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingTravelerOnline = false);
      }
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await _notificationService.getAll();
      if (!mounted) return;
      setState(() => _notifications = data.take(5).toList());
    } catch (_) {}
  }

  Future<void> _bindRealtime() async {
    await _realtime.ensureConnected();
    _globalSyncSubscription = _realtime.globalEntitySync.listen((_) async {
      await _refreshShipments();
      await _loadNotifications();
    });
  }

  Future<void> _refreshShipments() async {
    if (!mounted) return;
    setState(() {
      _myShipmentsFuture = _shipmentService.getMyShipments();
      _bannersFuture = _bannerService.getHomeBanners(traveler: _isTraveler);
    });
  }

  Future<bool> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('¿Quieres salir de i-way?'),
        content: const Text('Si sales ahora, se cerrará i-way en este dispositivo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir')),
        ],
      ),
    );

    return shouldExit == true;
  }

  Future<void> _logout() async {
    await SessionService.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _globalSyncSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshShipments();
      _loadNotifications();
    }
  }

  Drawer _buildDrawer() {
    final user = SessionService.currentUser;

    ListTile tile({required IconData icon, required String title, required VoidCallback onTap, Color? color}) {
      return ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
      );
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.surface),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppTheme.surfaceSoft,
                child: Text((user?.nombre.isNotEmpty == true ? user!.nombre[0] : 'I').toUpperCase()),
              ),
              accountName: Text(user?.nombre ?? 'Usuario'),
              accountEmail: Text(user?.email ?? ''),
            ),
            tile(icon: Icons.person_outline, title: 'Perfil', onTap: () => Navigator.pushNamed(context, '/profile')),
            if (_isTraveler)
              tile(icon: Icons.route_outlined, title: 'Mis rutas', onTap: () => Navigator.pushNamed(context, '/traveler_routes')),
            if (_isTraveler)
              tile(icon: Icons.account_balance_wallet_outlined, title: 'Ingresos y comisiones', onTap: () => Navigator.pushNamed(context, '/debts')),
            tile(icon: Icons.history_rounded, title: 'Mis pedidos', onTap: () => Navigator.pushNamed(context, '/my_orders')),
            tile(icon: Icons.support_agent_outlined, title: 'Soporte técnico', onTap: () => Navigator.pushNamed(context, '/support')),
            tile(icon: Icons.settings_outlined, title: 'Ajustes', onTap: () => Navigator.pushNamed(context, '/settings')),
            if (_isTraveler)
              tile(icon: Icons.star_outline_rounded, title: 'Mis calificaciones', onTap: () => Navigator.pushNamed(context, '/my_ratings')),
            if (!_isTraveler)
              tile(icon: Icons.group_outlined, title: 'Gestión de destinatarios', onTap: () => Navigator.pushNamed(context, '/recipients')),
            const Spacer(),
            const Divider(height: 1),
            tile(icon: Icons.logout_rounded, title: 'Cerrar sesión', color: Colors.redAccent, onTap: _logout),
            tile(icon: Icons.person_remove_outlined, title: 'Eliminar cuenta', color: Colors.redAccent, onTap: () => Navigator.pushNamed(context, '/profile')),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerCarousel() {
    return FutureBuilder<List<HomeBannerItem>>(
      future: _bannersFuture,
      builder: (context, snapshot) {
        final banners = snapshot.data ?? const <HomeBannerItem>[];
        if (banners.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 158,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: banners.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = banners[index];
              final accent = _parseColor(item.accent);
              return Container(
                width: 280,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), shape: BoxShape.circle),
                      child: Icon(Icons.campaign_outlined, color: accent),
                    ),
                    const SizedBox(height: 14),
                    Text(item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(item.subtitle, style: const TextStyle(color: AppTheme.muted, height: 1.35)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _shipmentDisplayTitle(ShipmentModel shipment) {
    final productName = (shipment.descripcion ?? '').trim().isNotEmpty
        ? shipment.descripcion!.trim()
        : shipment.tipo.trim();
    return 'Envío de: $productName';
  }

  String _maskedIdSuffix(String rawId) {
    final trimmed = rawId.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= 5) return trimmed;
    return trimmed.substring(trimmed.length - 5);
  }

  String _sanitizeActivityText(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return trimmed;

    return trimmed.replaceAllMapped(
      RegExp(r'\b[a-zA-Z0-9_-]{12,}\b'),
      (match) => '…${_maskedIdSuffix(match.group(0) ?? '')}',
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
      case 'offered':
        return Icons.access_time_rounded;
      case 'picked_up':
        return Icons.inventory_2_rounded;
      case 'assigned':
        return Icons.person_pin_circle_outlined;
      case 'in_transit':
      case 'in_delivery':
        return Icons.local_shipping_outlined;
      case 'arrived':
        return Icons.location_on_outlined;
      case 'delivered':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Widget _buildNotificationsPreview() {
    return Container(
      width: double.infinity,
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
              const Text('Actividad reciente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pushNamed(context, '/notifications'), child: const Text('Ver todo')),
            ],
          ),
          const SizedBox(height: 8),
          if (_notifications.isEmpty)
            Text(
              _isTraveler
                  ? 'Aquí verás eventos reales como nuevas oportunidades, ofertas aceptadas y pagos.'
                  : 'Aquí verás eventos reales como ofertas, cambios de estado y entregas.',
              style: const TextStyle(color: AppTheme.muted, height: 1.4),
            )
          else
            ..._notifications.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notifications_active_outlined, size: 18, color: AppTheme.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.titulo.isNotEmpty ? item.titulo : 'Nuevo evento', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(_sanitizeActivityText(item.mensaje), style: const TextStyle(color: AppTheme.muted, height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHero() {
    if (_isTraveler) {
      final onlineColor = _travelerOnline ? const Color(0xFF32FF84) : const Color(0xFFFF8A7A);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: onlineColor.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: onlineColor.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Modo trabajo', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              _travelerOnline
                  ? 'Estás en línea. El backend ya te toma en cuenta para oportunidades compatibles.'
                  : 'Estás desconectado. No recibirás nuevas oportunidades hasta volver a activarte.',
              style: const TextStyle(color: AppTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: onlineColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                onPressed: _updatingTravelerOnline ? null : () => _setTravelerOnline(!_travelerOnline),
                icon: _updatingTravelerOnline
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Icon(_travelerOnline ? Icons.wifi_tethering_rounded : Icons.wifi_off_rounded),
                label: Text(_travelerOnline ? 'EN LÍNEA' : 'DESCONECTADO'),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _travelerOnline ? () => Navigator.pushNamed(context, '/traveler_opportunities') : null,
                    icon: const Icon(Icons.local_offer_outlined),
                    label: const Text('Ver oportunidades'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/my_orders'),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Mis pedidos'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildShipmentList(List<ShipmentModel> shipments) {
    if (shipments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(_isTraveler ? 'Aún no tienes pedidos en tu historial.' : 'Todavía no has publicado envíos.', style: const TextStyle(color: AppTheme.muted)),
      );
    }

    return Column(
      children: shipments.take(4).map((shipment) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 0,
            color: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.border, width: 0.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_statusIcon(shipment.estado), color: AppTheme.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_shipmentDisplayTitle(shipment), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              ShipmentStatusPresenter.label(shipment.estado),
                              style: const TextStyle(color: AppTheme.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('${shipment.origen} → ${shipment.destino}', style: const TextStyle(color: AppTheme.muted)),
                  const SizedBox(height: 4),
                  Text(
                    shipment.receptorNombre.isNotEmpty ? shipment.receptorNombre : 'Ref: …${_maskedIdSuffix(shipment.id)}',
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        shipment.estado == 'offered' && !_isTraveler ? '/offers' : '/tracking',
                        arguments: shipment.id,
                      ),
                      child: Text(shipment.estado == 'offered' && !_isTraveler ? 'Ver ofertas' : 'Abrir detalle'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _parseColor(String value) {
    final normalized = value.replaceFirst('#', '');
    final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF59D38C);
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;
    final unreadCount = _notifications.where((item) => !item.leido).length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _confirmExit();
        if (!mounted || !shouldExit) return;
        await SystemNavigator.pop();
      },
      child: Scaffold(
        drawer: _buildDrawer(),
        floatingActionButton: _isTraveler
            ? null
            : FloatingActionButton.extended(
                onPressed: () => Navigator.pushNamed(context, '/create_shipment'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo Envío'),
              ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.background, Color(0xFF101116), AppTheme.background],
            ),
          ),
          child: RefreshIndicator(
            onRefresh: () async {
              await _refreshShipments();
              await _loadNotifications();
            },
            child: FutureBuilder<List<ShipmentModel>>(
              future: _myShipmentsFuture,
              builder: (context, snapshot) {
                final shipments = snapshot.data ?? const <ShipmentModel>[];
                return CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      floating: false,
                      backgroundColor: AppTheme.background,
                      elevation: 0,
                      leading: Builder(
                        builder: (context) => IconButton(
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          icon: const Icon(Icons.menu_rounded),
                        ),
                      ),
                      titleSpacing: 0,
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hola, ${user?.nombre.split(' ').first ?? 'i-WAY'}'),
                          Text(
                            _isTraveler ? 'Tu centro operativo' : 'Tus envíos',
                            style: const TextStyle(color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      actions: [
                        Stack(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pushNamed(context, '/notifications'),
                              icon: const Icon(Icons.notifications_none_rounded),
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 10,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(999)),
                                  child: Text('$unreadCount', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isTraveler) ...[
                              _buildHero(),
                              const SizedBox(height: 18),
                            ],
                            _buildBannerCarousel(),
                            if (!_isTraveler) const SizedBox(height: 18),
                            const SizedBox(height: 18),
                            _buildNotificationsPreview(),
                            const SizedBox(height: 18),
                            Text(_isTraveler ? 'Actividad reciente' : 'Tus envíos recientes', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 12),
                            _buildShipmentList(shipments),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
