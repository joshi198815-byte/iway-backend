import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/notifications/models/notification_model.dart';
import 'package:iway_app/features/notifications/services/notification_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/realtime_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_empty_state.dart';
import 'package:iway_app/shared/ui/app_info_chip.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with WidgetsBindingObserver {
  final service = NotificationService();
  final realtime = RealtimeService.instance;

  List<NotificationModel> notifications = [];
  bool loading = true;
  bool refreshing = false;
  StreamSubscription<dynamic>? notificationSubscription;
  StreamSubscription<dynamic>? offerSubscription;
  StreamSubscription<dynamic>? shipmentStatusSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadNotifications();
    bindRealtime();
  }

  Future<void> _markAllAsRead({bool reload = false}) async {
    final hasUnread = notifications.any((item) => !item.leido);
    if (!hasUnread) return;

    try {
      await service.markAllRead();
      if (!mounted) return;
      setState(() {
        notifications = notifications
            .map((item) => item.copyWith(leido: true))
            .toList();
      });
      if (reload) {
        await loadNotifications(showRefreshing: true);
      }
    } catch (_) {}
  }

  Future<void> bindRealtime() async {
    await realtime.ensureConnected();
    notificationSubscription = realtime.notificationUpdated.listen((_) => loadNotifications(showRefreshing: true));
    offerSubscription = realtime.offerUpdated.listen((_) => loadNotifications(showRefreshing: true));
    shipmentStatusSubscription = realtime.shipmentStatusChanged.listen((_) => loadNotifications(showRefreshing: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    notificationSubscription?.cancel();
    offerSubscription?.cancel();
    shipmentStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadNotifications(showRefreshing: true);
    }
  }

  Future<void> loadNotifications({bool showRefreshing = false}) async {
    if (showRefreshing) {
      setState(() => refreshing = true);
    }

    try {
      final data = await service.getAll();
      if (!mounted) return;

      setState(() {
        notifications = data;
        loading = false;
        refreshing = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markAllAsRead();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        refreshing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        refreshing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar las notificaciones.')),
      );
    }
  }

  String formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }


  IconData _iconForType(String? type) {
    switch (type) {
      case 'offer':
      case 'offer_updated':
      case 'offer_accepted':
      case 'offer_rejected':
      case 'shipment_available':
      case 'shipment_published':
        return Icons.local_offer_outlined;
      case 'shipment_assigned':
      case 'shipment_in_route':
      case 'shipment_status_changed':
        return Icons.local_shipping_outlined;
      case 'tracking_updated':
        return Icons.alt_route_outlined;
      case 'traveler_verification':
        return Icons.verified_user_outlined;
      case 'transfer_review':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _toneForType(String? type) {
    switch (type) {
      case 'transfer_review':
        return const Color(0xFFFFD27A);
      case 'traveler_verification':
        return const Color(0xFF8AB4FF);
      case 'shipment_assigned':
      case 'shipment_in_route':
      case 'shipment_status_changed':
      case 'tracking_updated':
        return const Color(0xFF59D38C);
      default:
        return AppTheme.accent;
    }
  }

  String _labelForType(String? type) {
    switch (type) {
      case 'offer':
      case 'offer_updated':
      case 'offer_accepted':
      case 'offer_rejected':
      case 'shipment_available':
      case 'shipment_published':
        return 'Oferta';
      case 'shipment_assigned':
      case 'shipment_in_route':
      case 'shipment_status_changed':
        return 'Operación';
      case 'tracking_updated':
        return 'Seguimiento';
      case 'rating':
        return 'Calificación';
      case 'traveler_verification':
        return 'Verificación';
      case 'transfer_review':
        return 'Pagos';
      default:
        return 'Actividad';
    }
  }

  String _ctaFor(NotificationModel notification) {
    switch (notification.tipo) {
      case 'offer':
      case 'shipment_available':
      case 'shipment_published':
      case 'offer_updated':
        return 'Toca para abrir ofertas';
      case 'offer_rejected':
        return 'Toca para revisar y enviar una nueva propuesta';
      case 'offer_accepted':
      case 'shipment_assigned':
      case 'shipment_in_route':
      case 'shipment_delivered':
      case 'delivery_closed':
      case 'shipment_status_changed':
      case 'tracking_updated':
        return 'Toca para abrir el tracking';
      case 'rating':
        return 'Toca para ver tus calificaciones';
      case 'traveler_verification':
        return 'Toca para revisar tu perfil';
      case 'transfer_review':
        return 'Toca para revisar tus pagos';
      default:
        return 'Toca para ver el detalle';
    }
  }

  String _subtitleFor(NotificationModel notification) {
    switch (notification.tipo) {
      case 'offer_accepted':
        return 'Tu propuesta ya fue elegida para operar este envío.';
      case 'offer_rejected':
        return 'El cliente pidió una nueva propuesta o descartó la anterior.';
      case 'shipment_assigned':
        return 'Ya hay un viajero asignado y la operación puede avanzar.';
      case 'shipment_status_changed':
        return 'El envío cambió de etapa operativa.';
      case 'tracking_updated':
        return 'Se recibió una nueva ubicación o movimiento logístico.';
      case 'rating':
        return 'Se registró una nueva calificación en tu cuenta.';
      case 'transfer_review':
        return 'Hubo movimiento o revisión en tu flujo de pagos.';
      default:
        return notification.mensaje;
    }
  }

  Future<void> openNotification(NotificationModel notification) async {
    if (!notification.leido) {
      await service.markRead(notification.id);
      await loadNotifications(showRefreshing: true);
    }

    switch (notification.tipo) {
      case 'offer':
      case 'shipment_available':
      case 'shipment_published':
      case 'offer_updated':
      case 'offer_rejected':
        final shipmentId = notification.shipmentId;
        if (shipmentId == null || shipmentId.isEmpty) return;
        await Navigator.pushNamed(context, '/offers', arguments: shipmentId);
        break;
      case 'offer_accepted':
      case 'shipment_assigned':
      case 'shipment_delivered':
      case 'delivery_closed':
      case 'shipment_status_changed':
      case 'tracking_updated':
        final shipmentId = notification.shipmentId;
        if (shipmentId == null || shipmentId.isEmpty) return;
        await Navigator.pushNamed(context, '/tracking', arguments: shipmentId);
        break;
      case 'rating':
        await Navigator.pushNamed(context, '/my_ratings');
        break;
      case 'traveler_verification':
        await Navigator.pushNamed(context, '/profile');
        break;
      case 'transfer_review':
        await Navigator.pushNamed(context, '/debts');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                child: Row(
                  children: [
                    AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppPageIntro(
                            title: 'Notificaciones',
                            subtitle: 'Actividad reciente y movimientos importantes.',
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: notifications.any((item) => !item.leido)
                                  ? () => _markAllAsRead(reload: true)
                                  : null,
                              icon: const Icon(Icons.done_all_rounded),
                              label: const Text('Marcar todas como leídas'),
                            ),
                          ),
                          if (refreshing) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Actualizando notificaciones...',
                              style: TextStyle(color: AppTheme.muted, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : notifications.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.notifications_none_rounded,
                            title: 'Sin notificaciones por ahora',
                            subtitle: 'Cuando haya actividad de ofertas, tracking, pagos o verificación, aparecerá aquí.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                            itemCount: notifications.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final n = notifications[index];

                              return InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () async {
                                  await _markAllAsRead();
                                  await openNotification(n);
                                },
                                child: Ink(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: n.leido ? AppTheme.border : AppTheme.accent,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Builder(
                                        builder: (_) {
                                          final tone = _toneForType(n.tipo);
                                          return Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: tone.withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Icon(_iconForType(n.tipo), color: tone),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(n.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                AppInfoChip(
                                                  icon: _iconForType(n.tipo),
                                                  label: _labelForType(n.tipo),
                                                  iconColor: _toneForType(n.tipo),
                                                  backgroundColor: _toneForType(n.tipo).withValues(alpha: 0.12),
                                                  borderColor: _toneForType(n.tipo).withValues(alpha: 0.28),
                                                ),
                                                AppInfoChip(
                                                  icon: n.leido ? Icons.drafts_outlined : Icons.mark_email_unread_outlined,
                                                  label: n.leido ? 'Leída' : 'Nueva',
                                                  iconColor: n.leido ? AppTheme.muted : AppTheme.accent,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _subtitleFor(n),
                                              style: const TextStyle(color: AppTheme.muted, height: 1.35),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              _ctaFor(n),
                                              style: const TextStyle(
                                                color: AppTheme.accent,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        formatTime(n.fecha),
                                        style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
