import 'dart:math';

import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/models/user_model.dart';
import 'package:iway_app/features/auth/services/auth_service.dart';
import 'package:iway_app/features/notifications/services/push_notification_service.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class ContactVerificationScreen extends StatefulWidget {
  const ContactVerificationScreen({super.key});

  @override
  State<ContactVerificationScreen> createState() => _ContactVerificationScreenState();
}

class _ContactVerificationScreenState extends State<ContactVerificationScreen> {
  final _authService = AuthService();
  final codeController = TextEditingController();
  final phoneController = TextEditingController();
  final _random = Random();

  bool sendingCode = false;
  bool verifyingCode = false;
  bool sentInitialCode = false;
  String? _generatedCode;
  String _returnRoute = '/login';

  UserModel? get user => SessionService.currentUser;
  bool get canContinue => user?.telefonoVerificado == true;

  @override
  void initState() {
    super.initState();
    phoneController.text = user?.telefono ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['returnRoute'] is String) {
        _returnRoute = args['returnRoute'] as String;
      }
      _sendCodeIfNeeded();
    });
  }

  @override
  void dispose() {
    codeController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendCodeIfNeeded() async {
    if (sentInitialCode || canContinue) return;
    sentInitialCode = true;
    await _sendCode();
  }

  Future<void> _sendCode() async {
    setState(() => sendingCode = true);
    try {
      final code = (_random.nextInt(9000) + 1000).toString();
      await PushNotificationService.showLocalVerificationCode(code);
      if (!mounted) return;
      setState(() {
        _generatedCode = code;
        codeController.text = code;
        sendingCode = false;
      });
      showMessage('Te envié un código local de 4 dígitos.');
    } catch (_) {
      if (!mounted) return;
      setState(() => sendingCode = false);
      showMessage('No se pudo generar el código local.');
    }
  }

  Future<void> _verifyCode() async {
    final code = codeController.text.trim();
    if (code.length != 4) {
      showMessage('Ingresa un código válido de 4 dígitos.');
      return;
    }

    if ((_generatedCode ?? '').isEmpty) {
      showMessage('Primero toca Enviar código.');
      return;
    }

    setState(() => verifyingCode = true);
    if (code != _generatedCode) {
      setState(() => verifyingCode = false);
      showMessage('El código no coincide.');
      return;
    }

    await SessionService.markCurrentPhoneVerifiedLocally();
    try {
      await _authService.markPhoneVerified();
    } catch (_) {
      // Mantener la validación local aunque la sincronización remota falle temporalmente.
    }
    if (!mounted) return;
    setState(() => verifyingCode = false);
    showMessage('Tu cuenta quedó validada.');
  }

  Future<void> _continue() async {
    if (!canContinue) {
      showMessage('Primero valida tu número.');
      return;
    }

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
  }

  Future<void> _handleBack() async {
    if (canContinue) {
      if (!mounted) return;
      Navigator.maybePop(context);
      return;
    }

    final cancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar validación'),
        content: const Text('Si sales ahora, volverás al registro y tendrás que retomar la validación después.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir aquí'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar proceso'),
          ),
        ],
      ),
    );

    if (cancel == true && mounted) {
      Navigator.pushReplacementNamed(context, _returnRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = user;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _handleBack(),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: _handleBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const AppPageIntro(
                    title: 'Activa tu cuenta',
                    subtitle: 'Valida tu número antes de entrar al dashboard.',
                  ),
                  const SizedBox(height: 20),
                  AppGlassSection(
                    title: 'Estado actual',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser?.email ?? 'Sin correo',
                          style: const TextStyle(color: AppTheme.muted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          currentUser?.telefono ?? 'Sin teléfono',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Teléfono: ${currentUser?.telefonoVerificado == true ? 'verificado' : 'pendiente'}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppGlassSection(
                    title: 'Verificación local automática',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: phoneController,
                          readOnly: true,
                          decoration: const InputDecoration(labelText: 'Número de teléfono'),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: codeController,
                          decoration: const InputDecoration(
                            labelText: 'Código de 4 dígitos',
                          ),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _verifyCode(),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: sendingCode ? null : _sendCode,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: AppTheme.border),
                                  minimumSize: const Size(double.infinity, 52),
                                ),
                                child: Text(sendingCode ? 'Enviando...' : 'Enviar código'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: verifyingCode ? null : _verifyCode,
                                child: verifyingCode
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Validar'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Cuando toques Enviar código, i-Way generará un código local, lo mostrará en una notificación y lo escribirá automáticamente aquí.',
                          style: TextStyle(color: AppTheme.muted, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: canContinue ? _continue : null,
                    child: const Text('Continuar a iWay'),
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
