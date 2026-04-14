import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:iway_app/services/api_client.dart';

class StorageUploadService {
  StorageUploadService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;
  final ImagePicker _picker = ImagePicker();

  Future<Map<String, dynamic>?> pickAndUploadTransferProof({ImageSource source = ImageSource.gallery}) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final extension = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
    final base64 = 'data:$mimeType;base64,${base64Encode(bytes)}';

    return _apiClient.post('/storage/upload-base64', {
      'bucket': 'transfer-proofs',
      'fileName': 'transfer-proof-${DateTime.now().millisecondsSinceEpoch}',
      'base64': base64,
    });
  }
}
