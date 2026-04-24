import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:iway_app/config/app_env.dart';
import 'package:iway_app/features/notifications/services/push_notification_service.dart';
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

  static bool _handlingUnauthorized = false;

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
    final bases = <String>{
      baseUrl.replaceAll(RegExp(r'/$'), ''),
      AppEnv.fallbackApiBaseUrl.replaceAll(RegExp(r'/$'), ''),
    };

    final candidates = <Uri>[];
    for (final base in bases) {
      candidates.add(Uri.parse('$base$normalizedPath'));

      final fallbackBase = base.endsWith('/api')
          ? base.substring(0, base.length - 4)
          : base;
      final fallbackUri = Uri.parse('$fallbackBase$normalizedPath');
      if (!candidates.any((candidate) => candidate.toString() == fallbackUri.toString())) {
        candidates.add(fallbackUri);
      }
    }

    return candidates;
  }

  Future<http.Response> _sendWith404Fallback(
    String path,
    Future<http.Response> Function(Uri uri) sender,
  ) async {
    final candidates = _candidateUris(path);
    http.Response? lastResponse;

    try {
      for (var index = 0; index < candidates.length; index++) {
        final response = await sender(candidates[index]).timeout(requestTimeout);
        lastResponse = response;

        final shouldRetryWithFallback =
            (response.statusCode == 404 || !_looksLikeJsonResponse(response)) &&
            index < candidates.length - 1;
        if (!shouldRetryWithFallback) {
          return response;
        }
      }
    } on TimeoutException {
      throw ApiException('La solicitud tardó demasiado. Intenta de nuevo.');
    } on SocketException {
      throw ApiException('No se pudo conectar al servidor. Verifica tu conexión.');
    } on HttpException {
      throw ApiException('La conexión con el servidor falló. Intenta de nuevo.');
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

  Future<Map<String, dynamic>> delete(String path) async {
    final response = await _sendWith404Fallback(
      path,
      (uri) => _client.delete(uri, headers: _headers()),
    );

    final decoded = _decodeResponse(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'data': decoded};
  }

  Future<void> _handleUnauthorized() async {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;

    try {
      await SessionService.clear();
      final navigator = PushNotificationService.navigatorKey.currentState;
      navigator?.pushNamedAndRemoveUntil('/login', (_) => false);
    } finally {
      _handlingUnauthorized = false;
    }
  }

  bool _looksLikeJsonResponse(http.Response response) {
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (contentType.contains('application/json')) {
      return true;
    }

    final body = response.body.trimLeft();
    return body.startsWith('{') || body.startsWith('[');
  }

  dynamic _decodeResponse(http.Response response) {
    final raw = response.body;
    dynamic decoded;

    try {
      decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    } on FormatException {
      throw ApiException('El servidor respondió con un formato inválido.', statusCode: response.statusCode);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (response.statusCode == 401) {
      unawaited(_handleUnauthorized());
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
