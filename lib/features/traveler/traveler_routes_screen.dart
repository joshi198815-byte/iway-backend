import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/features/auth/data/location_catalogs.dart';
import 'package:iway_app/features/traveler/services/traveler_workspace_service.dart';
import 'package:iway_app/shared/ui/app_back_button_shell.dart';
import 'package:iway_app/shared/ui/app_glass_section.dart';
import 'package:iway_app/shared/ui/app_page_intro.dart';

class TravelerRoutesScreen extends StatefulWidget {
  const TravelerRoutesScreen({super.key});

  @override
  State<TravelerRoutesScreen> createState() => _TravelerRoutesScreenState();
}

class _TravelerRoutesScreenState extends State<TravelerRoutesScreen> {
  final _workspaceService = TravelerWorkspaceService();

  List<String> _selectedRoutes = [];
  String? _selectedState;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedState = availableRegionsForCountry('Estados Unidos').firstOrNull;
    _load();
  }

  Future<void> _load() async {
    try {
      final workspace = await _workspaceService.getWorkspace();
      if (!mounted) return;
      setState(() {
        _selectedRoutes = [...workspace.routes];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar tus rutas.')),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _workspaceService.updateWorkspace(routes: _selectedRoutes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tus rutas quedaron actualizadas.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron guardar tus rutas.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleRoute(String label) {
    setState(() {
      if (_selectedRoutes.contains(label)) {
        _selectedRoutes.remove(label);
      } else {
        _selectedRoutes.add(label);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final states = availableRegionsForCountry('Estados Unidos');
    final cities = citiesForUsState(_selectedState ?? '');

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
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                  children: [
                    AppBackButtonShell(onTap: () => Navigator.maybePop(context)),
                    const SizedBox(height: 24),
                    const AppPageIntro(
                      title: 'Mis rutas',
                      subtitle: 'Elige estados y ciudades de USA. Puedes combinar varias y borrar las que ya no operas.',
                    ),
                    const SizedBox(height: 18),
                    AppGlassSection(
                      title: 'Rutas activas',
                      child: _selectedRoutes.isEmpty
                          ? const Text('Todavía no agregaste rutas.', style: TextStyle(color: AppTheme.muted))
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _selectedRoutes.map((route) {
                                return Chip(
                                  label: Text(route),
                                  onDeleted: () => _toggleRoute(route),
                                  deleteIcon: const Icon(Icons.close_rounded, size: 18),
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 16),
                    AppGlassSection(
                      title: 'Estados',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: states.map((state) {
                          final selected = _selectedRoutes.contains(state);
                          return FilterChip(
                            label: Text(state),
                            selected: selected || _selectedState == state,
                            onSelected: (_) {
                              setState(() => _selectedState = state);
                              if (selected) {
                                _toggleRoute(state);
                              } else {
                                _toggleRoute(state);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppGlassSection(
                      title: _selectedState == null ? 'Ciudades' : 'Ciudades de $_selectedState',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: cities.map((city) {
                          final label = '${_selectedState ?? ''} · $city';
                          return FilterChip(
                            label: Text(city),
                            selected: _selectedRoutes.contains(label),
                            onSelected: (_) => _toggleRoute(label),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Guardar rutas'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
