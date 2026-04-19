import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleController {
  AppLocaleController._();

  static const _storageKey = 'app_language';
  static final ValueNotifier<Locale> notifier = ValueNotifier(const Locale('es'));

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_storageKey) ?? 'es';
    notifier.value = Locale(code);
  }

  static Future<void> setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, code);
    notifier.value = Locale(code);
  }

  static String get currentCode => notifier.value.languageCode;
}
