import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_action_cards.dart';
import 'package:iway_app/shared/ui/app_info_chip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _shipmentService = ShipmentService();
  late Future<List<ShipmentModel>> _myShipmentsFuture;

  Future<bool> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('¿Salir de la app?'),
        content: const Text('Si sales ahora, se cerrará iWay en este dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    return shouldExit == true;
  }

  @override
  void initState() {
    super.initState();
    _myShipmentsFuture = _shipmentService.getMyShipments();
  }

  List<String> _travelerRoutes() {
    final routes = SessionService.currentUser?.rutas ?? const [];
    return routes.where((e) => e.trim().isNotEmpty).toList();
  }

  void _showSupport(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Soporte técnico',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Si algo falla con tus pedidos, pagos o perfil, entra a Notificaciones o contacta al equipo de iWay desde tu canal habitual de soporte.',
              style: TextStyle(color: AppTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/notifications');
                },
                child: const Text('Ir a notificaciones'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
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
        return 'Completado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;
    final isTraveler = user?.tipo == 'traveler';
    final routes = _travelerRoutes();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _confirmExit();
        if (!mounted || !shouldExit) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
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
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _myShipmentsFuture = _shipmentService.getMyShipments();
              });
              await _myShipmentsFuture;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTraveler ? 'Panel del viajero' : 'Panel del cliente',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isTraveler
                                  ? 'Aquí ves tus rutas, tus pedidos y lo importante para operar.'
                                  : 'Crea envíos, revisa su estado y sigue las ofertas desde aquí.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      _TopAction(
                        icon: Icons.notifications_none_rounded,
                        onTap: () => Navigator.pushNamed(context, '/notifications'),
                      ),
                      const SizedBox(width: 10),
                      _TopAction(
                        icon: Icons.person_outline_rounded,
                        onTap: () => Navigator.pushNamed(context, '/profile'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      AppInfoChip(
                        icon: Icons.public,
                        label: user?.pais.isNotEmpty == true ? user!.pais : 'GT ↔ USA',
                      ),
                      AppInfoChip(
                        icon: Icons.verified_user_outlined,
                        label: user?.verificado == true ? 'Perfil aprobado' : 'Perfil en revisión',
                      ),
                      if (isTraveler)
                        AppInfoChip(
                          icon: Icons.route_outlined,
                          label: routes.isEmpty ? 'Rutas por definir' : '${routes.length} ruta${routes.length == 1 ? '' : 's'} activa${routes.length == 1 ? '' : 's'}',
                        )
                      else
                        AppInfoChip(
                          icon: Icons.photo_camera_front_outlined,
                          label: (user?.selfiePath ?? '').isEmpty ? 'Falta selfie' : 'Selfie cargada',
                        ),
                    ],
                  ),
                  if (isTraveler) ...[
                    const SizedBox(height: 18),
                    _RoutesCard(routes: routes),
                  ],
                  if (!isTraveler) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        (user?.selfiePath ?? '').isEmpty
                            ? 'Antes de publicar un envío, completa tu selfie en Perfil. Así evitamos cuentas incompletas y el flujo no se rompe.'
                            : 'Tu perfil ya tiene selfie. Puedes publicar envíos y seguirlos desde Mis pedidos.',
                        style: const TextStyle(color: AppTheme.muted, height: 1.4),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
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
                        Text(
                          isTraveler ? 'Tu operación' : 'Tus acciones rápidas',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isTraveler
                              ? 'Mantén tu perfil al día, revisa pedidos activos y controla tus pagos.'
                              : 'Publica un envío, revisa tus pedidos y controla su estado sin perderte.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width > 520
                                  ? (MediaQuery.of(context).size.width - 64) / 2
                                  : double.infinity,
                              child: AppQuickActionCard(
                                icon: isTraveler ? Icons.local_shipping_outlined : Icons.add_box_outlined,
                                title: isTraveler ? 'Mis pedidos' : 'Crear envío',
                                subtitle: isTraveler ? 'Activos y completados' : 'Publica un envío nuevo',
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  isTraveler ? '/my_orders' : '/create_shipment',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width > 520
                                  ? (MediaQuery.of(context).size.width - 64) / 2
                                  : double.infinity,
                              child: AppQuickActionCard(
                                icon: isTraveler ? Icons.local_offer_outlined : Icons.list_alt_outlined,
                                title: isTraveler ? 'Oportunidades' : 'Mis pedidos',
                                subtitle: isTraveler ? 'Explora envíos disponibles' : 'Publicado, en ruta o completado',
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  isTraveler ? '/traveler_opportunities' : '/my_orders',
                                ),
                              ),
                            ),
                            if (isTraveler)
                              SizedBox(
                                width: MediaQuery.of(context).size.width > 520
                                    ? (MediaQuery.of(context).size.width - 64) / 2
                                    : double.infinity,
                                child: AppQuickActionCard(
                                  icon: Icons.account_balance_wallet_outlined,
                                  title: 'Comisiones',
                                  subtitle: 'Pagos, cortes y saldo',
                                  onTap: () => Navigator.pushNamed(context, '/debts'),
                                ),
                              ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width > 520
                                  ? (MediaQuery.of(context).size.width - 64) / 2
                                  : double.infinity,
                              child: AppQuickActionCard(
                                icon: Icons.support_agent_outlined,
                                title: 'Soporte técnico',
                                subtitle: 'Ayuda si algo falla',
                                onTap: () => _showSupport(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isTraveler) ...[
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: FutureBuilder<List<ShipmentModel>>(
                        future: _myShipmentsFuture,
                        builder: (context, snapshot) {
                          final shipments = snapshot.data ?? const <ShipmentModel>[];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tus envíos recientes',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 10),
                              if (snapshot.connectionState == ConnectionState.waiting)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              else if (shipments.isEmpty)
                                const Text(
                                  'Todavía no tienes envíos publicados.',
                                  style: TextStyle(color: AppTheme.muted),
                                )
                              else
                                ...shipments.take(3).map(
                                  (shipment) => Container(
                                    margin: const EdgeInsets.only(top: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceSoft,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${shipment.origen} → ${shipment.destino}',
                                                style: const TextStyle(fontWeight: FontWeight.w700),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                shipment.descripcion?.isNotEmpty == true
                                                    ? shipment.descripcion!
                                                    : shipment.receptorDireccion,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: AppTheme.muted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              _statusLabel(shipment.estado),
                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                            const SizedBox(height: 6),
                                            TextButton(
                                              onPressed: () => Navigator.pushNamed(
                                                context,
                                                '/offers',
                                                arguments: shipment.id,
                                              ),
                                              child: const Text('Ver ofertas'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (shipments.length > 3) ...[
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () => Navigator.pushNamed(context, '/my_orders'),
                                  child: const Text('Ver todos mis pedidos'),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }
}

class _RoutesCard extends StatelessWidget {
  final List<String> routes;

  const _RoutesCard({required this.routes});

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'Estados / rutas que cubres',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (routes.isEmpty)
            const Text(
              'Todavía no has definido tus rutas. Puedes editarlas en tu perfil.',
              style: TextStyle(color: AppTheme.muted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: routes
                  .map(
                    (route) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSoft,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(route),
                    ),
                  )
                  .toList(),
            ),
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onTap,
      ),
    );
  }
}
