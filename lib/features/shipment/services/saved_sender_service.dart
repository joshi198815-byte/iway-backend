import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedSender {
  final String name;
  final String phone;
  final String address;
  final String countryCode;
  final String stateRegion;

  const SavedSender({
    required this.name,
    required this.phone,
    required this.address,
    required this.countryCode,
    required this.stateRegion,
  });

  factory SavedSender.fromJson(Map<String, dynamic> json) {
    return SavedSender(
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      countryCode: (json['countryCode'] ?? '').toString(),
      stateRegion: (json['stateRegion'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'address': address,
        'countryCode': countryCode,
        'stateRegion': stateRegion,
      };
}

class SavedSenderService {
  String _keyForUser(String userId) => 'saved_senders_$userId';

  Future<List<SavedSender>> getAll(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyForUser(userId));
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .map(SavedSender.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(String userId, SavedSender sender) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getAll(userId);
    final deduped = current.where((item) {
      final sameName = item.name.toLowerCase() == sender.name.toLowerCase();
      final samePhone = item.phone.trim() == sender.phone.trim();
      return !(sameName && samePhone);
    }).toList();

    final updated = [sender, ...deduped].take(10).map((e) => e.toJson()).toList();
    await prefs.setString(_keyForUser(userId), jsonEncode(updated));
  }

  Future<void> remove(String userId, SavedSender sender) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getAll(userId);
    final updated = current.where((item) {
      final sameName = item.name.toLowerCase() == sender.name.toLowerCase();
      final samePhone = item.phone.trim() == sender.phone.trim();
      return !(sameName && samePhone);
    }).map((e) => e.toJson()).toList();
    await prefs.setString(_keyForUser(userId), jsonEncode(updated));
  }
}
