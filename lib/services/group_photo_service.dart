import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import 'storage_service.dart';

class GroupPhotoService {
  static Future<void> changePhoto({
    required String groupId,
  }) async {
    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (image == null) return;

    final url =
        await StorageService.uploadImage(
      File(image.path),
    );

    await FirebaseFirestore.instance
        .collection("groups")
        .doc(groupId)
        .update({
      "groupPhoto": url,
    });
  }
}