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
  final phoneController = TextEditingController();

  bool sendingCode = false;
  bool verifyingCode = false;
  bool savingPhone = false;
  bool sentInitialCode = false;

  UserModel? get user => SessionService.currentUser;
  bool get canContinue => user?.telefonoVerificado == true;

  @override
  void initState() {
    super.initState();
    phoneController.text = user?.telefono ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      await authService.requestVerificationCode('phone');
      if (!mounted) return;
      setState(() => sendingCode = false);
      showMessage('Te envié un código de 6 dígitos a tu teléfono.');
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

  Future<void> _savePhone() async {
    final phone = phoneController.text.trim();
    if (phone.length < 8) {
      showMessage('Ingresa un número válido.');
      return;
    }

    setState(() => savingPhone = true);
    try {
      final updatedUser = await authService.updatePendingPhone(phone);
      if (!mounted) return;
      setState(() {
        savingPhone = false;
        sentInitialCode = false;
      });

      if (updatedUser == null) {
        showMessage('No pude actualizar tu teléfono.');
        return;
      }

      showMessage('Número actualizado. Ahora valida ese teléfono.');
      await _sendCode();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => savingPhone = false);
      showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => savingPhone = false);
      showMessage('No se pudo actualizar el teléfono.');
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
        channel: 'phone',
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
        showMessage('Tu teléfono ya quedó validado.');
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
      showMessage('Primero valida tu número de teléfono.');
      return;
    }

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = user;

    return WillPopScope(
      onWillPop: () async => false,
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
                  const AppPageIntro(
                    title: 'Activa tu cuenta',
                    subtitle: 'Antes de crear envíos, valida tu número de teléfono con un código OTP de 6 dígitos.',
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
                    title: 'Corrige tu número si está mal',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(labelText: 'Número de teléfono'),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: savingPhone ? null : _savePhone,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: AppTheme.border),
                              minimumSize: const Size(double.infinity, 52),
                            ),
                            child: Text(savingPhone ? 'Guardando...' : 'Actualizar número'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppGlassSection(
                    title: 'Verificación por teléfono',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                onPressed: sendingCode ? null : _sendCode,
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
                          'Hasta validar tu número no podrás crear envíos. Si el número estaba mal, cámbialo arriba y vuelve a pedir el código.',
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
