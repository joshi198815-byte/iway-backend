import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:iway_app/config/app_env.dart';

class NetworkDiagnostic {
  static Uri _uri(String path) => Uri.parse('${AppEnv.apiBaseUrl}$path');

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
          .timeout(const Duration(seconds: 30));

      final elapsed = DateTime.now().difference(started).inMilliseconds;
      print('');
      print('========== DIAGNOSTIC POST $path ==========');
      print('URL: $uri');
      print('STATUS: ${response.statusCode}');
      print('TIME_MS: $elapsed');
      print('HEADERS: ${response.headers}');
      print('BODY: ${response.body}');

      try {
        final decoded = jsonDecode(response.body);
        print('BODY_JSON: $decoded');
      } catch (_) {
        print('BODY_JSON: <not-json>');
      }
      print('===========================================');
    } on SocketException catch (e) {
      print('');
      print('========== DIAGNOSTIC POST $path ==========');
      print('URL: $uri');
      print('NETWORK_ERROR(SocketException): $e');
      print('TIP: si aquí sale handshake/certificate, el problema es SSL/TLS.');
      print('===========================================');
    } on HandshakeException catch (e) {
      print('');
      print('========== DIAGNOSTIC POST $path ==========');
      print('URL: $uri');
      print('TLS_ERROR(HandshakeException): $e');
      print('TIP: Android no está confiando en el certificado del dominio.');
      print('===========================================');
    } catch (e, st) {
      print('');
      print('========== DIAGNOSTIC POST $path ==========');
      print('URL: $uri');
      print('UNEXPECTED_ERROR: $e');
      print(st);
      print('===========================================');
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

    print('DOCUMENT_PATH: ${documentFile.path}');
    print('DOCUMENT_SIZE_BYTES: ${documentBytes.length}');
    print('SELFIE_PATH: ${selfieFile.path}');
    print('SELFIE_SIZE_BYTES: ${selfieBytes.length}');

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
