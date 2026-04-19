import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/data/location_catalogs.dart';
import 'package:iway_app/features/shipment/models/shipment_model.dart';
import 'package:iway_app/features/shipment/services/address_search_service.dart';
import 'package:iway_app/features/shipment/services/saved_recipient_service.dart';
import 'package:iway_app/features/shipment/services/shipment_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';

class CreateShipmentScreen extends StatefulWidget {
  const CreateShipmentScreen({super.key});

  @override
  State<CreateShipmentScreen> createState() => _CreateShipmentScreenState();
}

class _CreateShipmentScreenState extends State<CreateShipmentScreen> {
  final _shipmentService = ShipmentService();
  final _recipientService = SavedRecipientService();
  final _addressSearchService = AddressSearchService();

  final _descriptionController = TextEditingController();
  final _weightController = TextEditingController();
  final _valueController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _originAddressController = TextEditingController();

  final List<AddressSuggestion> _addressSuggestions = [];
  final List<AddressSuggestion> _originAddressSuggestions = [];
  Timer? _debounce;
  Timer? _originDebounce;

  int _step = 0;
  bool _insuranceEnabled = false;
  bool _acceptDeclaration = false;
  bool _submitting = false;
  String _category = 'libra';
  String _direction = 'gt_to_us';
  String _selectedUsState = usStatesCatalog.first.name;
  String _selectedUsCity = usStatesCatalog.first.cities.first;
  String _selectedGtDepartment = guatemalaDepartments.first.name;
  String _selectedGtMunicipality = guatemalaDepartments.first.municipalities.first;
  String _selectedGtZone = '';
  List<SavedRecipient> _savedRecipients = [];
  SavedRecipient? _selectedRecipient;
  double? _pickupLat;
  double? _pickupLng;
  double? _deliveryLat;
  double? _deliveryLng;

  @override
  void initState() {
    super.initState();
    _loadRecipients();
    _addressController.addListener(_onAddressChanged);
    _originAddressController.addListener(_onOriginAddressChanged);
  }

  Future<void> _loadRecipients() async {
    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty) return;
    final recipients = await _recipientService.getAll(userId);
    if (!mounted) return;
    setState(() => _savedRecipients = recipients);
  }

  void _onAddressChanged() {
    if (_direction != 'gt_to_us') {
      if (!mounted) return;
      setState(() => _addressSuggestions.clear());
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final text = _addressController.text.trim();
      if (text.length < 3) {
        if (!mounted) return;
        setState(() => _addressSuggestions.clear());
        return;
      }

      final suggestions = await _addressSearchService.autocompleteAddresses(
        input: text,
        countryCode: 'US',
      );

      if (!mounted) return;
      setState(() {
        _addressSuggestions
          ..clear()
          ..addAll(suggestions);
      });
    });
  }

  void _onOriginAddressChanged() {
    if (_direction != 'us_to_gt') {
      if (!mounted) return;
      setState(() => _originAddressSuggestions.clear());
      return;
    }

    _originDebounce?.cancel();
    _originDebounce = Timer(const Duration(milliseconds: 350), () async {
      final text = _originAddressController.text.trim();
      if (text.length < 3) {
        if (!mounted) return;
        setState(() => _originAddressSuggestions.clear());
        return;
      }

      final suggestions = await _addressSearchService.autocompleteAddresses(
        input: text,
        countryCode: 'US',
      );

      if (!mounted) return;
      setState(() {
        _originAddressSuggestions
          ..clear()
          ..addAll(suggestions);
      });
    });
  }

  void _applyRecipient(SavedRecipient recipient) {
    setState(() {
      _selectedRecipient = recipient;
      _recipientNameController.text = recipient.name;
      _recipientPhoneController.text = recipient.phone;
      _addressController.text = recipient.address;
      if (_direction == 'gt_to_us') {
        _selectedUsState = recipient.region;
        _selectedUsCity = recipient.city;
      } else {
        _selectedGtDepartment = recipient.region;
        final municipalities = municipalitiesForDepartment(_selectedGtDepartment);
        _selectedGtMunicipality = municipalities.contains(recipient.city)
            ? recipient.city
            : municipalities.first;
        final zones = zonesForDepartment(_selectedGtDepartment);
        _selectedGtZone = zones.isNotEmpty ? zones.first : '';
      }
      _addressSuggestions.clear();
    });
  }

  Future<void> _saveRecipient() async {
    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty) return;

    final recipient = SavedRecipient(
      name: _recipientNameController.text.trim(),
      phone: _recipientPhoneController.text.trim(),
      address: _addressController.text.trim(),
      country: _direction == 'gt_to_us' ? 'Estados Unidos' : 'Guatemala',
      region: _direction == 'gt_to_us' ? _selectedUsState : _selectedGtDepartment,
      city: _direction == 'gt_to_us' ? _selectedUsCity : _selectedGtMunicipality,
    );

    if (recipient.name.isEmpty || recipient.phone.isEmpty || recipient.address.isEmpty) {
      _showMessage('Completa los datos del destinatario antes de guardarlo.');
      return;
    }

    await _recipientService.save(userId, recipient);
    await _loadRecipients();
    if (!mounted) return;
    setState(() => _selectedRecipient = recipient);
    _showMessage('Destinatario guardado.');
  }

  Future<void> _pickAddress(AddressSuggestion suggestion, {required bool isOrigin}) async {
    final geocoded = await _addressSearchService.geocodeAddress(address: suggestion.description, countryCode: 'US');
    if (!mounted) return;
    setState(() {
      if (isOrigin) {
        _originAddressController.text = geocoded?.formattedAddress ?? suggestion.description;
        _pickupLat = geocoded?.latitude;
        _pickupLng = geocoded?.longitude;
        _originAddressSuggestions.clear();
      } else {
        _addressController.text = geocoded?.formattedAddress ?? suggestion.description;
        _deliveryLat = geocoded?.latitude;
        _deliveryLng = geocoded?.longitude;
        _addressSuggestions.clear();
      }
    });
  }

  bool _validateRecipientName(String value) {
    return RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ ]+$').hasMatch(value.trim());
  }

  bool _validateCurrentStep() {
    switch (_step) {
      case 0:
        if (_category != 'documentos') {
          final weight = double.tryParse(_weightController.text.trim());
          if (weight == null || weight <= 0) {
            _showMessage('Ingresa la cantidad de libras.');
            return false;
          }
        }
        if (_descriptionController.text.trim().isEmpty) {
          _showMessage('Agrega una descripción clara del envío.');
          return false;
        }
        return true;
      case 1:
        final value = double.tryParse(_valueController.text.trim());
        if (value == null || value <= 0) {
          _showMessage('Ingresa cuánto vale lo que envías.');
          return false;
        }
        return true;
      case 2:
        if (!_validateRecipientName(_recipientNameController.text)) {
          _showMessage('El nombre del destinatario debe llevar letras y espacios.');
          return false;
        }
        if (_recipientPhoneController.text.trim().isEmpty) {
          _showMessage('Completa el teléfono del destinatario.');
          return false;
        }
        if (_direction == 'gt_to_us') {
          if (_addressController.text.trim().isEmpty) {
            _showMessage('Completa la dirección de entrega en USA.');
            return false;
          }
        } else {
          if (_originAddressController.text.trim().isEmpty || _addressController.text.trim().isEmpty) {
            _showMessage('Completa el origen en USA y el destino en Guatemala.');
            return false;
          }
        }
        return true;
      default:
        if (!_acceptDeclaration) {
          _showMessage('Debes aceptar la declaración para publicar el envío.');
          return false;
        }
        return true;
    }
  }

  Future<void> _handlePublish() async {
    if (!_validateCurrentStep()) return;
    final user = SessionService.currentUser;
    final userId = SessionService.currentUserId;
    if (user == null || userId == null || userId.isEmpty) return;

    setState(() => _submitting = true);

    try {
      final receiverAddress = _direction == 'gt_to_us'
          ? '$_selectedUsCity, $_selectedUsState • ${_addressController.text.trim()}'
          : [
              _selectedGtMunicipality,
              _selectedGtDepartment,
              if (_selectedGtZone.isNotEmpty) _selectedGtZone,
              _addressController.text.trim(),
            ].join(' • ');

      final shipment = ShipmentModel(
        id: '',
        userId: userId,
        tipo: _category,
        peso: _category == 'documentos' ? null : double.tryParse(_weightController.text.trim()),
        descripcion: _descriptionController.text.trim(),
        valor: double.parse(_valueController.text.trim()),
        origen: _direction == 'gt_to_us' ? 'GT' : 'US',
        destino: _direction == 'gt_to_us' ? 'US' : 'GT',
        remitenteNombre: user.nombre,
        remitenteTelefono: user.telefono,
        remitenteDireccion: _direction == 'gt_to_us' ? user.direccion : _originAddressController.text.trim(),
        remitenteRegion: _direction == 'gt_to_us' ? user.estado : _selectedUsState,
        receptorNombre: _recipientNameController.text.trim(),
        receptorTelefono: _recipientPhoneController.text.trim(),
        receptorDireccion: receiverAddress,
        imagenes: const [],
        seguro: _insuranceEnabled,
        costoSeguro: _insuranceEnabled ? 15 : 0,
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
        deliveryLat: _deliveryLat,
        deliveryLng: _deliveryLng,
        estado: 'pending',
      );

      final created = await _shipmentService.createShipment(shipment);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/searching_traveler',
        (route) => route.settings.name == '/home',
        arguments: created.id,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message == 'Internal server error' ? 'No se pudo publicar el envío. Revisa los datos e intenta de nuevo.' : e.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('No se pudo publicar el envío.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handlePrimaryAction(int totalSteps) async {
    if (_step == totalSteps - 1) {
      await _handlePublish();
      return;
    }

    if (!_validateCurrentStep()) return;
    if (!mounted) return;
    setState(() => _step += 1);
  }

  void _showMessage(String message) {
    if (message.trim() == 'Debes validar tu número de teléfono antes de crear un envío.') {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _stepCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: AppTheme.muted, height: 1.4)),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildCategoryStep() {
    return _stepCard(
      title: 'Paso 1. Ruta y tipo de envío',
      subtitle: 'Elige el sentido del trayecto antes de describir el paquete.',
      child: Column(
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'gt_to_us', label: Text('GT a USA')),
              ButtonSegment(value: 'us_to_gt', label: Text('USA a GT')),
            ],
            selected: {_direction},
            onSelectionChanged: (selection) => setState(() => _direction = selection.first),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'libra', label: Text('Libra')),
              ButtonSegment(value: 'documentos', label: Text('Documentos')),
              ButtonSegment(value: 'medicina', label: Text('Medicina')),
            ],
            selected: {_category},
            onSelectionChanged: (selection) => setState(() => _category = selection.first),
          ),
          const SizedBox(height: 16),
          TextField(controller: _descriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Describe lo que envías')),
          if (_category != 'documentos') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Cantidad de libras'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildValueStep() {
    return _stepCard(
      title: 'Paso 2. Valoración',
      subtitle: 'Declara el valor real y decide si quieres cobertura.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '¿Cuánto vale lo que envías?'),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Text('Costo: Q15.00 | Cobertura: Hasta Q500.00 por pérdida/robo', style: TextStyle(height: 1.4)),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _insuranceEnabled,
            onChanged: (value) => setState(() => _insuranceEnabled = value),
            title: const Text('Agregar seguro opcional'),
            subtitle: const Text('Se suma solo cuando deseas cobertura adicional.'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientStep() {
    final destinationIsUs = _direction == 'gt_to_us';
    final gtMunicipalities = municipalitiesForDepartment(_selectedGtDepartment);
    final gtZones = zonesForDepartment(_selectedGtDepartment);

    return _stepCard(
      title: 'Paso 3. Origen, destino y destinatario',
      subtitle: destinationIsUs
          ? 'Sales desde Guatemala y entregas en USA.'
          : 'Sales desde USA con Google Places y entregas en Guatemala.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_savedRecipients.isNotEmpty) ...[
            const Text('Destinatarios guardados', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _savedRecipients.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final recipient = _savedRecipients[index];
                  final selected = _selectedRecipient == recipient;
                  return InkWell(
                    onTap: () => _applyRecipient(recipient),
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.accent.withValues(alpha: 0.14) : AppTheme.surfaceSoft,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: selected ? AppTheme.accent : AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(recipient.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text('${recipient.city}, ${recipient.region}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!destinationIsUs) ...[
            TextField(controller: _originAddressController, decoration: const InputDecoration(labelText: 'Origen en USA con Google Places')),
            if (_originAddressSuggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: _originAddressSuggestions.map((suggestion) {
                    return ListTile(
                      title: Text(suggestion.description),
                      onTap: () => _pickAddress(suggestion, isOrigin: true),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedUsState,
              decoration: const InputDecoration(labelText: 'Estado de origen en USA'),
              items: usStatesCatalog.map((state) => DropdownMenuItem(value: state.name, child: Text(state.name))).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedUsState = value;
                  _selectedUsCity = citiesForUsState(value).first;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedUsCity,
              decoration: const InputDecoration(labelText: 'Ciudad de origen en USA'),
              items: citiesForUsState(_selectedUsState).map((city) => DropdownMenuItem(value: city, child: Text(city))).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedUsCity = value);
              },
            ),
            const SizedBox(height: 16),
          ],
          TextField(controller: _recipientNameController, decoration: const InputDecoration(labelText: 'Nombre del destinatario')),
          const SizedBox(height: 12),
          TextField(
            controller: _recipientPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: destinationIsUs ? 'Teléfono USA' : 'Teléfono en Guatemala'),
          ),
          const SizedBox(height: 12),
          if (destinationIsUs) ...[
            DropdownButtonFormField<String>(
              value: _selectedUsState,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: usStatesCatalog.map((state) => DropdownMenuItem(value: state.name, child: Text(state.name))).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedUsState = value;
                  _selectedUsCity = citiesForUsState(value).first;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedUsCity,
              decoration: const InputDecoration(labelText: 'Ciudad'),
              items: citiesForUsState(_selectedUsState).map((city) => DropdownMenuItem(value: city, child: Text(city))).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedUsCity = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Dirección con Google Places')),
            if (_addressSuggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: _addressSuggestions.map((suggestion) {
                    return ListTile(
                      title: Text(suggestion.description),
                      onTap: () => _pickAddress(suggestion, isOrigin: false),
                    );
                  }).toList(),
                ),
              ),
            ],
          ] else ...[
            DropdownButtonFormField<String>(
              value: _selectedGtDepartment,
              decoration: const InputDecoration(labelText: 'Departamento en Guatemala'),
              items: guatemalaDepartments.map((item) => DropdownMenuItem(value: item.name, child: Text(item.name))).toList(),
              onChanged: (value) {
                if (value == null) return;
                final municipalities = municipalitiesForDepartment(value);
                final zones = zonesForDepartment(value);
                setState(() {
                  _selectedGtDepartment = value;
                  _selectedGtMunicipality = municipalities.first;
                  _selectedGtZone = zones.isNotEmpty ? zones.first : '';
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedGtMunicipality,
              decoration: const InputDecoration(labelText: 'Municipio'),
              items: gtMunicipalities.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedGtMunicipality = value);
              },
            ),
            if (gtZones.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedGtZone,
                decoration: const InputDecoration(labelText: 'Zona'),
                items: gtZones.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedGtZone = value);
                },
              ),
            ],
            const SizedBox(height: 12),
            TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Dirección exacta de entrega en Guatemala')),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saveRecipient,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar destinatario'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeclarationStep() {
    final enteringGuatemala = _direction == 'us_to_gt';
    return _stepCard(
      title: 'Paso 4. Declaración',
      subtitle: enteringGuatemala
          ? 'Aplica control de ingreso a Guatemala y validación aduanera SAT.'
          : 'Cierre legal simple antes de publicar tu envío.',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _acceptDeclaration,
          onChanged: (value) => setState(() => _acceptDeclaration = value ?? false),
          title: Text(
            enteringGuatemala
                ? 'Declaro que este envío cumple con requisitos de ingreso a Guatemala y no contiene mercancía prohibida ante SAT.'
                : 'Declaro que no envío productos prohibidos ni contenido oculto.',
          ),
          subtitle: Text(
            enteringGuatemala
                ? 'Acepto que i-WAY y la autoridad aduanera pueden retener, inspeccionar o rechazar el paquete si incumple normas de ingreso al país.'
                : 'Acepto que i-WAY puede rechazar, retener o reportar envíos que incumplan la política.',
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _originDebounce?.cancel();
    _descriptionController.dispose();
    _weightController.dispose();
    _valueController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _addressController.dispose();
    _originAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _buildCategoryStep(),
      _buildValueStep(),
      _buildRecipientStep(),
      _buildDeclarationStep(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Crear envío')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          Row(
            children: List.generate(
              steps.length,
              (index) => Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: index == steps.length - 1 ? 0 : 8),
                  decoration: BoxDecoration(
                    color: index <= _step ? AppTheme.accent : AppTheme.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          steps[_step],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step -= 1),
                  child: const Text('Atrás'),
                ),
              ),
            if (_step > 0) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _submitting
                    ? null
                    : () {
                        if (_step == steps.length - 1) {
                          _handlePublish();
                          return;
                        }
                        _handlePrimaryAction(steps.length);
                      },
                child: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_step == steps.length - 1 ? 'Publicar envío' : 'Continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
