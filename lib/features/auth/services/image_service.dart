import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ImageService {

  final ImagePicker _picker = ImagePicker();

  Future<File?> takePhoto() async {

    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (image == null) return null;

    return File(image.path);
  }
}