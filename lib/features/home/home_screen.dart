import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/services/auth_service.dart';
import 'package:iway_app/features/auth/services/location_service.dart';
import 'package:iway_app/features/notifications/services/notification_service.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_action_cards.dart';
import 'package:iway_app/shared/ui/app_info_chip.dart';
import 'package:iway_app/shared/ui/app_operational_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final locationService = LocationService();
  final authService = AuthService();
  final notificationService = NotificationService();
  final realtime = RealtimeService.instance;
  LatLng currentPosition = const LatLng(14.6349, -90.5069);
  bool loadingLocation = true;
  int unreadNotifications = 0;
  StreamSubscription<dynamic>? notificationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadCurrentLocation();
    loadNotifications();
    refreshUserState();
    bindRealtime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> bindRealtime() async {
    await realtime.ensureConnected();
    notificationSubscription = realtime.notificationUpdated.listen((_) => loadNotifications());
  }

  Future<void> refreshUserState() async {
    try {
      await authService.refreshCurrentUser();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadNotifications();
      refreshUserState();
    }
  }

  Future<void> loadNotifications() async {
    try {
      final notifications = await notificationService.getAll();
      if (!mounted) return;
      setState(() {
        unreadNotifications = notifications.where((item) => !item.leido).length;
      });
    } catch (_) {}
  }

  Future<void> loadCurrentLocation() async {
    final position = await locationService.getLocation();

    if (!mounted) return;

    setState(() {
      if (position != null) {
        currentPosition = LatLng(position.latitude, position.longitude);
      }
      loadingLocation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;
    final isTraveler = user?.tipo == 'traveler';
    final isBlocked = user?.bloqueado == true;
    final isVerified = user?.verificado == true;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: currentPosition,
                zoom: 12.8,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              markers: {
                Marker(
                  markerId: const MarkerId('current'),
                  position: currentPosition,
                ),
              },
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.background.withValues(alpha: 0.82),
                    Colors.transparent,
                    AppTheme.background.withValues(alpha: 0.16),
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
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _TopAction(
                            icon: Icons.notifications_none_rounded,
                            onTap: () async {
                              await Navigator.pushNamed(context, '/notifications');
                              if (!mounted) return;
                              loadNotifications();
                            },
                          ),
                          Positioned(
                            right: -2,
                            top: -2,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                              child: unreadNotifications > 0
                                  ? Container(
                                      key: ValueKey(unreadNotifications),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: AppTheme.background, width: 1.5),
                                      ),
                                      constraints: const BoxConstraints(minWidth: 20),
                                      child: Text(
                                        unreadNotifications > 99 ? '99+' : '$unreadNotifications',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ],
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
                        label: isBlocked ? 'Restringido' : isVerified ? 'Verificado' : 'En revisión',
                        iconColor: isBlocked
                            ? const Color(0xFFFF8A7A)
                            : isVerified
                                ? const Color(0xFF59D38C)
                                : const Color(0xFFFFD27A),
                        backgroundColor: (isBlocked
                                ? const Color(0xFFFF8A7A)
                                : isVerified
                                    ? const Color(0xFF59D38C)
                                    : const Color(0xFFFFD27A))
                            .withValues(alpha: 0.12),
                        borderColor: (isBlocked
                                ? const Color(0xFFFF8A7A)
                                : isVerified
                                    ? const Color(0xFF59D38C)
                                    : const Color(0xFFFFD27A))
                            .withValues(alpha: 0.28),
                      ),
                      AppInfoChip(
                        icon: Icons.location_searching_outlined,
                        label: loadingLocation ? 'Ubicando...' : 'Ubicación activa',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isTraveler && isBlocked) ...[
                    AppOperationalBanner(
                      icon: Icons.lock_outline_rounded,
                      title: 'Cuenta con restricción operativa',
                      message: 'Tienes bloqueo activo por deuda o revisión. Revisa tu perfil y tus pagos antes de tomar nuevos envíos.',
                      tone: const Color(0xFFFF8A7A),
                      onTap: () => Navigator.pushNamed(context, '/debts'),
                      ctaLabel: 'Revisar deudas',
                    ),
                    const SizedBox(height: 12),
                  ] else if (isTraveler && !isVerified) ...[
                    AppOperationalBanner(
                      icon: Icons.verified_user_outlined,
                      title: 'Perfil en revisión',
                      message: 'Tu cuenta todavía está bajo revisión. Completa tu perfil y mantén tus datos limpios para operar sin fricción.',
                      tone: const Color(0xFFFFD27A),
                      onTap: () => Navigator.pushNamed(context, '/profile'),
                      ctaLabel: 'Ver estado',
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    loadingLocation
                        ? 'Ubicando tu punto base para mostrarte una vista más útil.'
                        : 'Todo listo para operar desde un flujo rápido, claro y conectado.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.muted,
                      height: 1.35,
                    ),
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
                        Text(
                          isTraveler ? 'Modo viajero activo' : '¿Qué quieres hacer?',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isTraveler
                              ? 'Mira envíos disponibles para tu ruta, oferta rápido y comparte tu tracking.'
                              : 'Publica un envío, revisa ofertas y sigue todo en un solo lugar.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: (isTraveler && isBlocked)
                              ? null
                              : () {
                                  Navigator.pushNamed(
                                    context,
                                    isTraveler ? '/traveler_opportunities' : '/create_shipment',
                                  );
                                },
                          child: Text(
                            isTraveler ? 'Ver oportunidades' : 'Crear envío ahora',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isTraveler
                              ? 'Mantén tu ubicación y seguimiento al día para generar más confianza.'
                              : 'Publicar un envío te lleva directo al flujo de ofertas disponibles.',
                          style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: AppQuickActionCard(
                                icon: Icons.local_offer_outlined,
                                title: isTraveler ? 'Ver oportunidades' : 'Ofertas',
                                subtitle: isTraveler
                                    ? 'Explora envíos disponibles'
                                    : 'Revisa propuestas activas',
                                onTap: () {
                                  Navigator.pushNamed(context, isTraveler ? '/traveler_opportunities' : '/notifications');
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppQuickActionCard(
                                icon: Icons.account_balance_wallet_outlined,
                                title: 'Pagos',
                                subtitle: isTraveler ? 'Tus deudas y cortes' : 'Historial y control',
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
        icon: Icon(icon),
        onPressed: onTap,
      ),
    );
  }
}
