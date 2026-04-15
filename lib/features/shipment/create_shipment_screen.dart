import 'dart:io';

import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/data/location_catalogs.dart';
import 'package:iway_app/features/auth/services/image_service.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/address_search_service.dart';
import 'package:iway_app/features/shipment/services/insurance_service.dart';
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

  final descripcionController = TextEditingController();
  final valorController = TextEditingController();
  final pesoController = TextEditingController();
  final receptorNombreController = TextEditingController();
  final receptorTelefonoController = TextEditingController();
  final receptorDireccionController = TextEditingController();

  final shipmentService = ShipmentService();
  final imageService = ImageService();
  final insuranceService = InsuranceService();
  final addressSearchService = AddressSearchService();

  List<File> images = [];
  String tipo = 'libra';
  String origen = 'GT';
  String destino = 'US';
  String receiverCountry = 'Estados Unidos';
  String receiverRegion = supportedRegionsByCountry['Estados Unidos']!.first;
  bool seguro = false;
  bool loading = false;
  bool acceptedForeignRestrictions = false;
  double costoSeguro = 0;
  String? geocodedAddressLabel;

  bool get isForeignDestination => destino == 'US';

  List<String> get availableRegions =>
      supportedRegionsByCountry[receiverCountry] ?? const [];

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    descripcionController.dispose();
    valorController.dispose();
    pesoController.dispose();
    receptorNombreController.dispose();
    receptorTelefonoController.dispose();
    receptorDireccionController.dispose();
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

  void _syncReceiverCountryWithDestination(String countryCode) {
    final nextCountry = countryCode == 'GT' ? 'Guatemala' : 'Estados Unidos';
    final nextRegions = supportedRegionsByCountry[nextCountry] ?? const [];

    setState(() {
      destino = countryCode;
      receiverCountry = nextCountry;
      receiverRegion = nextRegions.isNotEmpty ? nextRegions.first : '';
      acceptedForeignRestrictions = !isForeignDestination;
      geocodedAddressLabel = null;
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

  Future<void> createShipment() async {
    final descripcion = descripcionController.text.trim();
    final valor = double.tryParse(valorController.text.trim());
    final peso = double.tryParse(pesoController.text.trim());
    final receptorNombre = receptorNombreController.text.trim();
    final receptorTelefono = receptorTelefonoController.text.trim();
    final receptorDireccion = receptorDireccionController.text.trim();
    final currentUserId = SessionService.currentUserId;

    if (currentUserId == null || currentUserId.isEmpty) {
      showMessage('Primero debes iniciar sesión para crear un envío.');
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

    final restrictedMatch = _findRestrictedProduct(descripcion);
    if (restrictedMatch != null) {
      showMessage('El producto "$restrictedMatch" no se puede enviar por esta ruta.');
      return;
    }

    setState(() => loading = true);

    try {
      final fullAddress = _composeAddress();
      final geocoded = await addressSearchService.geocodeAddress(
        address: fullAddress,
        countryCode: _countryNameToCode[receiverCountry] ?? destino,
      );

      if (geocoded == null) {
        setState(() => loading = false);
        showMessage('No pude validar la dirección. Intenta con una dirección más completa.');
        return;
      }

      final shipment = ShipmentModel(
        id: '',
        userId: currentUserId,
        tipo: tipo,
        peso: peso,
        descripcion: descripcion,
        valor: valor,
        origen: origen,
        destino: destino,
        receptorNombre: receptorNombre,
        receptorTelefono: receptorTelefono,
        receptorDireccion: geocoded.formattedAddress,
        deliveryLat: geocoded.latitude,
        deliveryLng: geocoded.longitude,
        imagenes: images.map((e) => e.path).toList(),
        seguro: seguro,
        costoSeguro: costoSeguro,
        estado: 'pending',
      );

      final createdShipment = await shipmentService.createShipment(shipment);

      if (!mounted) return;

      setState(() {
        loading = false;
        geocodedAddressLabel = geocoded.formattedAddress;
      });
      Navigator.pushNamed(context, '/offers', arguments: createdShipment.id);
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
                  title: 'Detalles del paquete',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: tipo,
                        decoration: const InputDecoration(labelText: 'Tipo de paquete'),
                        items: const [
                          DropdownMenuItem(value: 'libra', child: Text('Por libra')),
                          DropdownMenuItem(value: 'carga', child: Text('Carga grande')),
                          DropdownMenuItem(value: 'documento', child: Text('Documentos')),
                          DropdownMenuItem(value: 'medicina', child: Text('Medicina')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => tipo = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descripcionController,
                        decoration: const InputDecoration(labelText: 'Descripción'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: pesoController,
                        decoration: const InputDecoration(labelText: 'Peso (libras)'),
                        keyboardType: TextInputType.number,
                        enabled: tipo == 'libra',
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: valorController,
                        decoration: const InputDecoration(labelText: 'Valor declarado'),
                        keyboardType: TextInputType.number,
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
                        value: origen,
                        decoration: const InputDecoration(labelText: 'Origen'),
                        items: const [
                          DropdownMenuItem(value: 'GT', child: Text('Guatemala')),
                          DropdownMenuItem(value: 'US', child: Text('Estados Unidos')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => origen = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: destino,
                        decoration: const InputDecoration(labelText: 'Destino'),
                        items: const [
                          DropdownMenuItem(value: 'US', child: Text('Estados Unidos')),
                          DropdownMenuItem(value: 'GT', child: Text('Guatemala')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          _syncReceiverCountryWithDestination(value);
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
                      TextField(
                        controller: receptorNombreController,
                        decoration: const InputDecoration(labelText: 'Nombre receptor'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: receptorTelefonoController,
                        decoration: const InputDecoration(labelText: 'Teléfono receptor'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: receiverCountry,
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
                          final nextRegions = supportedRegionsByCountry[value] ?? const [];
                          setState(() {
                            receiverCountry = value;
                            receiverRegion = nextRegions.isNotEmpty ? nextRegions.first : '';
                            destino = _countryNameToCode[value] ?? destino;
                            acceptedForeignRestrictions = destino != 'US';
                            geocodedAddressLabel = null;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: receiverRegion.isNotEmpty ? receiverRegion : null,
                        decoration: const InputDecoration(labelText: 'Departamento / Estado'),
                        items: availableRegions
                            .map(
                              (region) => DropdownMenuItem(
                                value: region,
                                child: Text(region),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            receiverRegion = value;
                            geocodedAddressLabel = null;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: receptorDireccionController,
                        decoration: const InputDecoration(
                          labelText: 'Buscar dirección del receptor',
                          hintText: 'Ej. Manzana F lote 11, zona 6',
                        ),
                        maxLines: 2,
                        onChanged: (_) {
                          if (geocodedAddressLabel != null) {
                            setState(() => geocodedAddressLabel = null);
                          }
                        },
                      ),
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
