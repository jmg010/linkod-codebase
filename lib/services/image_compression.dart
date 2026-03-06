import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Compresses image bytes for upload: max width ~800px, target size ~300–500KB.
/// Uses app memory only; does not write to disk.
class ImageCompression {
  ImageCompression._();

  static const int maxWidth = 800;
  static const int targetMaxBytes = 500 * 1024; // 500KB
  static const int absoluteMaxBytes = 600 * 1024; // hard cap

  /// Returns compressed JPEG bytes, or original [bytes] if decode/compress fails.
  static Uint8List compressForUpload(Uint8List bytes) {
    if (bytes.lengthInBytes <= targetMaxBytes) return bytes;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      img.Image resized = decoded;
      if (decoded.width > maxWidth) {
        resized = img.copyResize(decoded, width: maxWidth);
      }
      for (final quality in [85, 75, 65, 55, 45, 35]) {
        final encoded = img.encodeJpg(resized, quality: quality);
        if (encoded.length <= absoluteMaxBytes) return Uint8List.fromList(encoded);
      }
      final encoded = img.encodeJpg(resized, quality: 30);
      return Uint8List.fromList(encoded);
    } catch (_) {
      return bytes;
    }
  }
}
