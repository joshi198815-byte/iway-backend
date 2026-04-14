import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/services/auth_service.dart';
import 'package:iway_app/features/notifications/services/push_notification_service.dart';
import 'package:iway_app/features/travelers/services/traveler_verification_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  final verificationService = TravelerVerificationService();
  final authService = AuthService();
  Map<String, dynamic>? verificationSummary;
  bool loadingVerification = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshProfileState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshProfileState();
    }
  }

  Future<void> _refreshProfileState() async {
    try {
      await authService.refreshCurrentUser();
    } catch (_) {}
    await _loadVerification();
    if (mounted) setState(() {});
  }

  Future<void> _requestVerification(String channel) async {
    try {
      await authService.requestVerificationCode(channel);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Código enviado por ${channel == 'phone' ? 'teléfono' : 'correo'} en tus notificaciones iWay.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _verifyCode(String channel) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(channel == 'phone' ? 'Verificar teléfono' : 'Verificar correo'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'Código de 6 dígitos'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Verificar')),
        ],
      ),
    );

    if (code == null || code.length != 6) return;

    try {
      await authService.verifyContactCode(channel: channel, code: code);
      await _refreshProfileState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${channel == 'phone' ? 'Teléfono' : 'Correo'} verificado correctamente.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _loadVerification() async {
    final user = SessionService.currentUser;
    if (user == null || user.tipo != 'traveler') return;

    setState(() => loadingVerification = true);
    try {
      final data = await verificationService.getMySummary();
      if (!mounted) return;
      setState(() => verificationSummary = data);
    } on ApiException {
    } catch (_) {
    } finally {
      if (mounted) setState(() => loadingVerification = false);
    }
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF59D38C);
    if (score >= 55) return const Color(0xFFFFD27A);
    return const Color(0xFFFF7A7A);
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;
    final hasSession = user != null;
    final isTraveler = user?.tipo == 'traveler';
    final summary = verificationSummary;
    final score = (summary?['score'] as num?)?.toInt() ?? 0;
    final flagsSummary = summary?['flagsSummary'];
    final trustScore = (summary?['trustScore'] as num?)?.toInt() ?? 0;

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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                const SizedBox(height: 24),
                const AppPageIntro(
                  title: 'Tu perfil',
                  subtitle: 'Sesión, rol, verificación y estado operativo dentro de iWay.',
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
                            _ProfileRow(label: 'Teléfono verificado', value: user.telefonoVerificado ? 'Sí' : 'No'),
                            _ProfileRow(label: 'Correo verificado', value: user.emailVerificado ? 'Sí' : 'No'),
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
                          'No hay una sesión activa. Inicia sesión para ver tu perfil, tu rol y tu estado operativo.',
                          style: TextStyle(color: AppTheme.muted, height: 1.5),
                        ),
                ),
                if (hasSession && (!user.telefonoVerificado || !user.emailVerificado)) ...[
                  const SizedBox(height: 16),
                  AppGlassSection(
                    title: 'Verificación de contacto',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Refuerza tu trust score verificando teléfono y correo con código.',
                          style: TextStyle(color: AppTheme.muted),
                        ),
                        const SizedBox(height: 12),
                        if (!user.telefonoVerificado)
                          Row(
                            children: [
                              Expanded(child: OutlinedButton(onPressed: () => _requestVerification('phone'), child: const Text('Enviar código teléfono'))),
                              const SizedBox(width: 10),
                              Expanded(child: ElevatedButton(onPressed: () => _verifyCode('phone'), child: const Text('Confirmar teléfono'))),
                            ],
                          ),
                        if (!user.telefonoVerificado && !user.emailVerificado) const SizedBox(height: 10),
                        if (!user.emailVerificado)
                          Row(
                            children: [
                              Expanded(child: OutlinedButton(onPressed: () => _requestVerification('email'), child: const Text('Enviar código correo'))),
                              const SizedBox(width: 10),
                              Expanded(child: ElevatedButton(onPressed: () => _verifyCode('email'), child: const Text('Confirmar correo'))),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
                if (hasSession && isTraveler) ...[
                  const SizedBox(height: 16),
                  AppGlassSection(
                    title: 'Verificación del viajero',
                    child: loadingVerification
                        ? const SizedBox(height: 72, child: Center(child: CircularProgressIndicator()))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatusMetric(
                                      label: 'Score',
                                      value: '$score / 100',
                                      color: _scoreColor(score),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _StatusMetric(
                                      label: 'Trust',
                                      value: '$trustScore / 100',
                                      color: _scoreColor(trustScore),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _StatusMetric(
                                      label: 'Flags',
                                      value: flagsSummary is Map<String, dynamic>
                                          ? '${flagsSummary['high'] ?? 0}H / ${flagsSummary['medium'] ?? 0}M'
                                          : '0',
                                      color: const Color(0xFF8AB4FF),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                summary == null
                                    ? 'Todavía no hay un resumen detallado disponible para este perfil.'
                                    : 'Estado actual: ${summary['currentStatus']} • Recomendación del sistema: ${summary['recommendedDecision']}',
                                style: const TextStyle(color: AppTheme.muted, height: 1.35),
                              ),
                              if (summary != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'KYC ${summary['currentKycTier']} → sugerido ${summary['suggestedKycTier']} • ${summary['payoutHoldRecommended'] == true ? 'Payout con hold recomendado' : 'Sin hold operativo recomendado'}',
                                  style: const TextStyle(color: AppTheme.muted, height: 1.35),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Device trust: ${(summary['deviceTrust']?['averageTrustScore'] ?? 0)} / 100 • ${(summary['deviceTrust']?['activeDevices'] ?? 0)} activo(s)',
                                  style: const TextStyle(color: AppTheme.muted, height: 1.35),
                                ),
                                if (summary['nextSteps'] is List && (summary['nextSteps'] as List).isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  ...((summary['nextSteps'] as List).take(3)).map(
                                    (step) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '• ${step.toString()}',
                                        style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  hasSession
                      ? 'Desde aquí puedes revisar tu estado y cerrar sesión de forma segura.'
                      : 'Si vuelves al login, podrás recuperar tu flujo y continuar donde te quedaste.',
                  style: const TextStyle(color: AppTheme.muted, height: 1.35),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () async {
                    if (hasSession) {
                      await PushNotificationService.deactivateCurrentToken();
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

class _StatusMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatusMetric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
        ],
      ),
    );
  }
}
