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
  final _apiClient = ApiClient();

  bool _submitting = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Ingresa un correo válido.');
      return;
    }

    setState(() => _submitting = true);

    try {
      await _apiClient.post('/auth/forgot-password', {
        'email': email,
      });

      if (!mounted) return;
      _showMessage('Si el correo existe, recibirás instrucciones para recuperar tu contraseña.');
      Navigator.maybePop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      final normalized = e.message.toLowerCase();
      if (e.statusCode == 404 || normalized.contains('not found')) {
        _showMessage('La recuperación de contraseña aún no está habilitada en este servidor.');
      } else {
        _showMessage(e.message);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('No se pudo procesar la solicitud. ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
                  subtitle: 'Ingresa tu correo para solicitar el reinicio de acceso.',
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
                        decoration: const InputDecoration(
                          labelText: 'Correo',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Solicitar recuperación'),
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
