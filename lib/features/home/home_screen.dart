import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iway_app/config/app_env.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/notifications/models/notification_model.dart';
import 'package:iway_app/features/notifications/services/notification_service.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/features/traveler/services/traveler_workspace_service.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/utils/currency_presenter.dart';
import 'package:iway_app/shared/utils/shipment_status_presenter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _shipmentService = ShipmentService();
  final _notificationService = NotificationService();
  final _travelerWorkspaceService = TravelerWorkspaceService();
  final _realtime = RealtimeService.instance;

  late Future<List<ShipmentModel>> _myShipmentsFuture;
  List<NotificationModel> _notifications = [];
  StreamSubscription<dynamic>? _globalSyncSubscription;
  bool _travelerOnline = true;
  bool _updatingTravelerOnline = false;
  TravelerRouteAnnouncement? _latestAnnouncement;

  bool get _isTraveler => SessionService.currentUser?.tipo == 'traveler';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _myShipmentsFuture = _shipmentService.getMyShipments();
    _loadTravelerWorkspace();
    _loadNotifications();
    _bindRealtime();
  }

  Future<void> _loadTravelerWorkspace() async {
    if (!_isTraveler) return;
    try {
      final workspace = await _travelerWorkspaceService.getWorkspace();
      final announcement = await _travelerWorkspaceService.getLatestRouteAnnouncement();
      if (!mounted) return;
      setState(() {
        _travelerOnline = workspace.isOnline;
        _latestAnnouncement = announcement;
      });
    } catch (_) {}
  }

  Future<void> _setTravelerOnline(bool value) async {
    if (!_isTraveler || _updatingTravelerOnline) return;
    setState(() => _updatingTravelerOnline = true);
    try {
      final workspace = await _travelerWorkspaceService.updateWorkspace(isOnline: value);
      if (!mounted) return;
      setState(() => _travelerOnline = workspace.isOnline);
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

  Future<void> _openRouteAnnouncementComposer() async {
    final messageController = TextEditingController();
    final productsController = TextEditingController();
    final regionsController = TextEditingController(text: SessionService.currentUser?.estado ?? '');

    final published = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Anunciar mi próxima ruta'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Mensaje del anuncio'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: productsController,
                decoration: const InputDecoration(labelText: 'Qué estás recibiendo (ej. Documentos, Medicina, Pan)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: regionsController,
                decoration: const InputDecoration(labelText: 'Regiones objetivo (opcional, separadas por coma)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final message = messageController.text.trim();
              final allowedProducts = productsController.text
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList();
              final regions = regionsController.text
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList();

              if (message.isEmpty || allowedProducts.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Completa el mensaje y qué productos recibirás.')),
                );
                return;
              }

              try {
                await _travelerWorkspaceService.publishRouteAnnouncement(
                  message: message,
                  allowedProducts: allowedProducts,
                  regions: regions,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, true);
              } catch (_) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('No se pudo publicar tu anuncio de ruta.')),
                );
              }
            },
            child: const Text('Publicar anuncio'),
          ),
        ],
      ),
    );

    messageController.dispose();
    productsController.dispose();
    regionsController.dispose();

    if (published == true) {
      await _loadTravelerWorkspace();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu ruta fue anunciada.')),
      );
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await _notificationService.getAll();
      if (!mounted) return;
      setState(() => _notifications = data);
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
    });
  }

  Future<bool> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('¿Quieres salir de iWay?'),
        content: const Text('Si sales ahora, la app se cerrará en este dispositivo.'),
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

  String _maskedShipmentId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '------';
    final suffix = trimmed.length <= 6 ? trimmed : trimmed.substring(trimmed.length - 6);
    return '...${suffix.toUpperCase()}';
  }

  String _shipmentTitle(ShipmentModel shipment) {
    return shipment.descripcion?.trim().isNotEmpty == true ? shipment.descripcion!.trim() : shipment.tipo;
  }

  String _travelerTaskTitle(ShipmentModel shipment) {
    switch (shipment.estado) {
      case 'assigned':
        return 'Tarea actual: Recoger paquete #${_maskedShipmentId(shipment.id)}';
      case 'picked_up':
      case 'in_transit':
      case 'arrived':
      case 'in_delivery':
        return 'Tarea actual: Entregar paquete #${_maskedShipmentId(shipment.id)}';
      default:
        return 'Siguiente tarea disponible';
    }
  }

  String _routeLabel(ShipmentModel shipment) {
    final origin = shipment.remitenteRegion.trim().isNotEmpty ? shipment.remitenteRegion.trim() : shipment.origen;
    final destination = shipment.receptorDireccion.trim().isNotEmpty ? shipment.receptorDireccion.trim() : shipment.destino;
    return '$origin → $destination';
  }

  bool _isTerminalStatus(String status) => status == 'delivered' || status == 'archived';

  List<ShipmentModel> _activeTravelerTasks(List<ShipmentModel> shipments) {
    return shipments.where((item) {
      if (_isTerminalStatus(item.estado)) return false;
      return item.estado == 'assigned' ||
          item.estado == 'picked_up' ||
          item.estado == 'in_transit' ||
          item.estado == 'arrived' ||
          item.estado == 'in_delivery';
    }).toList();
  }

  ShipmentModel? _nextTravelerTask(List<ShipmentModel> shipments) {
    final tasks = _activeTravelerTasks(shipments);
    if (tasks.isEmpty) return null;
    const order = {
      'assigned': 0,
      'picked_up': 1,
      'in_transit': 2,
      'arrived': 3,
      'in_delivery': 4,
    };
    tasks.sort((a, b) => (order[a.estado] ?? 99).compareTo(order[b.estado] ?? 99));
    return tasks.first;
  }

  Drawer _buildDrawer() {
    final user = SessionService.currentUser;

    ListTile tile({required IconData icon, required String title, required VoidCallback onTap, Color? color}) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        minLeadingWidth: 28,
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
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
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.surfaceSoft,
                    child: ClipOval(
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: user?.selfiePath != null && user!.selfiePath!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: AppEnv.resolveMediaUrl(user.selfiePath!),
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(Icons.person_rounded, color: AppTheme.muted, size: 28),
                                placeholder: (_, __) => const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              )
                            : const Icon(Icons.person_rounded, color: AppTheme.muted, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.nombre ?? 'Usuario', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(user?.email ?? '', style: const TextStyle(color: AppTheme.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            tile(icon: Icons.person_outline, title: 'Perfil', onTap: () => Navigator.pushNamed(context, '/profile')),
            tile(icon: Icons.inventory_2_outlined, title: 'Mis pedidos', onTap: () => Navigator.pushNamed(context, '/my_orders')),
            tile(icon: Icons.receipt_long_outlined, title: 'Mis envíos / Recibos', onTap: () => Navigator.pushNamed(context, '/history')),
            if (_isTraveler)
              tile(icon: Icons.star_outline, title: 'Mis calificaciones', onTap: () => Navigator.pushNamed(context, '/my_ratings')),
            if (_isTraveler)
              tile(icon: Icons.account_balance_wallet_outlined, title: 'Ingresos y comisiones', onTap: () => Navigator.pushNamed(context, '/debts')),
            if (!_isTraveler)
              tile(icon: Icons.group_outlined, title: 'Destinatarios', onTap: () => Navigator.pushNamed(context, '/recipients')),
            tile(icon: Icons.support_agent_outlined, title: 'Soporte', onTap: () => Navigator.pushNamed(context, '/support')),
            tile(icon: Icons.settings_outlined, title: 'Ajustes', onTap: () => Navigator.pushNamed(context, '/settings')),
            const Spacer(),
            tile(icon: Icons.logout_outlined, title: 'Cerrar sesión', color: const Color(0xFFE58B8B), onTap: _logout),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelerHeader(List<ShipmentModel> shipments) {
    final nextTask = _nextTravelerTask(shipments);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Escanear',
                subtitle: 'Confirmar carga o entrega con QR.',
                onTap: () => Navigator.pushNamed(context, '/scan_shipment'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.local_offer_outlined,
                title: 'Oportunidades',
                subtitle: _travelerOnline ? 'Ver pedidos disponibles.' : 'Activa En línea para recibir pedidos.',
                onTap: _travelerOnline ? () => Navigator.pushNamed(context, '/traveler_opportunities') : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ActionCard(
          icon: Icons.campaign_outlined,
          title: 'Anunciar mi próxima ruta',
          subtitle: _latestAnnouncement == null
              ? 'Publica lo que recogerás y avisa a los usuarios.'
              : '${_latestAnnouncement!.message} • ${_latestAnnouncement!.allowedProducts.join(', ')}',
          onTap: _openRouteAnnouncementComposer,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: nextTask == null
              ? const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sin tarea activa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 8),
                    Text('Cuando aceptes una oferta, aquí verás tu siguiente paso.', style: TextStyle(color: AppTheme.muted)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_travelerTaskTitle(nextTask), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(_shipmentTitle(nextTask), style: const TextStyle(color: AppTheme.muted)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pushNamed(context, '/tracking', arguments: nextTask.id),
                            child: const Text('Abrir tarea'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pushNamed(context, '/my_orders'),
                            child: const Text('Ver bandeja'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCustomerHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tu panel de envíos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Revisa ofertas, seguimiento y recibos sin datos técnicos innecesarios.',
            style: TextStyle(color: AppTheme.muted, height: 1.35),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/create_shipment'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo envío'),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelerTaskList(List<ShipmentModel> shipments) {
    final tasks = _activeTravelerTasks(shipments);
    if (tasks.isEmpty) {
      return _EmptyCard(
        title: 'Nada pendiente por ahora',
        message: 'Activa oportunidades o espera tu próxima asignación.',
        icon: Icons.inbox_outlined,
      );
    }

    return Column(
      children: tasks.map((shipment) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${_maskedShipmentId(shipment.id)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(CurrencyPresenter.formatForShipment(shipment, shipment.valor), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF34D399))),
                const SizedBox(height: 8),
                Text(_shipmentTitle(shipment), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(ShipmentStatusPresenter.label(shipment.estado), style: const TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/tracking', arguments: shipment.id),
                  child: const Text('Continuar tarea'),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomerShipmentList(List<ShipmentModel> shipments) {
    final activeShipments = shipments.where((shipment) => !_isTerminalStatus(shipment.estado)).toList();
    if (activeShipments.isEmpty) {
      return _EmptyCard(
        title: 'Todavía no tienes envíos',
        message: 'Crea tu primer envío para empezar a recibir ofertas.',
        icon: Icons.add_box_outlined,
      );
    }

    return Column(
      children: activeShipments.take(6).map((shipment) {
        final openOffers = shipment.estado == 'offered';
        final delivered = shipment.estado == 'delivered';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_shipmentTitle(shipment), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Envío #${_maskedShipmentId(shipment.id)}', style: const TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 8),
                Text(_routeLabel(shipment), style: const TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ShipmentStatusPresenter.label(shipment.estado),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        openOffers ? '/offers' : '/tracking',
                        arguments: shipment.id,
                      ),
                      child: Text(delivered ? 'Ver recibo' : openOffers ? 'Ver ofertas' : 'Ver detalle'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
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
                          Text(user?.nombre.split(' ').first ?? 'iWay', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(
                            _isTraveler ? 'Hoja de tareas' : 'Panel premium',
                            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                          ),
                        ],
                      ),
                      actions: [
                        if (_isTraveler) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Center(
                              child: Switch(
                                value: _travelerOnline,
                                onChanged: _updatingTravelerOnline ? null : _setTravelerOnline,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Center(child: Text('En línea', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                          ),
                        ],
                        Stack(
                          children: [
                            IconButton(
                              onPressed: () async {
                                await Navigator.pushNamed(context, '/notifications');
                                if (!mounted) return;
                                await _loadNotifications();
                              },
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
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isTraveler) _buildTravelerHeader(shipments) else _buildCustomerHeader(),
                            const SizedBox(height: 20),
                            Text(
                              _isTraveler ? 'Tus tareas activas' : 'Tus envíos',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            if (snapshot.connectionState == ConnectionState.waiting && shipments.isEmpty)
                              const Center(child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: CircularProgressIndicator(),
                              ))
                            else if (_isTraveler)
                              _buildTravelerTaskList(shipments)
                            else
                              _buildCustomerShipmentList(shipments),
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
        floatingActionButton: _isTraveler
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.pushNamed(context, '/my_orders'),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Mis pedidos'),
              )
            : FloatingActionButton.extended(
                onPressed: () => Navigator.pushNamed(context, '/create_shipment'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo envío'),
              ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.accent),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: AppTheme.muted, height: 1.35)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _EmptyCard({required this.title, required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accent),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: AppTheme.muted, height: 1.35)),
        ],
      ),
    );
  }
}
