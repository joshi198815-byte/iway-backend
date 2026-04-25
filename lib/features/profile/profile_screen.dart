import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/data/location_catalogs.dart';
import 'package:iway_app/features/auth/services/auth_service.dart';
import 'package:iway_app/features/rating/models/rating_model.dart';
import 'package:iway_app/features/rating/services/rating_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';
import 'package:iway_app/services/storage_upload_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _ratingService = RatingService();
  final _storageUploadService = StorageUploadService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _photoUrl;
  double _ratingAvg = 0;
  int _ratingCount = 0;
  List<RatingModel> _ratings = [];
  String _selectedCountry = 'Guatemala';
  String? _selectedRegion;
  String? _selectedCity;
  String? _selectedZone;
  bool get _isTraveler => SessionService.currentUser?.tipo == 'traveler';

  @override
  void initState() {
    super.initState();
    final user = SessionService.currentUser;
    _nameController.text = user?.nombre ?? '';
    _phoneController.text = user?.telefono ?? '';
    _addressController.text = user?.direccion ?? '';
    _photoUrl = user?.selfieUrl;
    _hydrateLocation(user?.pais ?? 'GT', user?.estado ?? 'Guatemala');
    _loadRatings();
  }

  void _hydrateLocation(String countryCode, String regionRaw) {
    _selectedCountry = countryCode == 'US' ? 'Estados Unidos' : 'Guatemala';
    final chunks = regionRaw
        .split('|')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final regions = availableRegionsForCountry(_selectedCountry);
    _selectedRegion = regions.contains(chunks.isNotEmpty ? chunks.first : '')
        ? chunks.first
        : regions.firstOrNull;
    if (_selectedCountry == 'Guatemala') {
      final municipalities = municipalitiesForDepartment(_selectedRegion ?? '');
      _selectedCity = municipalities.contains(chunks.length > 1 ? chunks[1] : '')
          ? chunks[1]
          : municipalities.firstOrNull;
      final zones = zonesForDepartment(_selectedRegion ?? '');
      _selectedZone = zones.contains(chunks.length > 2 ? chunks[2] : '') ? chunks[2] : null;
    } else {
      final cities = citiesForUsState(_selectedRegion ?? '');
      _selectedCity = cities.contains(chunks.length > 1 ? chunks[1] : '') ? chunks[1] : cities.firstOrNull;
      _selectedZone = null;
    }
  }

  Future<void> _loadRatings() async {
    final userId = SessionService.currentUserId;
    if (userId == null || userId.isEmpty) return;
    try {
      final ratings = await _ratingService.getRatings(userId);
      if (!mounted) return;
      final avg = ratings.isEmpty
          ? 0
          : ratings.map((e) => e.estrellas).reduce((a, b) => a + b) / ratings.length;
      setState(() {
        _ratingAvg = avg.toDouble();
        _ratingCount = ratings.length;
        _ratings = ratings;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String _resolveImageUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) return value;

    final base = ApiClient.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final normalizedPath = value.startsWith('/api/') ? value.substring(4) : value;
    return normalizedPath.startsWith('/') ? '$base$normalizedPath' : '$base/$normalizedPath';
  }

  Future<void> _pickProfilePhoto(ImageSource source) async {
    setState(() => _uploadingPhoto = true);
    try {
      final result = await _storageUploadService.pickAndUploadProfilePhoto(source: source);
      if (!mounted) return;
      final uploadedUrl = result?['publicUrl']?.toString().trim();
      final fallbackUrl = result?['url']?.toString().trim();
      setState(() => _photoUrl = (uploadedUrl?.isNotEmpty == true ? uploadedUrl : fallbackUrl));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = SessionService.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await _authService.updateProfile(
        fullName: _nameController.text,
        phone: _phoneController.text,
        countryCode: _selectedCountry == 'Estados Unidos' ? 'US' : 'GT',
        stateRegion: [
          _selectedRegion,
          _selectedCity,
          if ((_selectedZone ?? '').isNotEmpty) _selectedZone,
        ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' | '),
        address: _addressController.text,
        selfieUrl: _photoUrl,
      );
      await _authService.refreshCurrentUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo guardar el perfil.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Eliminar cuenta'),
        content: const Text('Esta acción cerrará tu sesión y eliminará tu acceso actual. ¿Deseas continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await _authService.deleteMyAccount();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo eliminar la cuenta.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('No hay sesión activa.')));
    }

    final photoUrl = _photoUrl;
    final cityOptions = _selectedCountry == 'Guatemala'
        ? municipalitiesForDepartment(_selectedRegion ?? '')
        : citiesForUsState(_selectedRegion ?? '');

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
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                const SizedBox(height: 24),
                const AppPageIntro(
                  title: 'Tu perfil',
                  subtitle: 'Gestiona tu información principal.',
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppTheme.surfaceSoft,
                        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                            ? NetworkImage(
                                _resolveImageUrl(photoUrl),
                                headers: SessionService.currentAccessToken == null || SessionService.currentAccessToken!.isEmpty
                                    ? null
                                    : {'Authorization': 'Bearer ${SessionService.currentAccessToken!}'},
                              )
                            : null,
                        child: photoUrl == null || photoUrl.isEmpty
                            ? const Icon(Icons.person_outline_rounded, size: 40, color: AppTheme.accent)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(user.nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      _RatingStrip(ratingAvg: _ratingAvg, ratingCount: _ratingCount),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _uploadingPhoto ? null : () => _pickProfilePhoto(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Galería'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _uploadingPhoto ? null : () => _pickProfilePhoto(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Cámara'),
                          ),
                        ],
                      ),
                      if (_uploadingPhoto) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Datos personales',
                  child: Column(
                    children: [
                      TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre completo')),
                      const SizedBox(height: 12),
                      TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Teléfono')),
                      const SizedBox(height: 12),
                      TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Dirección base'), maxLines: 2),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Ubicación base',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedCountry,
                        decoration: const InputDecoration(labelText: 'Ubicación base · país'),
                        items: supportedCountries.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          final region = availableRegionsForCountry(value).firstOrNull;
                          setState(() {
                            _selectedCountry = value;
                            _selectedRegion = region;
                            _selectedCity = value == 'Guatemala'
                                ? municipalitiesForDepartment(region ?? '').firstOrNull
                                : citiesForUsState(region ?? '').firstOrNull;
                            _selectedZone = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedRegion,
                        decoration: const InputDecoration(labelText: 'Ubicación base · región'),
                        items: availableRegionsForCountry(_selectedCountry)
                            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedRegion = value;
                            _selectedCity = _selectedCountry == 'Guatemala'
                                ? municipalitiesForDepartment(value).firstOrNull
                                : citiesForUsState(value).firstOrNull;
                            _selectedZone = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedCity,
                        decoration: const InputDecoration(labelText: 'Ubicación base · ciudad'),
                        items: cityOptions.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                        onChanged: (value) => setState(() => _selectedCity = value),
                      ),
                    ],
                  ),
                ),
                if (_isTraveler) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Cobertura del viajero',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selecciona los estados y destinos de USA que cubres para que el sistema conozca tu ruta real.',
                          style: TextStyle(color: AppTheme.muted),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/traveler_routes'),
                            icon: const Icon(Icons.route_outlined),
                            label: const Text('Editar destinos que cubro'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _RatingsSummaryCard(ratingAvg: _ratingAvg, ratingCount: _ratingCount, ratings: _ratings),
                ],
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Estado de cuenta',
                  child: Column(
                    children: [
                      _StatusRow(label: 'Verificación', value: user.verificado ? 'Perfil aprobado' : 'Pendiente de revisión'),
                      _StatusRow(label: 'Operación', value: user.bloqueado ? 'Con restricción' : 'Activo'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Guardar cambios'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _deleteAccount,
                    icon: const Icon(Icons.person_remove_outlined, color: Colors.redAccent),
                    label: const Text('Eliminar cuenta', style: TextStyle(color: Colors.redAccent)),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.muted))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RatingStrip extends StatelessWidget {
  final double ratingAvg;
  final int ratingCount;

  const _RatingStrip({required this.ratingAvg, required this.ratingCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (index) => Icon(
              index < ratingAvg.round() ? Icons.star_rounded : Icons.star_border_rounded,
              color: const Color(0xFFFFC83D),
              size: 18,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ratingCount == 0 ? 'Sin calificaciones todavía' : '${ratingAvg.toStringAsFixed(1)} de 5 • $ratingCount calificaciones',
          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _RatingsSummaryCard extends StatelessWidget {
  final double ratingAvg;
  final int ratingCount;
  final List<RatingModel> ratings;

  const _RatingsSummaryCard({
    required this.ratingAvg,
    required this.ratingCount,
    required this.ratings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        title: const Text('Resumen de calificaciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        subtitle: Text(
          ratingCount == 0 ? 'Aún no tienes reseñas visibles.' : '$ratingCount calificaciones registradas',
          style: const TextStyle(color: AppTheme.muted),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ratingCount == 0 ? '—' : ratingAvg.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < ratingAvg.round() ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFFFC83D),
                      size: 18,
                    ),
                  ),
                ),
                if (ratings.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('Comentarios recientes', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ...ratings.take(3).map((rating) {
                    final comment = rating.comentario.trim().isEmpty ? 'Sin comentario escrito.' : rating.comentario.trim();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rating.fromUserName.isEmpty ? 'Usuario' : rating.fromUserName, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(comment, style: const TextStyle(color: AppTheme.muted, height: 1.35)),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
