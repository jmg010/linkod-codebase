import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Service for fetching barangay information from Firestore (admin-managed data)
class BarangayInfoService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _categoriesCollection = 'barangayCategories';
  static const String _postingsCollection = 'barangayPostings';

  /// Get all categories stream from Firestore
  static Stream<List<Map<String, dynamic>>> getCategoriesStream() {
    return _firestore
        .collection(_categoriesCollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'title': data['title'] as String? ?? 'Untitled',
                  'description': data['description'] as String? ?? '',
                  'iconCodePoint': data['iconCodePoint'],
                  'iconFontFamily': data['iconFontFamily'] as String?,
                  ...data,
                };
              }).toList(),
        );
  }

  /// Get all categories (one-time fetch)
  static Future<List<Map<String, dynamic>>> getCategories() async {
    final snapshot =
        await _firestore
            .collection(_categoriesCollection)
            .orderBy('createdAt', descending: false)
            .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'title': data['title'] as String? ?? 'Untitled',
        'description': data['description'] as String? ?? '',
        'iconCodePoint': data['iconCodePoint'],
        'iconFontFamily': data['iconFontFamily'] as String?,
        ...data,
      };
    }).toList();
  }

  /// Get postings stream for a specific category
  static Stream<List<Map<String, dynamic>>> getPostingsStream(
    String categoryId,
  ) {
    return _firestore
        .collection(_postingsCollection)
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) {
                final data = doc.data();
                return {'id': doc.id, ...data};
              }).toList(),
        );
  }

  /// Get postings for a specific category (one-time fetch)
  static Future<List<Map<String, dynamic>>> getPostings(
    String categoryId,
  ) async {
    final snapshot =
        await _firestore
            .collection(_postingsCollection)
            .where('categoryId', isEqualTo: categoryId)
            .orderBy('createdAt', descending: true)
            .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {'id': doc.id, ...data};
    }).toList();
  }

  /// Reconstruct IconData from Firestore iconCodePoint
  /// Handles both int and String codePoint for backward compatibility
  static IconData? getIconFromCodePoint(dynamic codePoint, String? fontFamily) {
    if (codePoint == null) return null;

    int? parsedCodePoint;
    if (codePoint is int) {
      parsedCodePoint = codePoint;
    } else if (codePoint is String) {
      parsedCodePoint = int.tryParse(codePoint);
    }

    if (parsedCodePoint == null) return null;

    return IconData(
      parsedCodePoint,
      fontFamily: fontFamily?.isNotEmpty == true ? fontFamily : 'MaterialIcons',
    );
  }

  /// Get image URLs from posting data
  /// Handles both new 'imageUrls' array and old 'imageUrl' single value
  static List<String> getImageUrls(Map<String, dynamic> posting) {
    // Try new imageUrls array first
    final imageUrls = posting['imageUrls'] as List<dynamic>?;
    if (imageUrls != null && imageUrls.isNotEmpty) {
      return imageUrls.cast<String>();
    }

    // Fallback to old single imageUrl
    final singleImageUrl = posting['imageUrl'] as String?;
    if (singleImageUrl != null && singleImageUrl.isNotEmpty) {
      return [singleImageUrl];
    }

    return [];
  }
}
