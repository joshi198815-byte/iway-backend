import 'dart:io';

import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/services/image_service.dart';
import 'package:iway_app/features/auth/services/location_service.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/insurance_service.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/services/upload_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class CreateShipmentScreen extends StatefulWidget {
  const CreateShipmentScreen({super.key});

  @override
  State<CreateShipmentScreen> createState() => _CreateShipmentScreenState();
}

class _CreateShipmentScreenState extends State<CreateShipmentScreen> {
  final descripcionController = TextEditingController();
  final valorController = TextEditingController();
  final pesoController = TextEditingController();
  final receptorNombreController = TextEditingController();
  final receptorTelefonoController = TextEditingController();
  final receptorDireccionController = TextEditingController();
  final deliveryLatController = TextEditingController();
  final deliveryLngController = TextEditingController();

  final shipmentService = ShipmentService();
  final imageService = ImageService();
  final insuranceService = InsuranceService();
  final locationService = LocationService();
  final uploadService = UploadService();

  List<File> images = [];
  String tipo = 'libra';
  String origen = 'GT';
  String destino = 'US';
  bool seguro = false;
  double costoSeguro = 0;
  bool loading = false;
  bool loadingPickup = false;
  double? pickupLat;
  double? pickupLng;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    loadPickupLocation();
  }

  Future<void> loadPickupLocation() async {
    setState(() => loadingPickup = true);
    final position = await locationService.getLocation();
    if (!mounted) return;
    setState(() {
      pickupLat = position?.latitude;
      pickupLng = position?.longitude;
      loadingPickup = false;
    });
  }

  @override
  void dispose() {
    descripcionController.dispose();
    valorController.dispose();
    pesoController.dispose();
    receptorNombreController.dispose();
    receptorTelefonoController.dispose();
    receptorDireccionController.dispose();
    deliveryLatController.dispose();
    deliveryLngController.dispose();
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

  Future<void> createShipment() async {
    final descripcion = descripcionController.text.trim();
    final valor = double.tryParse(valorController.text.trim());
    final peso = double.tryParse(pesoController.text.trim());
    final receptorNombre = receptorNombreController.text.trim();
    final receptorTelefono = receptorTelefonoController.text.trim();
    final receptorDireccion = receptorDireccionController.text.trim();
    final deliveryLat = double.tryParse(deliveryLatController.text.trim());
    final deliveryLng = double.tryParse(deliveryLngController.text.trim());
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
        receptorDireccion.isEmpty) {
      showMessage('Completa correctamente los datos del receptor.');
      return;
    }

    if (origen == destino) {
      showMessage('El origen y el destino deben ser diferentes.');
      return;
    }

    if (pickupLat == null || pickupLng == null) {
      showMessage('Activa tu ubicación para guardar el punto de origen del envío.');
      return;
    }

    if (deliveryLat == null || deliveryLng == null) {
      showMessage('Ingresa coordenadas válidas de entrega para poder trazar la ruta.');
      return;
    }

    setState(() => loading = true);

    try {
      final uploadedImageUrls = <String>[];
      for (var i = 0; i < images.length; i++) {
        final imageUrl = await uploadService.uploadImage(
          file: images[i],
          bucket: 'shipment-images',
          fileName: 'shipment-${DateTime.now().millisecondsSinceEpoch}-$i',
        );
        uploadedImageUrls.add(imageUrl);
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
        receptorDireccion: receptorDireccion,
        imagenes: uploadedImageUrls,
        seguro: seguro,
        costoSeguro: costoSeguro,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
        estado: 'pending',
      );

      final createdShipment = await shipmentService.createShipment(shipment);

      if (!mounted) return;

      setState(() => loading = false);
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
                        initialValue: tipo,
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
                        textInputAction: TextInputAction.next,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: pesoController,
                        decoration: const InputDecoration(labelText: 'Peso (libras)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                        enabled: tipo == 'libra',
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
                        initialValue: destino,
                        decoration: const InputDecoration(labelText: 'Destino'),
                        items: const [
                          DropdownMenuItem(value: 'US', child: Text('Estados Unidos')),
                          DropdownMenuItem(value: 'GT', child: Text('Guatemala')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => destino = value);
                        },
                      ),
                      const SizedBox(height: 14),
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
                            const Text(
                              'Punto de origen del envío',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              loadingPickup
                                  ? 'Detectando tu ubicación actual...'
                                  : pickupLat != null && pickupLng != null
                                      ? 'Origen listo: ${pickupLat!.toStringAsFixed(5)}, ${pickupLng!.toStringAsFixed(5)}'
                                      : 'No pudimos detectar tu ubicación todavía.',
                              style: const TextStyle(color: AppTheme.muted, height: 1.35),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: loadingPickup ? null : loadPickupLocation,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: AppTheme.border),
                                minimumSize: const Size(double.infinity, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(loadingPickup ? 'Actualizando ubicación...' : 'Usar mi ubicación actual'),
                            ),
                          ],
                        ),
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
                      const SizedBox(height: 10),
                      Text(
                        images.isEmpty
                            ? 'Agregar fotos ayuda a que los viajeros evalúen mejor el envío.'
                            : '${images.length} foto(s) listas para subir y mostrar en el envío.',
                        style: const TextStyle(color: AppTheme.muted, fontSize: 13),
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
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: receptorTelefonoController,
                        decoration: const InputDecoration(labelText: 'Teléfono receptor'),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: receptorDireccionController,
                        decoration: const InputDecoration(labelText: 'Dirección receptor'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: deliveryLatController,
                        decoration: const InputDecoration(labelText: 'Latitud entrega'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: deliveryLngController,
                        decoration: const InputDecoration(labelText: 'Longitud entrega'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Estas coordenadas permiten dibujar la ruta del envío en el mapa.',
                        style: TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.35),
                      ),
                    ],
                  ),
                ),
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
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    loading
                        ? 'Subiendo imágenes y publicando el envío para preparar la vista de ofertas...'
                        : 'Cuando lo publiques, los viajeros podrán enviarte ofertas de inmediato.',
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
}
