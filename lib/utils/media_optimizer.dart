import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';

class MediaOptimizer {
  static Future<File?> compressImage(String path) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      path,
      "${path}_compressed.jpg",
      quality: 70,
      minWidth: 1280,
      minHeight: 1280,
    );

    if (result == null) return null;

    return File(result.path);
  }

  static Future<File?> compressVideo(String path) async {
    final info = await VideoCompress.compressVideo(
      path,
      quality: VideoQuality.MediumQuality,
    );

    if (info?.path == null) return null;

    return File(info!.path!);
  }

  static bool isValidFileSize(
    File file,
    int maxMb,
  ) {
    final size = file.lengthSync() / (1024 * 1024);
    return size <= maxMb;
  }
}