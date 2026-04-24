import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _rememberLoginKey = 'remember_login_enabled';
  static const _rememberedEmailKey = 'remembered_login_email';
  static const _rememberedPasswordKey = 'remembered_login_password';

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final authService = AuthService();

  bool loading = false;
  bool rememberMe = false;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
    if (SessionService.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          SessionService.currentUser?.telefonoVerificado == true ? '/home' : '/verify_contact',
        );
      });
    }
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRememberMe = prefs.getBool(_rememberLoginKey) ?? false;
    final savedEmail = prefs.getString(_rememberedEmailKey) ?? '';
    final savedPassword = prefs.getString(_rememberedPasswordKey) ?? '';

    if (!mounted) return;

    setState(() {
      rememberMe = savedRememberMe;
      if (savedRememberMe) {
        emailController.text = savedEmail;
        passwordController.text = savedPassword;
      }
    });
  }

  Future<void> _persistRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberLoginKey, rememberMe);

    if (rememberMe) {
      await prefs.setString(_rememberedEmailKey, emailController.text.trim());
      await prefs.setString(_rememberedPasswordKey, passwordController.text.trim());
      return;
    }

    await prefs.remove(_rememberedEmailKey);
    await prefs.remove(_rememberedPasswordKey);
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      showMessage('Ingresa un correo válido.');
      return;
    }

    if (password.length < 6) {
      showMessage('La contraseña debe tener al menos 6 caracteres.');
      return;
    }

    setState(() => loading = true);

    try {
      final user = await authService.login(email, password);

      if (!mounted) return;

      setState(() => loading = false);

      if (user != null) {
        await _persistRememberedCredentials();
        Navigator.pushReplacementNamed(
          context,
          SessionService.currentUser?.telefonoVerificado == true ? '/home' : '/verify_contact',
        );
      } else {
        showMessage('No se pudo iniciar sesión. Revisa tus datos.');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage('No se pudo iniciar sesión. ${e.toString()}');
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
                  title: 'Bienvenido a iWay',
                  subtitle: 'Logística GT ↔ USA con una experiencia más rápida, clara y segura.',
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
                      const _SectionBadge(label: 'Acceso seguro'),
                      const SizedBox(height: 18),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Correo',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => login(),
                      ),
                      const SizedBox(height: 8),
                      Theme(
                        data: Theme.of(context).copyWith(
                          checkboxTheme: CheckboxThemeData(
                            side: const BorderSide(color: AppTheme.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                          ),
                        ),
                        child: CheckboxListTile(
                          value: rememberMe,
                          onChanged: (value) async {
                            setState(() => rememberMe = value ?? false);
                            await _persistRememberedCredentials();
                          },
                          title: const Text('Recordar mis datos'),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: loading ? null : login,
                        child: loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Ingresar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/forgot_password'),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          loading
                              ? 'Validando tu cuenta y preparando tu panel...'
                              : 'Tus envíos, ofertas y tracking en un solo flujo.',
                          key: ValueKey(loading),
                          style: const TextStyle(color: AppTheme.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _ActionTile(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Crear cuenta como cliente',
                  subtitle: 'Publica envíos y compara ofertas de viajeros.',
                  onTap: () {
                    Navigator.pushNamed(context, '/register');
                  },
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.flight_takeoff_rounded,
                  title: 'Registrarme como viajero',
                  subtitle: 'Verifícate, recibe ofertas y comparte tracking.',
                  onTap: () {
                    Navigator.pushNamed(context, '/register_traveler');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionBadge extends StatelessWidget {
  final String label;

  const _SectionBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppTheme.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
