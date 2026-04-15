import 'dart:convert';

import 'package:http/http.dart' as http;

class AddressLocationResult {
  final double latitude;
  final double longitude;
  final String formattedAddress;

  const AddressLocationResult({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
  });
}

class AddressSearchService {
  AddressSearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _apiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyAidt2UJyI9DvKjnLltJKZ6SsnLCwservw',
  );

  Future<AddressLocationResult?> geocodeAddress({
    required String address,
    required String countryCode,
  }) async {
    if (address.trim().isEmpty || _apiKey.trim().isEmpty) {
      return null;
    }

    final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'address': address.trim(),
      'components': 'country:${countryCode.trim()}',
      'key': _apiKey,
      'language': 'es',
    });

    final response = await _client.get(uri, headers: {
      'Accept': 'application/json',
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final results = decoded['results'];
    if (results is! List || results.isEmpty) return null;

    final first = results.first;
    if (first is! Map<String, dynamic>) return null;

    final geometry = first['geometry'];
    if (geometry is! Map<String, dynamic>) return null;

    final location = geometry['location'];
    if (location is! Map<String, dynamic>) return null;

    final lat = _toDouble(location['lat']);
    final lng = _toDouble(location['lng']);
    if (lat == null || lng == null) return null;

    return AddressLocationResult(
      latitude: lat,
      longitude: lng,
      formattedAddress: (first['formatted_address'] ?? address).toString(),
    );
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
