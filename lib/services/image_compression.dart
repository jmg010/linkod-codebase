import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Compresses image bytes for upload: max width ~800px, target size ~300–500KB.
/// Uses native compression; handles all formats including HEIC from iOS.
class ImageCompression {
  ImageCompression._();

  static const int maxWidth = 800;
  static const int maxHeight = 800;
  static const int quality = 85;

  /// Returns compressed JPEG bytes, or original [bytes] if compression fails.
  static Future<Uint8List> compressForUpload(Uint8List bytes) async {
    try {
      // Use flutter_image_compress which handles all formats including HEIC
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxWidth,
        minHeight: maxHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      return result;
    } catch (e) {
      // If compression fails, return original bytes
      return bytes;
    }
  }
}
