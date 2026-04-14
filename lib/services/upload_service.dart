import 'dart:convert';
import 'dart:io';

import 'package:iway_app/services/api_client.dart';

class UploadService {
  UploadService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<String> encodeImageAsDataUrl(File file) async {
    final bytes = await file.readAsBytes();
    final base64 = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64';
  }

  Future<String> uploadImage({
    required File file,
    required String bucket,
    required String fileName,
  }) async {
    final data = await _apiClient.post('/storage/upload-base64', {
      'bucket': bucket,
      'fileName': fileName,
      'base64': await encodeImageAsDataUrl(file),
    });

    final url = data['url']?.toString();
    if (url == null || url.isEmpty) {
      throw ApiException('No se pudo subir el archivo.');
    }

    return url;
  }
}
