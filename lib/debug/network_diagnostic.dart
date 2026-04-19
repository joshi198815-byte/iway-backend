import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:iway_app/config/app_env.dart';
import 'package:iway_app/services/api_client.dart';

class NetworkDiagnostic {
  static Uri _uri(String path) => Uri.parse('${AppEnv.apiBaseUrl}$path');

  static void _log(Object? message) {
    if (!kDebugMode) return;
    debugPrint(message?.toString());
  }

  static Future<void> postJson(String path, Map<String, dynamic> body) async {
    final uri = _uri(path);
    final started = DateTime.now();

    try {
      final response = await http
          .post(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(ApiClient.requestTimeout);

      final elapsed = DateTime.now().difference(started).inMilliseconds;
      _log('');
      _log('========== DIAGNOSTIC POST $path ==========');
      _log('URL: $uri');
      _log('STATUS: ${response.statusCode}');
      _log('TIME_MS: $elapsed');
      _log('HEADERS: ${response.headers}');
      _log('BODY: ${response.body}');

      try {
        final decoded = jsonDecode(response.body);
        _log('BODY_JSON: $decoded');
      } catch (_) {
        _log('BODY_JSON: <not-json>');
      }
      _log('===========================================');
    } on SocketException catch (e) {
      _log('');
      _log('========== DIAGNOSTIC POST $path ==========');
      _log('URL: $uri');
      _log('NETWORK_ERROR(SocketException): $e');
      _log('TIP: si aquí sale handshake/certificate, el problema es SSL/TLS.');
      _log('===========================================');
    } on HandshakeException catch (e) {
      _log('');
      _log('========== DIAGNOSTIC POST $path ==========');
      _log('URL: $uri');
      _log('TLS_ERROR(HandshakeException): $e');
      _log('TIP: Android no está confiando en el certificado del dominio.');
      _log('===========================================');
    } catch (e, st) {
      _log('');
      _log('========== DIAGNOSTIC POST $path ==========');
      _log('URL: $uri');
      _log('UNEXPECTED_ERROR: $e');
      _log(st);
      _log('===========================================');
    }
  }

  static Future<void> debugLogin({
    required String email,
    required String password,
  }) {
    return postJson('/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
  }

  static Future<void> debugRegisterCustomer() {
    return postJson('/auth/register/customer', {
      'fullName': 'Diag Customer',
      'email': 'diag_${DateTime.now().millisecondsSinceEpoch}@example.com',
      'phone': '55555555',
      'password': 'diag1234',
      'countryCode': 'GT',
      'stateRegion': 'Guatemala',
      'city': 'Guatemala',
      'address': 'Zona 10',
    });
  }

  static Future<void> debugRegisterTraveler({
    required File documentFile,
    required File selfieFile,
  }) async {
    final documentBytes = await documentFile.readAsBytes();
    final selfieBytes = await selfieFile.readAsBytes();

    final documentBase64 = 'data:image/jpeg;base64,${base64Encode(documentBytes)}';
    final selfieBase64 = 'data:image/jpeg;base64,${base64Encode(selfieBytes)}';

    _log('DOCUMENT_PATH: ${documentFile.path}');
    _log('DOCUMENT_SIZE_BYTES: ${documentBytes.length}');
    _log('SELFIE_PATH: ${selfieFile.path}');
    _log('SELFIE_SIZE_BYTES: ${selfieBytes.length}');

    await postJson('/auth/register/traveler', {
      'fullName': 'Diag Traveler',
      'email': 'traveler_diag_${DateTime.now().millisecondsSinceEpoch}@example.com',
      'phone': '55555555',
      'password': 'diag1234',
      'travelerType': 'avion_ida_vuelta',
      'documentNumber': 'DIAG-${DateTime.now().millisecondsSinceEpoch}',
      'countryCode': 'GT',
      'detectedCountryCode': 'GT',
      'stateRegion': 'Guatemala',
      'city': 'Guatemala',
      'address': 'Zona 10',
      'documentBase64': documentBase64,
      'selfieBase64': selfieBase64,
    });
  }
}
