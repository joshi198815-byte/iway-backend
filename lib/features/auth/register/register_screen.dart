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
  final addressController = TextEditingController();

  final authService = AuthService();

  bool loading = false;
  String selectedCountry = supportedCountries.first;
  String? selectedRegion = guatemalaDepartments.first.name;
  String? selectedCity = municipalitiesForDepartment(guatemalaDepartments.first.name).firstOrNull;
  String? selectedZone;

  bool get _showZoneSelector => selectedCountry == 'Guatemala' && selectedRegion == 'Guatemala';
  bool get _showMunicipalitySelector => selectedCountry == 'Guatemala';

  List<String> get _regions => availableRegionsForCountry(selectedCountry);
  List<String> get _cities {
    if (selectedCountry == 'Guatemala') {
      return municipalitiesForDepartment(selectedRegion ?? '');
    }
    return citiesForUsState(selectedRegion ?? '');
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    if (SessionService.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      });
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    emailController.dispose();
    telefonoController.dispose();
    passwordController.dispose();
    addressController.dispose();
    super.dispose();
  }

  String get countryCode => selectedCountry == 'Guatemala' ? 'GT' : 'US';

  void _onCountryChanged(String? value) {
    if (value == null) return;
    final regions = availableRegionsForCountry(value);
    final region = regions.firstOrNull;
    setState(() {
      selectedCountry = value;
      selectedRegion = region;
      selectedCity = value == 'Guatemala'
          ? municipalitiesForDepartment(region ?? '').firstOrNull
          : citiesForUsState(region ?? '').firstOrNull;
      selectedZone = null;
    });
  }

  void _onRegionChanged(String? value) {
    if (value == null) return;
    setState(() {
      selectedRegion = value;
      selectedCity = selectedCountry == 'Guatemala'
          ? municipalitiesForDepartment(value).firstOrNull
          : citiesForUsState(value).firstOrNull;
      selectedZone = null;
    });
  }

  Future<void> register() async {
    final nombre = nombreController.text.trim();
    final email = emailController.text.trim();
    final telefono = telefonoController.text.trim();
    final password = passwordController.text.trim();
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

    if ((selectedRegion ?? '').isEmpty) {
      showMessage('Selecciona tu departamento o estado.');
      return;
    }

    if ((selectedCity ?? '').isEmpty) {
      showMessage(selectedCountry == 'Guatemala' ? 'Selecciona tu municipio.' : 'Selecciona tu ciudad base.');
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
        city: _showZoneSelector && (selectedZone ?? '').isNotEmpty
            ? '${selectedCity!} | $selectedZone'
            : selectedCity,
        address: address.isEmpty ? null : address,
      );

      if (!mounted) return;

      if (createdUser == null) {
        setState(() => loading = false);
        showMessage('No se pudo registrar el usuario.');
        return;
      }

      setState(() => loading = false);
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
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
            colors: [AppTheme.background, Color(0xFF101116), AppTheme.background],
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
                  subtitle: 'Registro limpio, token guardado y entrada directa al dashboard.',
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
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Correo'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: telefonoController,
                        decoration: const InputDecoration(labelText: 'Teléfono'),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(labelText: 'Contraseña'),
                        obscureText: true,
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
                        value: selectedCountry,
                        decoration: const InputDecoration(labelText: 'País'),
                        items: supportedCountries
                            .map((country) => DropdownMenuItem(value: country, child: Text(country)))
                            .toList(),
                        onChanged: _onCountryChanged,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedRegion,
                        decoration: InputDecoration(
                          labelText: selectedCountry == 'Guatemala' ? 'Departamento' : 'Estado',
                        ),
                        items: _regions
                            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                            .toList(),
                        onChanged: _onRegionChanged,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedCity,
                        decoration: InputDecoration(
                          labelText: selectedCountry == 'Guatemala' ? 'Municipio' : 'Ciudad',
                        ),
                        items: _cities
                            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                            .toList(),
                        onChanged: (value) => setState(() => selectedCity = value),
                      ),
                      if (_showZoneSelector) ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: selectedZone,
                          decoration: const InputDecoration(labelText: 'Zona'),
                          items: zonesForDepartment('Guatemala')
                              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                              .toList(),
                          onChanged: (value) => setState(() => selectedZone = value),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(labelText: 'Dirección base'),
                        maxLines: 2,
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
                Text(
                  loading
                      ? 'Estamos guardando tu sesión y preparando tu dashboard...'
                      : 'Si el backend responde OK, entras directo al panel sin pantallas fantasma.',
                  style: const TextStyle(color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
