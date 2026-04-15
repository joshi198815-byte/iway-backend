import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/models/user_model.dart';
import 'package:iway_app/features/auth/services/auth_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class ContactVerificationScreen extends StatefulWidget {
  const ContactVerificationScreen({super.key});

  @override
  State<ContactVerificationScreen> createState() => _ContactVerificationScreenState();
}

class _ContactVerificationScreenState extends State<ContactVerificationScreen> {
  final authService = AuthService();
  final codeController = TextEditingController();

  String selectedChannel = 'email';
  bool sendingCode = false;
  bool verifyingCode = false;
  bool sentInitialCode = false;

  UserModel? get user => SessionService.currentUser;
  bool get canContinue =>
      (user?.emailVerificado ?? false) || (user?.telefonoVerificado ?? false);

  @override
  void initState() {
    super.initState();
    final currentUser = user;
    if (currentUser?.email.isEmpty == true && currentUser?.telefono.isNotEmpty == true) {
      selectedChannel = 'phone';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendCodeIfNeeded();
    });
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendCodeIfNeeded() async {
    if (sentInitialCode) return;
    sentInitialCode = true;
    await _sendCode(selectedChannel);
  }

  Future<void> _sendCode(String channel) async {
    setState(() => sendingCode = true);
    try {
      await authService.requestVerificationCode(channel);
      if (!mounted) return;
      setState(() {
        selectedChannel = channel;
        sendingCode = false;
      });
      showMessage(
        'Te envié un código de 6 dígitos por ${channel == 'email' ? 'correo' : 'teléfono'}.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => sendingCode = false);
      showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => sendingCode = false);
      showMessage('No se pudo enviar el código.');
    }
  }

  Future<void> _verifyCode() async {
    final code = codeController.text.trim();
    if (code.length != 6) {
      showMessage('Ingresa un código válido de 6 dígitos.');
      return;
    }

    setState(() => verifyingCode = true);
    try {
      final updatedUser = await authService.verifyContactCode(
        channel: selectedChannel,
        code: code,
      );
      if (!mounted) return;
      setState(() {
        verifyingCode = false;
        codeController.clear();
      });

      if (updatedUser == null) {
        showMessage('No pude actualizar tu estado de verificación.');
        return;
      }

      if (canContinue) {
        showMessage('Tu cuenta ya quedó activada.');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => verifyingCode = false);
      showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => verifyingCode = false);
      showMessage('No se pudo validar el código.');
    }
  }

  Future<void> _continue() async {
    if (!canContinue) {
      showMessage('Primero valida al menos un canal de contacto.');
      return;
    }

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = user;

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
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppPageIntro(
                  title: 'Activa tu cuenta',
                  subtitle: 'Antes de entrar, valida tu correo o tu teléfono con un código OTP de 6 dígitos.',
                ),
                const SizedBox(height: 20),
                AppGlassSection(
                  title: 'Estado actual',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser?.email ?? 'Sin correo',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentUser?.telefono ?? 'Sin teléfono',
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Correo: ${currentUser?.emailVerificado == true ? 'verificado' : 'pendiente'}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Teléfono: ${currentUser?.telefonoVerificado == true ? 'verificado' : 'pendiente'}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppGlassSection(
                  title: 'Verificación OTP',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ChoiceChip(
                            label: const Text('Correo'),
                            selected: selectedChannel == 'email',
                            onSelected: (_) => setState(() => selectedChannel = 'email'),
                          ),
                          ChoiceChip(
                            label: const Text('Teléfono'),
                            selected: selectedChannel == 'phone',
                            onSelected: (_) => setState(() => selectedChannel = 'phone'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: codeController,
                        decoration: const InputDecoration(
                          labelText: 'Código de 6 dígitos',
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
                              onPressed: sendingCode ? null : () => _sendCode(selectedChannel),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: AppTheme.border),
                                minimumSize: const Size(double.infinity, 52),
                              ),
                              child: Text(sendingCode ? 'Enviando...' : 'Reenviar código'),
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
                        'Si ya validaste uno de los dos canales, puedes continuar y completar el otro después desde tu perfil.',
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
    );
  }
}
