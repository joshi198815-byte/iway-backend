import 'dart:io';

import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/data/location_catalogs.dart';
import 'package:iway_app/features/auth/models/traveler_type.dart';
import 'package:iway_app/features/auth/services/auth_service.dart';
import 'package:iway_app/features/auth/services/image_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/services/upload_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class TravelerRegisterScreen extends StatefulWidget {
  const TravelerRegisterScreen({super.key});

  @override
  State<TravelerRegisterScreen> createState() => _TravelerRegisterScreenState();
}

class _TravelerRegisterScreenState extends State<TravelerRegisterScreen> {
  final nombreController = TextEditingController();
  final emailController = TextEditingController();
  final telefonoController = TextEditingController();
  final direccionController = TextEditingController();
  final documentoController = TextEditingController();
  final passwordController = TextEditingController();
  final cityController = TextEditingController();

  TravelerType? selectedType;
  String selectedCountry = supportedCountries.first;
  String? selectedRegion;

  final authService = AuthService();
  final imageService = ImageService();
  final uploadService = UploadService();

  File? selfie;
  File? documentPhoto;
  bool loading = false;

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
        Navigator.pushReplacementNamed(context, '/home');
      });
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    emailController.dispose();
    telefonoController.dispose();
    direccionController.dispose();
    documentoController.dispose();
    passwordController.dispose();
    cityController.dispose();
    super.dispose();
  }

  Future<void> takeSelfie() async {
    final photo = await imageService.takePhoto();
    if (photo == null) return;

    setState(() {
      selfie = photo;
    });
  }

  Future<void> takeDocumentPhoto() async {
    final photo = await imageService.takePhoto();
    if (photo == null) return;

    setState(() {
      documentPhoto = photo;
    });
  }

  String get countryCode => selectedCountry == 'Guatemala' ? 'GT' : 'US';

  Future<void> register() async {
    final nombre = nombreController.text.trim();
    final email = emailController.text.trim();
    final telefono = telefonoController.text.trim();
    final direccion = direccionController.text.trim();
    final documento = documentoController.text.trim();
    final password = passwordController.text.trim();
    final city = cityController.text.trim();

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

    if (direccion.isEmpty) {
      showMessage('Ingresa tu dirección.');
      return;
    }

    if (selectedRegion == null || selectedRegion!.isEmpty) {
      showMessage('Selecciona tu departamento o estado.');
      return;
    }

    if (documento.isEmpty) {
      showMessage('Ingresa tu DPI o pasaporte.');
      return;
    }

    if (selectedType == null) {
      showMessage('Selecciona el tipo de viajero.');
      return;
    }

    if (documentPhoto == null) {
      showMessage('Toma una foto de tu documento para continuar.');
      return;
    }

    if (selfie == null) {
      showMessage('Tómate una selfie para continuar.');
      return;
    }

    setState(() => loading = true);

    try {
      final documentBase64 = await uploadService.encodeImageAsDataUrl(documentPhoto!);
      final selfieBase64 = await uploadService.encodeImageAsDataUrl(selfie!);

      final createdUser = await authService.registerTraveler(
        fullName: nombre,
        email: email,
        phone: telefono,
        password: password,
        travelerType: selectedType!,
        documentNumber: documento,
        countryCode: countryCode,
        detectedCountryCode: countryCode,
        stateRegion: selectedRegion,
        city: city.isEmpty ? null : city,
        address: direccion,
        documentBase64: documentBase64,
        selfieBase64: selfieBase64,
      );

      if (!mounted) return;

      setState(() => loading = false);

      if (createdUser == null) {
        showMessage('No se pudo registrar el viajero.');
        return;
      }

      Navigator.pushReplacementNamed(context, '/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage('No se pudo completar el registro del viajero.');
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
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                const SizedBox(height: 24),
                const AppPageIntro(
                  title: 'Regístrate como viajero',
                  subtitle: 'Verifícate, toma ofertas y reporta tracking entre Guatemala y Estados Unidos.',
                ),
                const SizedBox(height: 24),
                AppGlassSection(
                  title: 'Cuenta',
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
                  title: 'Base operativa',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedCountry,
                        decoration: const InputDecoration(labelText: 'País base'),
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
                      DropdownButtonFormField<String>(
                        initialValue: selectedRegion,
                        decoration: InputDecoration(
                          labelText: selectedCountry == 'Guatemala' ? 'Departamento' : 'Estado',
                        ),
                        items: availableRegions
                            .map((region) => DropdownMenuItem(value: region, child: Text(region)))
                            .toList(),
                        onChanged: (value) => setState(() => selectedRegion = value),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: cityController,
                        decoration: const InputDecoration(labelText: 'Ciudad'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: direccionController,
                        decoration: const InputDecoration(labelText: 'Dirección'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppGlassSection(
                  title: 'Validación y ruta',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<TravelerType>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(labelText: 'Tipo de viajero'),
                        items: TravelerType.values
                            .map((type) => DropdownMenuItem(value: type, child: Text(type.label)))
                            .toList(),
                        onChanged: (value) => setState(() => selectedType = value),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: documentoController,
                        decoration: const InputDecoration(labelText: 'DPI / Pasaporte'),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Documento de identidad',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sube una foto clara de tu DPI o pasaporte. Se guarda en el backend para revisión.',
                        style: TextStyle(color: AppTheme.muted, height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        documentPhoto == null
                            ? 'Toma una foto frontal y legible del documento.'
                            : 'Documento listo para subir.',
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: loading ? null : takeDocumentPhoto,
                        icon: const Icon(Icons.badge_outlined),
                        label: Text(documentPhoto == null ? 'Tomar foto del documento' : 'Repetir documento'),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Selfie de verificación',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'La selfie se guarda junto con el documento para validar identidad del viajero.',
                        style: TextStyle(color: AppTheme.muted, height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selfie == null
                            ? 'Tip: toma una foto con buena luz para completar el alta más rápido.'
                            : 'Selfie lista. Ya puedes terminar tu registro.',
                        style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: takeSelfie,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(selfie == null ? 'Tomar selfie' : 'Cambiar selfie'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.border),
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      if (selfie != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(
                              selfie!,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
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
                      : const Text('Registrar viajero'),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    loading
                        ? 'Validando tu perfil de viajero y preparando tu acceso...'
                        : 'Tu perfil quedará listo para recibir ofertas y compartir tracking.',
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
