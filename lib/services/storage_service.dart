import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  static const _uuid = Uuid();

  // 1. Image Upload (with compression)
  static Future<String> uploadImage(File image) async {
    final fileName = "${_uuid.v4()}.jpg";
    
    final compressed = await FlutterImageCompress.compressAndGetFile(
      image.path,
      "${image.path}_compressed.jpg",
      quality: 70,
      minWidth: 1280,
      minHeight: 1280,
    );

    final file = File(compressed?.path ?? image.path);

    final ref = FirebaseStorage.instance
        .ref()
        .child("group_images")
        .child(fileName);

    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));

    return await ref.getDownloadURL();
  }

  // 2. Video Upload (with compression)
  static Future<String> uploadVideo(File file) async {
    final info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
    );

    final compressed = info?.file ?? file;

    return await uploadFile(
      compressed,
      "group_videos",
    );
  }

  // 3. Generic File Upload (Audio, Docs, etc.)
  static Future<String> uploadFile(File file, String folder) async {
    final fileName = _uuid.v4();
    final ref = FirebaseStorage.instance
        .ref()
        .child(folder)
        .child(fileName);

    // Metadata helps in caching and browser identification
    await ref.putFile(
      file, 
      SettableMetadata(cacheControl: "public,max-age=31536000")
    );

    return await ref.getDownloadURL();
  }

  // Utility to delete files if needed
  static Future<void> deleteFile(String url) async {
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (e) {
      print("Error deleting file: $e");
    }
  }
}