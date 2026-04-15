import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/data/location_catalogs.dart';
import 'package:iway_app/features/auth/services/auth_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nombreController = TextEditingController();
  final emailController = TextEditingController();
  final telefonoController = TextEditingController();
  final passwordController = TextEditingController();
  final cityController = TextEditingController();
  final addressController = TextEditingController();

  final authService = AuthService();

  bool loading = false;
  String selectedCountry = supportedCountries.first;
  String? selectedRegion;

  List<String> get availableRegions =>
      supportedRegionsByCountry[selectedCountry] ?? const [];

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    selectedRegion = availableRegions.isNotEmpty ? availableRegions.first : null;

    if (SessionService.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final currentUser = SessionService.currentUser;
        final nextRoute = currentUser != null &&
                !currentUser.emailVerificado &&
                !currentUser.telefonoVerificado
            ? '/verify_contact'
            : '/home';
        Navigator.pushReplacementNamed(context, nextRoute);
      });
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    emailController.dispose();
    telefonoController.dispose();
    passwordController.dispose();
    cityController.dispose();
    addressController.dispose();
    super.dispose();
  }

  String get countryCode => selectedCountry == 'Guatemala' ? 'GT' : 'US';

  Future<void> pickRegion() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: 360,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedCountry == 'Guatemala' ? 'Selecciona departamento' : 'Selecciona estado',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: availableRegions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final region = availableRegions[index];
                      final selected = selectedRegion == region;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: selected ? AppTheme.accent : AppTheme.border,
                          ),
                        ),
                        tileColor: AppTheme.surfaceSoft,
                        title: Text(region),
                        trailing: selected
                            ? const Icon(Icons.check_circle_rounded, color: AppTheme.accent)
                            : null,
                        onTap: () => Navigator.pop(context, region),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null) return;
    setState(() => selectedRegion = picked);
  }

  Future<void> register() async {
    final nombre = nombreController.text.trim();
    final email = emailController.text.trim();
    final telefono = telefonoController.text.trim();
    final password = passwordController.text.trim();
    final city = cityController.text.trim();
    final address = addressController.text.trim();

    if (nombre.isEmpty) {
      showMessage('Ingresa tu nombre.');
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      showMessage('Ingresa un correo válido.');
      return;
    }

    if (telefono.length < 8) {
      showMessage('Ingresa un teléfono válido.');
      return;
    }

    if (password.length < 6) {
      showMessage('La contraseña debe tener al menos 6 caracteres.');
      return;
    }

    if (selectedRegion == null || selectedRegion!.isEmpty) {
      showMessage('Selecciona tu departamento o estado.');
      return;
    }

    setState(() => loading = true);

    try {
      final createdUser = await authService.registerCustomer(
        fullName: nombre,
        email: email,
        phone: telefono,
        password: password,
        countryCode: countryCode,
        stateRegion: selectedRegion,
        city: city.isEmpty ? null : city,
        address: address.isEmpty ? null : address,
      );

      if (!mounted) return;

      setState(() => loading = false);

      if (createdUser == null) {
        showMessage('No se pudo registrar el usuario.');
        return;
      }

      await authService.requestVerificationCode('email');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/verify_contact');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage('No se pudo completar el registro.');
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
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                const SizedBox(height: 24),
                const AppPageIntro(
                  title: 'Crea tu cuenta',
                  subtitle: 'Publica envíos, recibe ofertas y sigue todo en tiempo real.',
                ),
                const SizedBox(height: 24),
                AppGlassSection(
                  title: 'Perfil',
                  child: Column(
                    children: [
                      TextField(
                        controller: nombreController,
                        decoration: const InputDecoration(labelText: 'Nombre completo'),
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Correo'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: telefonoController,
                        decoration: const InputDecoration(labelText: 'Teléfono'),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(labelText: 'Contraseña'),
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => register(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppGlassSection(
                  title: 'Ubicación base',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedCountry,
                        decoration: const InputDecoration(labelText: 'País'),
                        items: supportedCountries
                            .map((country) => DropdownMenuItem(value: country, child: Text(country)))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            selectedCountry = value;
                            selectedRegion = availableRegionsForCountry(selectedCountry).firstOrNull;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: pickRegion,
                        borderRadius: BorderRadius.circular(18),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: selectedCountry == 'Guatemala' ? 'Departamento' : 'Estado',
                            suffixIcon: const Icon(Icons.expand_more_rounded),
                          ),
                          child: Text(selectedRegion ?? 'Seleccionar'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: cityController,
                        decoration: const InputDecoration(labelText: 'Ciudad'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(labelText: 'Dirección'),
                        maxLines: 2,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: loading ? null : register,
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Crear cuenta'),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    loading
                        ? 'Estamos creando tu cuenta y conectando tu sesión...'
                        : 'Podrás publicar envíos y revisar ofertas desde el primer minuto.',
                    key: ValueKey(loading),
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> availableRegionsForCountry(String country) {
    return supportedRegionsByCountry[country] ?? const [];
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
