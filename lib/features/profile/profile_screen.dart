import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/services/auth_service.dart';
import 'package:iway_app/features/notifications/services/push_notification_service.dart';
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
  final _storageUploadService = StorageUploadService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _routeController = TextEditingController();

  bool _saving = false;
  bool _uploadingPhoto = false;
  List<String> _routes = [];
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    final user = SessionService.currentUser;
    _nameController.text = user?.nombre ?? '';
    _phoneController.text = user?.telefono ?? '';
    _addressController.text = user?.direccion ?? '';
    _routes = [...?user?.rutas];
    _photoUrl = user?.selfiePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  String _resolveImageUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '${ApiClient.baseUrl}$value';
  }

  Future<void> _pickProfilePhoto(ImageSource source) async {
    setState(() => _uploadingPhoto = true);
    try {
      final result = await _storageUploadService.pickAndUploadProfilePhoto(source: source);
      if (!mounted) return;
      setState(() {
        _photoUrl = result?['url']?.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  void _addRoute() {
    final value = _routeController.text.trim();
    if (value.isEmpty) return;
    if (_routes.any((route) => route.toLowerCase() == value.toLowerCase())) {
      _routeController.clear();
      return;
    }
    setState(() {
      _routes = [..._routes, value];
      _routeController.clear();
    });
  }

  Future<void> _saveProfile() async {
    final user = SessionService.currentUser;
    if (user == null) return;

    if ((_photoUrl ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes subir una selfie para guardar tu perfil.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _authService.updateProfile(
        fullName: _nameController.text,
        phone: _phoneController.text,
        countryCode: user.pais,
        stateRegion: _routes.join(', '),
        address: _addressController.text,
        selfieUrl: _photoUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el perfil.')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;
    final hasSession = user != null;
    final isTraveler = user?.tipo == 'traveler';
    final photoUrl = _photoUrl;

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
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                const SizedBox(height: 24),
                const AppPageIntro(
                  title: 'Tu perfil',
                  subtitle: 'Edita tus datos, tus rutas y tu foto de viajero.',
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: hasSession
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 74,
                                    height: 74,
                                    color: AppTheme.surfaceSoft,
                                    child: photoUrl != null && photoUrl.isNotEmpty
                                        ? Image.network(
                                            _resolveImageUrl(photoUrl),
                                            fit: BoxFit.cover,
                                            headers: SessionService.currentAccessToken == null || SessionService.currentAccessToken!.isEmpty
                                                ? null
                                                : {'Authorization': 'Bearer ${SessionService.currentAccessToken!}'},
                                            errorBuilder: (_, __, ___) => const Icon(
                                              Icons.person_outline_rounded,
                                              size: 34,
                                              color: AppTheme.accent,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person_outline_rounded,
                                            size: 34,
                                            color: AppTheme.accent,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isTraveler ? 'Perfil del viajero' : 'Perfil de usuario',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.email.isNotEmpty ? user.email : 'Sin correo',
                                        style: const TextStyle(color: AppTheme.muted),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        photoUrl == null || photoUrl.isEmpty
                                            ? 'La selfie es obligatoria para mantener el perfil activo.'
                                            : 'Selfie cargada y lista para edición.',
                                        style: TextStyle(
                                          color: photoUrl == null || photoUrl.isEmpty ? Colors.amber[300] : AppTheme.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
                            const SizedBox(height: 18),
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Nombre completo'),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _phoneController,
                              decoration: const InputDecoration(labelText: 'Teléfono'),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _addressController,
                              decoration: const InputDecoration(labelText: 'Dirección base'),
                              maxLines: 2,
                            ),
                            if (isTraveler) ...[
                              const SizedBox(height: 18),
                              const Text(
                                'Rutas / estados donde viajas en USA',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Agrega uno o varios estados para que quede claro por dónde operas.',
                                style: TextStyle(color: AppTheme.muted, height: 1.4),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _routeController,
                                      decoration: const InputDecoration(
                                        labelText: 'Ejemplo: Florida, Texas, New York',
                                      ),
                                      onSubmitted: (_) => _addRoute(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: _addRoute,
                                    child: const Text('Agregar'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_routes.isEmpty)
                                const Text(
                                  'Todavía no has agregado rutas.',
                                  style: TextStyle(color: AppTheme.muted),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _routes
                                      .map(
                                        (route) => Chip(
                                          label: Text(route),
                                          deleteIcon: const Icon(Icons.close, size: 18),
                                          onDeleted: () {
                                            setState(() {
                                              _routes = _routes.where((item) => item != route).toList();
                                            });
                                          },
                                        ),
                                      )
                                      .toList(),
                                ),
                            ],
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, '/my_ratings'),
                              icon: const Icon(Icons.star_outline_rounded),
                              label: const Text('Ver mis calificaciones'),
                            ),
                            const SizedBox(height: 18),
                            _ProfileStatusRow(
                              label: 'Estado de verificación',
                              value: user.verificado ? 'Perfil aprobado' : 'Pendiente de revisión',
                            ),
                            _ProfileStatusRow(
                              label: 'Estado operativo',
                              value: user.bloqueado ? 'Con restricción' : 'Activo',
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _saving ? null : _saveProfile,
                                child: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Guardar cambios'),
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'No hay una sesión activa. Inicia sesión para ver tu perfil.',
                          style: TextStyle(color: AppTheme.muted, height: 1.5),
                        ),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () async {
                    if (hasSession) {
                      await PushNotificationService.deactivateCurrentToken();
                      await SessionService.clear();
                    }
                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.border),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(hasSession ? 'Cerrar sesión' : 'Ir a login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileStatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.muted),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
