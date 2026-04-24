import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/data/location_catalogs.dart';
import 'package:iway_app/features/auth/services/auth_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Crear cuenta',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Primero elige cómo vas a usar iWay.',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 24),
                    _RoleCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'Registrarme como Usuario',
                      subtitle: 'Publica envíos, revisa ofertas y sigue tu paquete con una vista simple.',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const _CustomerRegisterFormScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _RoleCard(
                      icon: Icons.flight_takeoff_rounded,
                      title: 'Registrarme como Viajero',
                      subtitle: 'Recibe tareas, confirma carga, entrega y opera sin ruido.',
                      onTap: () => Navigator.pushNamed(context, '/register_traveler'),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Ya tengo cuenta'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerRegisterFormScreen extends StatefulWidget {
  const _CustomerRegisterFormScreen();

  @override
  State<_CustomerRegisterFormScreen> createState() => _CustomerRegisterFormScreenState();
}

class _CustomerRegisterFormScreenState extends State<_CustomerRegisterFormScreen> {
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
  List<String> get _regions => availableRegionsForCountry(selectedCountry);
  List<String> get _cities {
    if (selectedCountry == 'Guatemala') {
      return municipalitiesForDepartment(selectedRegion ?? '');
    }
    return citiesForUsState(selectedRegion ?? '');
  }

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    nombreController.dispose();
    emailController.dispose();
    telefonoController.dispose();
    passwordController.dispose();
    addressController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String get countryCode => selectedCountry == 'Guatemala' ? 'GT' : 'US';

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
      showMessage(selectedCountry == 'Guatemala' ? 'Selecciona tu municipio.' : 'Selecciona tu ciudad.');
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
      setState(() => loading = false);

      if (createdUser == null) {
        showMessage('No se pudo registrar el usuario.');
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/verify_contact',
        (_) => false,
        arguments: const {'returnRoute': '/register'},
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage('No se pudo completar el registro. ${e.toString()}');
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
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Registro de Usuario',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crea tu cuenta para publicar envíos y revisar ofertas sin pasos innecesarios.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 24),
                  _FormCard(
                    child: Column(
                      children: [
                        TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre completo')),
                        const SizedBox(height: 14),
                        TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Correo')),
                        const SizedBox(height: 14),
                        TextField(controller: telefonoController, decoration: const InputDecoration(labelText: 'Teléfono')),
                        const SizedBox(height: 14),
                        TextField(
                          controller: passwordController,
                          decoration: const InputDecoration(labelText: 'Contraseña'),
                          obscureText: true,
                          onSubmitted: (_) => register(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FormCard(
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
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: selectedRegion,
                          decoration: InputDecoration(labelText: selectedCountry == 'Guatemala' ? 'Departamento' : 'Estado'),
                          items: _regions
                              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              selectedRegion = value;
                              selectedCity = selectedCountry == 'Guatemala'
                                  ? municipalitiesForDepartment(value).firstOrNull
                                  : citiesForUsState(value).firstOrNull;
                              selectedZone = null;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCity,
                          decoration: InputDecoration(labelText: selectedCountry == 'Guatemala' ? 'Municipio' : 'Ciudad'),
                          items: _cities.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                          onChanged: (value) => setState(() => selectedCity = value),
                        ),
                        if (_showZoneSelector) ...[
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: selectedZone,
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
                  const SizedBox(height: 20),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppTheme.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: const TextStyle(color: AppTheme.muted, height: 1.35)),
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

class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: child,
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
