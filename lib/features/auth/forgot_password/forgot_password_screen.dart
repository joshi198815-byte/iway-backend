import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _apiClient = ApiClient();

  bool _requestingCode = false;
  bool _resettingPassword = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Ingresa un correo válido.');
      return;
    }

    setState(() => _requestingCode = true);

    try {
      await _apiClient.post('/auth/forgot-password', {
        'email': email,
      });

      if (!mounted) return;
      _showMessage('Si la cuenta existe, enviamos un código de recuperación por correo.');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      _showMessage('No se pudo solicitar el código. ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _requestingCode = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Ingresa un correo válido.');
      return;
    }

    if (code.length != 6) {
      _showMessage('Ingresa el código de 6 dígitos.');
      return;
    }

    if (newPassword.length < 6) {
      _showMessage('La nueva contraseña debe tener al menos 6 caracteres.');
      return;
    }

    setState(() => _resettingPassword = true);

    try {
      await _apiClient.post('/auth/reset-password', {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      });

      if (!mounted) return;
      _showMessage('Contraseña actualizada. Ya puedes iniciar sesión.');
      Navigator.pushReplacementNamed(context, '/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      _showMessage('No se pudo restablecer la contraseña. ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _resettingPassword = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    return const InputDecoration().copyWith(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
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
              Color(0xFF121318),
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                const SizedBox(height: 28),
                const AppPageIntro(
                  title: 'Recuperar contraseña',
                  subtitle: 'Solicita tu código por correo y cambia tu contraseña desde aquí.',
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: _inputDecoration('Correo'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _requestingCode ? null : _requestCode,
                          child: _requestingCode
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Enviar código'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _codeController,
                        decoration: _inputDecoration('Código de recuperación'),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _newPasswordController,
                        decoration: _inputDecoration('Nueva contraseña'),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _resetPassword(),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _resettingPassword ? null : _resetPassword,
                        child: _resettingPassword
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Restablecer contraseña'),
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
