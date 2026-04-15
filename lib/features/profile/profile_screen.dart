import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/notifications/services/push_notification_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;

    final hasSession = user != null;

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
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                const SizedBox(height: 24),
                const AppPageIntro(
                  title: 'Tu perfil',
                  subtitle: 'Sesión, rol y estado operativo dentro de iWay.',
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: hasSession
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceSoft,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.person_outline_rounded, size: 30, color: AppTheme.accent),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.nombre.isNotEmpty ? user.nombre : 'Usuario iWay',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.email.isNotEmpty ? user.email : 'Sin correo',
                                        style: const TextStyle(color: AppTheme.muted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _ProfileRow(label: 'Rol', value: user.tipo.isNotEmpty ? user.tipo : 'Sin rol'),
                            _ProfileRow(label: 'País', value: user.pais.isNotEmpty ? user.pais : 'Sin dato'),
                            _ProfileRow(label: 'Región', value: user.estado.isNotEmpty ? user.estado : 'Sin dato'),
                            _ProfileRow(label: 'Teléfono', value: user.telefono.isNotEmpty ? user.telefono : 'Sin dato'),
                            _ProfileRow(
                              label: 'Estado de verificación',
                              value: user.verificado ? 'Verificado' : 'Pendiente',
                            ),
                            _ProfileRow(
                              label: 'Estado operativo',
                              value: user.bloqueado ? 'Bloqueado' : 'Activo',
                            ),
                          ],
                        )
                      : const Text(
                          'No hay una sesión activa. Inicia sesión para ver tu perfil y tu estado operativo.',
                          style: TextStyle(color: AppTheme.muted, height: 1.5),
                        ),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () async {
                    if (hasSession) {
                      await PushNotificationService.instance.unregisterDevice();
                      await SessionService.clear();
                    }
                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.border),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(hasSession ? 'Cerrar sesión' : 'Ir a login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.muted),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
