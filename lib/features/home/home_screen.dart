import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/utils/shipment_status_presenter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _travelerOnlineKey = 'traveler_online';

  final _shipmentService = ShipmentService();
  final _realtime = RealtimeService.instance;

  late Future<List<ShipmentModel>> _myShipmentsFuture;
  StreamSubscription<dynamic>? _globalSyncSubscription;
  bool _travelerOnline = true;

  bool get _isTraveler => SessionService.currentUser?.tipo == 'traveler';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _myShipmentsFuture = _shipmentService.getMyShipments();
    _loadPreferences();
    _bindRealtime();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _travelerOnline = prefs.getBool(_travelerOnlineKey) ?? true;
    });
  }

  Future<void> _setTravelerOnline(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_travelerOnlineKey, value);
    if (!mounted) return;
    setState(() => _travelerOnline = value);
  }

  Future<void> _bindRealtime() async {
    await _realtime.ensureConnected();
    _globalSyncSubscription = _realtime.globalEntitySync.listen((_) => _refreshShipments());
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
    }
  }

  Widget _buildBanner({required IconData icon, required String title, required String subtitle}) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accent),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: AppTheme.muted, height: 1.4)),
        ],
      ),
    );
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
                backgroundImage: (user?.selfiePath ?? '').isNotEmpty ? NetworkImage(user!.selfiePath!) : null,
                child: (user?.selfiePath ?? '').isEmpty ? const Icon(Icons.person_outline, size: 32) : null,
              ),
              accountName: Text(user?.nombre ?? 'Usuario'),
              accountEmail: Text(user?.email ?? ''),
            ),
            if (_isTraveler)
              SwitchListTile(
                value: _travelerOnline,
                onChanged: _setTravelerOnline,
                title: const Text('En línea'),
                subtitle: Text(_travelerOnline ? 'Recibiendo pedidos compatibles' : 'Desconectado'),
              ),
            tile(icon: Icons.person_outline, title: _isTraveler ? 'Editar perfil' : 'Perfil', onTap: () => Navigator.pushNamed(context, '/profile')),
            tile(icon: Icons.history_rounded, title: _isTraveler ? 'Pedidos' : 'Historial', onTap: () => Navigator.pushNamed(context, '/my_orders')),
            if (!_isTraveler)
              tile(icon: Icons.group_outlined, title: 'Gestión de destinatarios', onTap: () => Navigator.pushNamed(context, '/recipients')),
            if (_isTraveler)
              tile(icon: Icons.account_balance_wallet_outlined, title: 'Wallet', onTap: () => Navigator.pushNamed(context, '/debts')),
            if (_isTraveler)
              tile(icon: Icons.route_outlined, title: 'Mis rutas', onTap: () => Navigator.pushNamed(context, '/profile')),
            tile(icon: Icons.settings_outlined, title: 'Ajustes', onTap: () => Navigator.pushNamed(context, '/settings')),
            tile(icon: Icons.support_agent_outlined, title: 'Soporte técnico', onTap: () => Navigator.pushNamed(context, '/support')),
            const Spacer(),
            tile(icon: Icons.delete_outline, title: 'Eliminar cuenta', color: Colors.redAccent, onTap: () => Navigator.pushNamed(context, '/support')),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Envía con claridad y seguimiento real', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Publica tu envío, espera ofertas y sigue todo el proceso sin compartir tu número antes de tiempo.', style: TextStyle(color: AppTheme.muted, height: 1.4)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/create_shipment'),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Crear Envío'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelerHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Panel del viajero', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      _travelerOnline ? 'Estás disponible para recibir pedidos compatibles con tus rutas.' : 'Estás desconectado. No deberías operar nuevas coincidencias hasta activarte.',
                      style: const TextStyle(color: AppTheme.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
              Switch(value: _travelerOnline, onChanged: _setTravelerOnline),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/traveler_opportunities'),
                  icon: const Icon(Icons.local_offer_outlined),
                  label: const Text('Ver ofertas'),
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
        child: Text(
          _isTraveler ? 'Aún no tienes pedidos en tu historial.' : 'Todavía no has publicado envíos.',
          style: const TextStyle(color: AppTheme.muted),
        ),
      );
    }

    final recent = shipments.take(4).toList();
    return Column(
      children: recent.map((shipment) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${shipment.receptorNombre.isEmpty ? 'Destinatario pendiente' : shipment.receptorNombre} • ${ShipmentStatusPresenter.label(shipment.estado)}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('${shipment.origen} → ${shipment.destino}', style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 4),
              Text(shipment.descripcion?.isNotEmpty == true ? shipment.descripcion! : shipment.tipo, style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/tracking', arguments: shipment.id),
                  child: const Text('Abrir detalle'),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;

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
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshShipments,
              child: FutureBuilder<List<ShipmentModel>>(
                future: _myShipmentsFuture,
                builder: (context, snapshot) {
                  final shipments = snapshot.data ?? const <ShipmentModel>[];
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      Row(
                        children: [
                          Builder(
                            builder: (context) => IconButton(
                              onPressed: () => Scaffold.of(context).openDrawer(),
                              icon: const Icon(Icons.menu_rounded),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hola, ${user?.nombre.split(' ').first ?? 'i-Way'}', style: Theme.of(context).textTheme.headlineMedium),
                                const SizedBox(height: 4),
                                Text(_isTraveler ? 'Controla rutas, pedidos y soporte.' : 'Publica envíos y espera ofertas con tranquilidad.', style: const TextStyle(color: AppTheme.muted)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pushNamed(context, '/notifications'),
                            icon: const Icon(Icons.notifications_none_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _isTraveler ? _buildTravelerHero() : _buildCustomerHero(),
                      const SizedBox(height: 20),
                      const Text('Información importante', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 170,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildBanner(icon: Icons.security_rounded, title: 'Seguridad', subtitle: 'Chat interno, estados en tiempo real y control operativo durante todo el envío.'),
                            _buildBanner(icon: Icons.shield_outlined, title: 'Seguro', subtitle: 'Activa cobertura opcional ante pérdida o robo cuando el valor declarado lo requiera.'),
                            _buildBanner(icon: Icons.verified_user_outlined, title: 'Cobertura total en USA', subtitle: 'Entrega final con destinatarios guardados y dirección validada por autocompletado.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(_isTraveler ? 'Pedidos recientes' : 'Historial reciente', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ))
                      else
                        _buildShipmentList(shipments),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
