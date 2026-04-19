import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedRecipient {
  final String name;
  final String phone;
  final String address;
  final String country;
  final String region;

  const SavedRecipient({
    required this.name,
    required this.phone,
    required this.address,
    required this.country,
    required this.region,
  });

  factory SavedRecipient.fromJson(Map<String, dynamic> json) {
    return SavedRecipient(
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      country: (json['country'] ?? '').toString(),
      region: (json['region'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'address': address,
        'country': country,
        'region': region,
      };
}

class SavedRecipientService {
  String _keyForUser(String userId) => 'saved_recipients_$userId';

  Future<List<SavedRecipient>> getAll(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyForUser(userId));
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .map(SavedRecipient.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(String userId, SavedRecipient recipient) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getAll(userId);
    final deduped = current.where((item) {
      final sameName = item.name.toLowerCase() == recipient.name.toLowerCase();
      final samePhone = item.phone.trim() == recipient.phone.trim();
      return !(sameName && samePhone);
    }).toList();

    final updated = [recipient, ...deduped].take(12).map((e) => e.toJson()).toList();
    await prefs.setString(_keyForUser(userId), jsonEncode(updated));
  }

  Future<void> remove(String userId, SavedRecipient recipient) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getAll(userId);
    final updated = current.where((item) {
      final sameName = item.name.toLowerCase() == recipient.name.toLowerCase();
      final samePhone = item.phone.trim() == recipient.phone.trim();
      return !(sameName && samePhone);
    }).map((e) => e.toJson()).toList();
    await prefs.setString(_keyForUser(userId), jsonEncode(updated));
  }
}
