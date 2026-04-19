import 'package:flutter/material.dart';
import 'package:iway_app/config/theme.dart';
import 'package:iway_app/core/app_locale_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _language = AppLocaleController.currentCode;

  Future<void> _saveLanguage(String value) async {
    await AppLocaleController.setLanguage(value);
    if (!mounted) return;
    setState(() => _language = value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value == 'es' ? 'Idioma actualizado al instante.' : 'Language updated instantly.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Idioma', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                const Text(
                  'El cambio se aplica inmediatamente en la app.',
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'es', label: Text('Español')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {_language},
                  onSelectionChanged: (value) => _saveLanguage(value.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cuenta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                SizedBox(height: 10),
                Text(
                  'El cierre de sesión se movió al final del menú lateral. La eliminación de cuenta sigue canalizada por soporte.',
                  style: TextStyle(color: AppTheme.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
