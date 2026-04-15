import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/services/location_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_action_cards.dart';
import 'package:iway_app/shared/ui/app_info_chip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final locationService = LocationService();
  String activeLocationLabel = 'Ciudad de Guatemala';
  bool loadingLocation = true;

  @override
  void initState() {
    super.initState();
    loadCurrentLocation();
  }

  Future<void> loadCurrentLocation() async {
    final position = await locationService.getLocation();

    if (!mounted) return;

    setState(() {
      if (position != null) {
        activeLocationLabel =
            '${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}';
      }
      loadingLocation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;
    final isTraveler = user?.tipo == 'traveler';

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
                            isTraveler ? 'Tu ruta de hoy' : 'Envía sin complicarte',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isTraveler
                                ? 'Seguimiento y control en tiempo real entre Guatemala y Estados Unidos.'
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
                      label: user?.verificado == true ? 'Verificado' : 'Pendiente revisión',
                    ),
                    AppInfoChip(
                      icon: Icons.location_searching_outlined,
                      label: loadingLocation ? 'Ubicando...' : activeLocationLabel,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withOpacity(0.96),
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
                          isTraveler ? 'Modo viajero activo' : '¿Qué quieres hacer?',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isTraveler
                              ? 'Mira envíos disponibles, oferta rápido y comparte tu tracking.'
                              : 'Publica un envío, revisa ofertas y sigue todo en un solo lugar.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              isTraveler ? '/map' : '/create_shipment',
                            );
                          },
                          child: Text(
                            isTraveler ? 'Abrir mapa y tracking' : 'Crear envío ahora',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width > 520
                                  ? (MediaQuery.of(context).size.width - 64) / 2
                                  : double.infinity,
                              child: AppQuickActionCard(
                                icon: Icons.local_offer_outlined,
                                title: isTraveler ? 'Ver oportunidades' : 'Ofertas',
                                subtitle: isTraveler
                                    ? 'Explora envíos disponibles'
                                    : 'Revisa propuestas activas',
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Abre un envío específico para ver u ofertar.'),
                                    ),
                                  );
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
                                  title: 'Pagos',
                                  subtitle: 'Tus deudas y cortes',
                                  onTap: () {
                                    Navigator.pushNamed(context, '/debts');
                                  },
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppQuickActionWide(
                          icon: Icons.person_outline_rounded,
                          title: 'Perfil y sesión',
                          subtitle: 'Revisa tu estado y cierra sesión si lo necesitas',
                          onTap: () {
                            Navigator.pushNamed(context, '/profile');
                          },
                        ),
                        if (!isTraveler) ...[
                          const SizedBox(height: 12),
                          AppQuickActionWide(
                            icon: Icons.admin_panel_settings_outlined,
                            title: 'Panel operativo',
                            subtitle: 'Revisión administrativa y soporte interno',
                            onTap: () {
                              Navigator.pushNamed(context, '/admin');
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
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
        color: AppTheme.surface.withOpacity(0.92),
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
