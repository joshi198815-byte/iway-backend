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

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

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

  Future<dynamic> get(String path) async {
    final response = await _client
        .get(_uri(path), headers: _headers())
        .timeout(requestTimeout);

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          _uri(path),
          headers: _headers(json: true),
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);

    final decoded = _decodeResponse(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'data': decoded};
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final response = await _client
        .patch(
          _uri(path),
          headers: _headers(json: true),
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);

    final decoded = _decodeResponse(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'data': decoded};
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final response = await _client
        .put(
          _uri(path),
          headers: _headers(json: true),
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);

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
