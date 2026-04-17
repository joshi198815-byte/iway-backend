import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:iway_app/config/app_env.dart';
import 'package:iway_app/services/session_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration requestTimeout = Duration(seconds: 60);

  static String get baseUrl => AppEnv.apiBaseUrl;

  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{'Accept': 'application/json'};

    if (json) {
      headers['Content-Type'] = 'application/json';
    }

    final token = SessionService.currentAccessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  List<Uri> _candidateUris(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final primaryBase = baseUrl.replaceAll(RegExp(r'/$'), '');
    final fallbackBase = primaryBase.endsWith('/api')
        ? primaryBase.substring(0, primaryBase.length - 4)
        : primaryBase;

    final candidates = <Uri>[
      Uri.parse('$primaryBase$normalizedPath'),
    ];

    final fallbackUri = Uri.parse('$fallbackBase$normalizedPath');
    if (fallbackUri.toString() != candidates.first.toString()) {
      candidates.add(fallbackUri);
    }

    return candidates;
  }

  Future<http.Response> _sendWith404Fallback(
    String path,
    Future<http.Response> Function(Uri uri) sender,
  ) async {
    final candidates = _candidateUris(path);
    http.Response? lastResponse;

    for (var index = 0; index < candidates.length; index++) {
      final response = await sender(candidates[index]).timeout(requestTimeout);
      lastResponse = response;

      final shouldRetryWithFallback = response.statusCode == 404 && index < candidates.length - 1;
      if (!shouldRetryWithFallback) {
        return response;
      }
    }

    return lastResponse!;
  }

  Future<dynamic> get(String path) async {
    final response = await _sendWith404Fallback(
      path,
      (uri) => _client.get(uri, headers: _headers()),
    );

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await _sendWith404Fallback(
      path,
      (uri) => _client.post(
        uri,
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
    );

    final decoded = _decodeResponse(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'data': decoded};
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final response = await _sendWith404Fallback(
      path,
      (uri) => _client.patch(
        uri,
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
    );

    final decoded = _decodeResponse(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'data': decoded};
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final response = await _sendWith404Fallback(
      path,
      (uri) => _client.put(
        uri,
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
    );

    final decoded = _decodeResponse(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'data': decoded};
  }

  dynamic _decodeResponse(http.Response response) {
    final raw = response.body;
    final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String message = 'Ocurrió un error con el servidor.';

    if (decoded is Map<String, dynamic>) {
      final error = decoded['message'];
      if (error is String && error.isNotEmpty) {
        message = error;
      } else if (error is List && error.isNotEmpty) {
        message = error.join(', ');
      }
    }

    throw ApiException(message, statusCode: response.statusCode);
  }
}
