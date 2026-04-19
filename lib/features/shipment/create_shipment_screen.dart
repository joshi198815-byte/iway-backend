import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/data/location_catalogs.dart';
import 'package:iway_app/features/auth/services/auth_service.dart';
import 'package:iway_app/features/auth/services/image_service.dart';
import 'package:iway_app/features/auth/services/location_service.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/address_search_service.dart';
import 'package:iway_app/features/shipment/services/insurance_service.dart';
import 'package:iway_app/features/shipment/services/saved_recipient_service.dart';
import 'package:iway_app/features/shipment/services/saved_sender_service.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class CreateShipmentScreen extends StatefulWidget {
  const CreateShipmentScreen({super.key});

  @override
  State<CreateShipmentScreen> createState() => _CreateShipmentScreenState();
}

class _CreateShipmentScreenState extends State<CreateShipmentScreen> {
  static const Map<String, String> _countryNameToCode = {
    'Guatemala': 'GT',
    'Estados Unidos': 'US',
  };

  static const List<String> _restrictedProducts = [
    'armas',
    'arma',
    'municiones',
    'explosivos',
    'droga',
    'drogas',
    'marihuana',
    'cocaina',
    'cocaína',
    'vape',
    'vapes',
    'alcohol',
    'dinero en efectivo',
    'efectivo',
    'animales vivos',
    'combustible',
    'quimicos',
    'químicos',
    'corrosivos',
  ];

  static const List<String> _basePackageTypes = [
    'libra',
    'carga',
    'documento',
    'medicina',
  ];

  static const List<String> _vehiclePackageTypes = [
    'carros',
    'motos',
    'buses',
    'lanchas',
  ];

  final descripcionController = TextEditingController();
  final valorController = TextEditingController();
  final pesoController = TextEditingController();
  final receptorNombreController = TextEditingController();
  final receptorTelefonoController = TextEditingController();
  final receptorDireccionController = TextEditingController();
  final vinController = TextEditingController();

  final shipmentService = ShipmentService();
  final authService = AuthService();
  final imageService = ImageService();
  final insuranceService = InsuranceService();
  final addressSearchService = AddressSearchService();
  final locationService = LocationService();
  final savedRecipientService = SavedRecipientService();
  final savedSenderService = SavedSenderService();

  List<SavedRecipient> savedRecipients = [];
  List<SavedSender> savedSenders = [];
  SavedSender? selectedSender;

  final List<File> images = [];
  final List<AddressSuggestion> addressSuggestions = [];

  Timer? _addressDebounce;

  String tipo = 'libra';
  String origen = 'GT';
  String destino = 'US';
  String receiverCountry = 'Estados Unidos';
  String receiverRegion = supportedRegionsByCountry['Estados Unidos']!.first;
  bool seguro = false;
  bool loading = false;
  bool acceptedForeignRestrictions = false;
  bool loadingAddressSuggestions = false;
  double costoSeguro = 0;
  String? geocodedAddressLabel;

  bool get isForeignDestination => destino == 'US';
  bool get isUsToGtRoute => origen == 'US' && destino == 'GT';
  bool get requiresVin => _vehiclePackageTypes.contains(tipo);

  List<String> get availableRegions =>
      supportedRegionsByCountry[receiverCountry] ?? const [];

  List<String> get availablePackageTypes => [
        ..._basePackageTypes,
        if (isUsToGtRoute) ..._vehiclePackageTypes,
      ];

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    _seedCurrentSender();
    _loadSavedSenders();
    _loadSavedRecipients();
  }

  void _seedCurrentSender() {
    final user = SessionService.currentUser;
    if (user == null) return;
    selectedSender = SavedSender(
      name: user.nombre,
      phone: user.telefono,
      address: user.direccion,
      countryCode: user.pais,
      stateRegion: user.estado,
    );
  }

  Future<void> _loadSavedSenders() async {
    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty) return;
    final data = await savedSenderService.getAll(userId);
    if (!mounted) return;
    setState(() => savedSenders = data);
  }

  Future<void> _saveCurrentSender({bool notify = true}) async {
    final userId = SessionService.currentUserId;
    final user = SessionService.currentUser;
    if (userId == null || userId.isEmpty || user == null) return;

    final sender = SavedSender(
      name: user.nombre.trim(),
      phone: user.telefono.trim(),
      address: user.direccion.trim(),
      countryCode: user.pais.trim(),
      stateRegion: user.estado.trim(),
    );

    if (sender.name.isEmpty || sender.phone.length < 8 || sender.address.isEmpty) {
      if (notify) {
        showMessage('Completa tu perfil antes de guardar un remitente.');
      }
      return;
    }

    await savedSenderService.save(userId, sender);
    await _loadSavedSenders();
    if (!mounted) return;
    setState(() => selectedSender = sender);
    if (notify) {
      showMessage('Remitente guardado para próximos envíos.');
    }
  }

  Future<void> _applySenderProfile(SavedSender sender) async {
    final user = SessionService.currentUser;
    if (user == null) return;

    await authService.updateProfile(
      fullName: sender.name,
      phone: sender.phone,
      countryCode: sender.countryCode,
      stateRegion: sender.stateRegion,
      address: sender.address,
      selfieUrl: user.selfiePath,
    );
    await authService.refreshCurrentUser();
    if (!mounted) return;
    setState(() => selectedSender = sender);
  }

  Future<void> _removeSavedSender(SavedSender sender) async {
    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty) return;
    await savedSenderService.remove(userId, sender);
    await _loadSavedSenders();
  }

  Future<void> _createSenderProfile() async {
    final user = SessionService.currentUser;
    final userId = SessionService.currentUserId;
    if (user == null || userId == null || userId.isEmpty) return;

    final nameController = TextEditingController(text: user.nombre);
    final phoneController = TextEditingController(text: user.telefono);
    final addressController = TextEditingController(text: user.direccion);
    String countryCode = user.pais.isNotEmpty ? user.pais : 'GT';
    String stateRegion = user.estado;

    final created = await showModalBottomSheet<SavedSender>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nuevo remitente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre completo')),
                    const SizedBox(height: 12),
                    TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Teléfono'), keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: countryCode,
                      decoration: const InputDecoration(labelText: 'País'),
                      items: const [
                        DropdownMenuItem(value: 'GT', child: Text('Guatemala')),
                        DropdownMenuItem(value: 'US', child: Text('Estados Unidos')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() {
                          countryCode = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Dirección base'), maxLines: 2),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: stateRegion,
                      decoration: const InputDecoration(labelText: 'Estado o región'),
                      onChanged: (value) => stateRegion = value,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final sender = SavedSender(
                            name: nameController.text.trim(),
                            phone: phoneController.text.trim(),
                            address: addressController.text.trim(),
                            countryCode: countryCode,
                            stateRegion: stateRegion.trim(),
                          );
                          Navigator.pop(context, sender);
                        },
                        child: const Text('Guardar remitente'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();

    if (created == null) return;
    if (created.name.isEmpty || created.phone.length < 8 || created.address.isEmpty) {
      showMessage('Completa nombre, teléfono y dirección para guardar el remitente.');
      return;
    }

    await savedSenderService.save(userId, created);
    await _loadSavedSenders();
    if (!mounted) return;
    setState(() => selectedSender = created);
    showMessage('Remitente creado y listo para usar.');
  }

  Future<void> _loadSavedRecipients() async {
    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty) return;
    final data = await savedRecipientService.getAll(userId);
    if (!mounted) return;
    setState(() => savedRecipients = data);
  }

  void _applySavedRecipient(SavedRecipient recipient) {
    setState(() {
      receiverCountry = recipient.country;
      receiverRegion = recipient.region;
      receptorNombreController.text = recipient.name;
      receptorTelefonoController.text = recipient.phone;
      receptorDireccionController.text = recipient.address;
      geocodedAddressLabel = null;
      addressSuggestions.clear();
    });
  }

  Future<void> _saveCurrentRecipient({bool notify = true}) async {
    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty) return;

    final recipient = SavedRecipient(
      name: receptorNombreController.text.trim(),
      phone: receptorTelefonoController.text.trim(),
      address: receptorDireccionController.text.trim(),
      country: receiverCountry,
      region: receiverRegion,
    );

    if (recipient.name.isEmpty || recipient.phone.length < 8 || recipient.address.isEmpty || recipient.region.isEmpty) {
      if (notify) {
        showMessage('Completa nombre, teléfono, dirección y estado antes de guardar el destinatario.');
      }
      return;
    }

    await savedRecipientService.save(userId, recipient);
    await _loadSavedRecipients();
    if (!mounted || !notify) return;
    showMessage('Destinatario guardado para próximos envíos.');
  }

  Future<void> _removeSavedRecipient(SavedRecipient recipient) async {
    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty) return;
    await savedRecipientService.remove(userId, recipient);
    await _loadSavedRecipients();
  }

  Future<void> _ensureSelectedSenderApplied() async {
    final user = SessionService.currentUser;
    final sender = selectedSender;
    if (user == null || sender == null) return;

    final sameSender = user.nombre.trim() == sender.name.trim() &&
        user.telefono.trim() == sender.phone.trim() &&
        user.direccion.trim() == sender.address.trim() &&
        user.pais.trim() == sender.countryCode.trim() &&
        user.estado.trim() == sender.stateRegion.trim();

    if (sameSender) return;

    await _applySenderProfile(sender);
  }

  @override
  void dispose() {
    _addressDebounce?.cancel();
    descripcionController.dispose();
    valorController.dispose();
    pesoController.dispose();
    receptorNombreController.dispose();
    receptorTelefonoController.dispose();
    receptorDireccionController.dispose();
    vinController.dispose();
    super.dispose();
  }

  Future<void> addImage() async {
    final img = await imageService.takePhoto();
    if (img == null) return;

    setState(() {
      images.add(img);
    });
  }

  void calcularSeguro() {
    final valor = double.tryParse(valorController.text.trim()) ?? 0;
    setState(() {
      costoSeguro = insuranceService.calcularSeguro(valor);
    });
  }

  void _syncRouteState({String? nextOrigin, String? nextDestination}) {
    final resolvedOrigin = nextOrigin ?? origen;
    final resolvedDestination = nextDestination ?? destino;
    final nextCountry = resolvedDestination == 'GT' ? 'Guatemala' : 'Estados Unidos';
    final nextRegions = supportedRegionsByCountry[nextCountry] ?? const [];
    final vehicleStillAllowed =
        resolvedOrigin == 'US' && resolvedDestination == 'GT' && _vehiclePackageTypes.contains(tipo);

    setState(() {
      origen = resolvedOrigin;
      destino = resolvedDestination;
      receiverCountry = nextCountry;
      receiverRegion = nextRegions.isNotEmpty ? nextRegions.first : '';
      acceptedForeignRestrictions = resolvedDestination != 'US';
      geocodedAddressLabel = null;
      addressSuggestions.clear();
      if (!vehicleStillAllowed && _vehiclePackageTypes.contains(tipo)) {
        tipo = 'libra';
        vinController.clear();
      }
    });
  }

  String _composeAddress() {
    final pieces = [
      receptorDireccionController.text.trim(),
      if (receiverRegion.isNotEmpty) receiverRegion,
      receiverCountry,
    ].where((item) => item.isNotEmpty).toList();

    return pieces.join(', ');
  }

  String? _findRestrictedProduct(String description) {
    final normalized = description.toLowerCase();
    for (final item in _restrictedProducts) {
      if (normalized.contains(item)) {
        return item;
      }
    }
    return null;
  }

  String _shipmentTypeLabel(String value) {
    switch (value) {
      case 'libra':
        return 'Por libra';
      case 'carga':
        return 'Carga grande';
      case 'documento':
        return 'Documentos';
      case 'medicina':
        return 'Medicina';
      case 'carros':
        return 'Carros';
      case 'motos':
        return 'Motos';
      case 'buses':
        return 'Buses';
      case 'lanchas':
        return 'Lanchas';
      default:
        return value;
    }
  }

  Future<void> _loadAddressSuggestions(String query) async {
    _addressDebounce?.cancel();

    if (!isForeignDestination) {
      setState(() {
        addressSuggestions.clear();
        loadingAddressSuggestions = false;
      });
      return;
    }

    if (query.trim().length < 3) {
      setState(() {
        addressSuggestions.clear();
        loadingAddressSuggestions = false;
      });
      return;
    }

    _addressDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => loadingAddressSuggestions = true);

      try {
        final suggestions = await addressSearchService.autocompleteAddresses(
          input: query,
          countryCode: destino,
        );

        if (!mounted) return;
        setState(() {
          addressSuggestions
            ..clear()
            ..addAll(suggestions);
          loadingAddressSuggestions = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => loadingAddressSuggestions = false);
      }
    });
  }

  Future<void> _selectAddressSuggestion(AddressSuggestion suggestion) async {
    receptorDireccionController.text = suggestion.description;
    setState(() {
      geocodedAddressLabel = suggestion.description;
      addressSuggestions.clear();
    });
  }

  Future<void> pickReceiverRegion() async {
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
                          receiverCountry == 'Guatemala' ? 'Selecciona departamento' : 'Selecciona estado',
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
                      final selected = receiverRegion == region;
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
    setState(() {
      receiverRegion = picked;
      geocodedAddressLabel = null;
    });
  }

  Future<void> createShipment() async {
    final descripcion = descripcionController.text.trim();
    final valor = double.tryParse(valorController.text.trim());
    final peso = double.tryParse(pesoController.text.trim());
    final receptorNombre = receptorNombreController.text.trim();
    final receptorTelefono = receptorTelefonoController.text.trim();
    final receptorDireccion = receptorDireccionController.text.trim();
    final vin = vinController.text.trim();
    final currentUserId = SessionService.currentUserId;

    if (currentUserId == null || currentUserId.isEmpty) {
      showMessage('Primero debes iniciar sesión para crear un envío.');
      return;
    }

    if ((SessionService.currentUser?.selfiePath ?? '').trim().isEmpty) {
      showMessage('Antes de publicar, sube tu selfie en Perfil.');
      return;
    }

    if (descripcion.isEmpty) {
      showMessage('Ingresa una descripción del envío.');
      return;
    }

    if (valor == null || valor <= 0) {
      showMessage('Ingresa un valor válido para el paquete.');
      return;
    }

    if (tipo == 'libra' && (peso == null || peso <= 0)) {
      showMessage('Ingresa un peso válido en libras.');
      return;
    }

    if (receptorNombre.isEmpty ||
        receptorTelefono.length < 8 ||
        receptorDireccion.isEmpty ||
        receiverRegion.isEmpty) {
      showMessage('Completa correctamente los datos del receptor.');
      return;
    }

    if (origen == destino) {
      showMessage('El origen y el destino deben ser diferentes.');
      return;
    }

    if (isForeignDestination && !acceptedForeignRestrictions) {
      showMessage('Debes confirmar la validación de productos prohibidos para envíos al extranjero.');
      return;
    }

    if (requiresVin && vin.length < 6) {
      showMessage('Ingresa un VIN válido para esta categoría.');
      return;
    }

    final restrictedMatch = _findRestrictedProduct(descripcion);
    if (restrictedMatch != null) {
      showMessage('El producto "$restrictedMatch" no se puede enviar por esta ruta.');
      return;
    }

    setState(() => loading = true);

    try {
      await _ensureSelectedSenderApplied();
      final fullAddress = _composeAddress();
      final geocoded = await addressSearchService.geocodeAddress(
        address: fullAddress,
        countryCode: _countryNameToCode[receiverCountry] ?? destino,
      );
      final pickupPosition = await locationService.getLocation();

      final resolvedAddress = geocoded?.formattedAddress ?? fullAddress;

      final shipmentDescription = requiresVin
          ? '$descripcion\nVIN: $vin'
          : descripcion;

      await _saveCurrentRecipient(notify: false);

      final shipment = ShipmentModel(
        id: '',
        userId: currentUserId,
        tipo: tipo,
        peso: peso,
        descripcion: shipmentDescription,
        valor: valor,
        origen: origen,
        destino: destino,
        receptorNombre: receptorNombre,
        receptorTelefono: receptorTelefono,
        receptorDireccion: resolvedAddress,
        pickupLat: pickupPosition?.latitude,
        pickupLng: pickupPosition?.longitude,
        deliveryLat: geocoded?.latitude,
        deliveryLng: geocoded?.longitude,
        imagenes: images.map((e) => e.path).toList(),
        seguro: seguro,
        costoSeguro: costoSeguro,
        estado: 'published',
      );

      await shipmentService.createShipment(shipment);

      if (!mounted) return;

      setState(() {
        loading = false;
        geocodedAddressLabel = geocoded?.formattedAddress;
      });

      if (geocoded == null) {
        showMessage('Envío publicado. La dirección quedó guardada sin validación automática.');
      } else {
        showMessage('Envío publicado correctamente.');
      }
      Navigator.pushNamedAndRemoveUntil(context, '/my_orders', (_) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage('No se pudo crear el envío.');
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
                  title: 'Publica un envío',
                  subtitle: 'Configura origen, destino y datos del receptor en un flujo claro y rápido.',
                ),
                const SizedBox(height: 24),
                AppGlassSection(
                  title: 'Remitente',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'El envío usará el remitente activo de tu perfil. Aquí puedes reutilizar remitentes guardados antes de publicar.',
                        style: TextStyle(color: AppTheme.muted, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      if (selectedSender != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSoft,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_pin_circle_outlined, color: AppTheme.accent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedSender!.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const Text(
                                    'Activo',
                                    style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(selectedSender!.phone, style: const TextStyle(color: AppTheme.muted)),
                              const SizedBox(height: 4),
                              Text(selectedSender!.address, style: const TextStyle(color: AppTheme.muted)),
                            ],
                          ),
                        ),
                      if (savedSenders.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 118,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: savedSenders.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final sender = savedSenders[index];
                              final isSelected = selectedSender?.name == sender.name && selectedSender?.phone == sender.phone;
                              return SizedBox(
                                width: 230,
                                child: InkWell(
                                  onTap: () => _applySenderProfile(sender),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.accent.withValues(alpha: 0.12) : AppTheme.surfaceSoft,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: isSelected ? AppTheme.accent : AppTheme.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                sender.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => _removeSavedSender(sender),
                                              child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.muted),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(sender.phone, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(sender.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                                        const Spacer(),
                                        Text(
                                          isSelected ? 'En uso' : 'Usar remitente',
                                          style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _createSenderProfile,
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: const Text('Crear remitente'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _saveCurrentSender,
                            icon: const Icon(Icons.bookmark_add_outlined),
                            label: const Text('Guardar remitente actual'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppGlassSection(
                  title: 'Detalles del paquete',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: tipo,
                        isExpanded: true,
                        menuMaxHeight: 320,
                        decoration: const InputDecoration(labelText: 'Tipo de paquete'),
                        items: availablePackageTypes
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(_shipmentTypeLabel(value)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => tipo = value);
                        },
                      ),
                      if (isUsToGtRoute) ...[
                        const SizedBox(height: 10),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Ruta USA → Guatemala habilita categorías de vehículos y maquinaria liviana.',
                            style: TextStyle(color: AppTheme.muted, fontSize: 13),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        controller: descripcionController,
                        decoration: const InputDecoration(labelText: 'Descripción'),
                        maxLines: 2,
                        textInputAction: TextInputAction.next,
                      ),
                      if (requiresVin) ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: vinController,
                          decoration: const InputDecoration(
                            labelText: 'Número de VIN',
                            hintText: 'Obligatorio para carros, motos, buses y lanchas',
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        controller: pesoController,
                        decoration: const InputDecoration(labelText: 'Peso (libras)'),
                        keyboardType: TextInputType.number,
                        enabled: tipo == 'libra',
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: valorController,
                        decoration: const InputDecoration(labelText: 'Valor declarado'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => calcularSeguro(),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSoft,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Seguro del envío',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    seguro
                                        ? 'Cobertura activa por Q$costoSeguro'
                                        : 'Protege el paquete por Q$costoSeguro',
                                    style: const TextStyle(
                                      color: AppTheme.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: seguro,
                              onChanged: (value) => setState(() => seguro = value),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppGlassSection(
                  title: 'Ruta',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: origen,
                        isExpanded: true,
                        menuMaxHeight: 280,
                        decoration: const InputDecoration(labelText: 'Origen'),
                        items: const [
                          DropdownMenuItem(value: 'GT', child: Text('Guatemala')),
                          DropdownMenuItem(value: 'US', child: Text('Estados Unidos')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          _syncRouteState(nextOrigin: value);
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: destino,
                        isExpanded: true,
                        menuMaxHeight: 280,
                        decoration: const InputDecoration(labelText: 'Destino'),
                        items: const [
                          DropdownMenuItem(value: 'US', child: Text('Estados Unidos')),
                          DropdownMenuItem(value: 'GT', child: Text('Guatemala')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          _syncRouteState(nextDestination: value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppGlassSection(
                  title: 'Fotos de referencia',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: addImage,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Agregar foto'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.border),
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      if (images.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: images.map((img) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                img,
                                height: 90,
                                width: 90,
                                fit: BoxFit.cover,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppGlassSection(
                  title: 'Datos del receptor',
                  child: Column(
                    children: [
                      if (savedRecipients.isNotEmpty) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Destinatarios guardados',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 112,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: savedRecipients.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final recipient = savedRecipients[index];
                              return SizedBox(
                                width: 230,
                                child: InkWell(
                                  onTap: () => _applySavedRecipient(recipient),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceSoft,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                recipient.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => _removeSavedRecipient(recipient),
                                              child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.muted),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${recipient.region}, ${recipient.country}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          recipient.phone,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                        ),
                                        const Spacer(),
                                        const Text(
                                          'Tocar para autollenar',
                                          style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextField(
                        controller: receptorNombreController,
                        decoration: const InputDecoration(labelText: 'Nombre receptor'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: receptorTelefonoController,
                        decoration: const InputDecoration(labelText: 'Teléfono receptor'),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: receiverCountry,
                        isExpanded: true,
                        menuMaxHeight: 280,
                        decoration: const InputDecoration(labelText: 'País del receptor'),
                        items: supportedCountries
                            .map(
                              (country) => DropdownMenuItem(
                                value: country,
                                child: Text(country),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          final nextCode = _countryNameToCode[value] ?? destino;
                          _syncRouteState(nextDestination: nextCode);
                        },
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: pickReceiverRegion,
                        borderRadius: BorderRadius.circular(18),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Departamento / Estado',
                            suffixIcon: Icon(Icons.expand_more_rounded),
                          ),
                          child: Text(receiverRegion.isNotEmpty ? receiverRegion : 'Seleccionar'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: receptorDireccionController,
                        decoration: InputDecoration(
                          labelText: isForeignDestination
                              ? 'Dirección del receptor en USA'
                              : 'Dirección del receptor',
                          hintText: isForeignDestination
                              ? 'Empieza a escribir calle, ciudad, estado o ZIP code'
                              : 'Ej. Manzana F lote 11, zona 6',
                          suffixIcon: loadingAddressSuggestions
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : null,
                        ),
                        maxLines: 2,
                        textInputAction: TextInputAction.done,
                        onChanged: (value) {
                          if (geocodedAddressLabel != null) {
                            setState(() => geocodedAddressLabel = null);
                          }
                          _loadAddressSuggestions(value);
                        },
                      ),
                      if (addressSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 220,
                          child: ListView.separated(
                            itemCount: addressSuggestions.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final suggestion = addressSuggestions[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.location_on_outlined),
                                title: Text(suggestion.description),
                                onTap: () => _selectAddressSuggestion(suggestion),
                              );
                            },
                          ),
                        ),
                      ],
                      if (geocodedAddressLabel != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Dirección validada: $geocodedAddressLabel',
                            style: const TextStyle(color: AppTheme.accent, fontSize: 13),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: _saveCurrentRecipient,
                          icon: const Icon(Icons.bookmark_add_outlined),
                          label: const Text('Guardar destinatario'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isForeignDestination) ...[
                  const SizedBox(height: 16),
                  AppGlassSection(
                    title: 'Validación de productos prohibidos',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Si el destino es Estados Unidos, recuerda que no puedes enviar armas, municiones, explosivos, drogas, vapeadores, alcohol, dinero en efectivo, animales vivos ni químicos peligrosos.',
                          style: TextStyle(color: AppTheme.muted, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: acceptedForeignRestrictions,
                          onChanged: (value) {
                            setState(() {
                              acceptedForeignRestrictions = value ?? false;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Entiendo las restricciones para envíos al extranjero'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: loading ? null : createShipment,
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Publicar envío'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
