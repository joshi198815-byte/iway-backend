import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_action_cards.dart';
import 'package:iway_app/shared/ui/app_info_chip.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;
    final isTraveler = user?.tipo == 'traveler';
    final routes = _travelerRoutes();

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
                            isTraveler ? 'Panel del viajero' : 'Envía sin complicarte',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isTraveler
                                ? 'Aquí ves tus rutas, tus pedidos y lo importante para operar.'
                                : 'Publica un envío y recibe ofertas de viajeros verificados.',
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
                      ),
                  ],
                ),
                if (isTraveler) ...[
                  const SizedBox(height: 18),
                  Container(
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
                        isTraveler ? 'Tu operación' : '¿Qué quieres hacer?',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isTraveler
                            ? 'Mantén tu perfil al día, revisa pedidos activos y controla tus pagos.'
                            : 'Publica un envío, revisa ofertas y sigue todo en un solo lugar.',
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
                              subtitle: isTraveler
                                  ? 'Activos y completados'
                                  : 'Publica un envío nuevo',
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  isTraveler ? '/my_orders' : '/create_shipment',
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width > 520
                                ? (MediaQuery.of(context).size.width - 64) / 2
                                : double.infinity,
                            child: AppQuickActionCard(
                              icon: isTraveler ? Icons.local_offer_outlined : Icons.sell_outlined,
                              title: isTraveler ? 'Oportunidades' : 'Ofertas',
                              subtitle: isTraveler
                                  ? 'Explora envíos disponibles'
                                  : 'Revisa propuestas activas',
                              onTap: () {
                                if (isTraveler) {
                                  Navigator.pushNamed(context, '/traveler_opportunities');
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Abre un envío específico para ver sus ofertas.'),
                                    ),
                                  );
                                }
                              },
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
                          if (isTraveler)
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
              ],
            ),
          ),
        ),
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
