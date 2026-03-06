import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'image_compression.dart';

/// Central service for uploading images to Firebase Storage and getting download URLs.
/// Used for: proof of residence, profile images, post images, product images.
/// Download: use the returned URL with Image.network() or NetworkImage() (no extra API).
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload image from [XFile] (e.g. from ImagePicker) to [storagePath].
  /// Compresses to ~800px width and ~300–500KB before upload.
  Future<String?> uploadImageFromXFile(XFile xFile, String storagePath) async {
    try {
      final bytes = await xFile.readAsBytes();
      return uploadImageFromBytes(bytes, storagePath);
    } catch (e) {
      return null;
    }
  }

  /// Upload image bytes to [storagePath]. Compresses before upload if large.
  Future<String?> uploadImageFromBytes(Uint8List bytes, String storagePath) async {
    try {
      final compressed = ImageCompression.compressForUpload(bytes);
      final ref = _storage.ref().child(storagePath);
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putData(compressed, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  /// Build path for proof of residence: proof/{uid}_{timestamp}.jpg
  static String proofPath(String uid) =>
      'proof/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

  /// Build path for profile image: profiles/{uid}.jpg
  static String profilePath(String uid) => 'profiles/$uid.jpg';

  /// Build path for post image: posts/{uid}_{timestamp}_{index}.jpg
  static String postImagePath(String uid, int index) =>
      'posts/${uid}_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';

  /// Build path for product image: products/{uid}_{timestamp}_{index}.jpg
  static String productImagePath(String uid, int index) =>
      'products/${uid}_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';

  /// Build path for task/errand image: task_images/{uid}_{timestamp}_{index}.jpg
  static String taskImagePath(String uid, int index) =>
      'task_images/${uid}_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
}
