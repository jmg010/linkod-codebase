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

  /// Resolve Firestore iconCodePoint to a predefined Material icon.
  ///
  /// Known icons are preferred for release safety. If no known icon matches,
  /// we fall back to dynamic Material IconData for compatibility with
  /// admin-selected Firestore icon code points.
  static IconData? getIconFromCodePoint(dynamic codePoint, String? fontFamily) {
    if (codePoint == null) return null;

    final parsedCodePoint = _parseCodePoint(codePoint);

    if (parsedCodePoint == null) return null;

    final normalizedFamily = _normalizeFontFamily(fontFamily);
    if (normalizedFamily != null && normalizedFamily != 'materialicons') {
      return null;
    }

    if (parsedCodePoint == Icons.calendar_today.codePoint) {
      return Icons.calendar_today;
    }
    if (parsedCodePoint == Icons.phone.codePoint) return Icons.phone;
    if (parsedCodePoint == Icons.location_on.codePoint) {
      return Icons.location_on;
    }
    if (parsedCodePoint == Icons.campaign.codePoint) return Icons.campaign;
    if (parsedCodePoint == Icons.push_pin.codePoint) return Icons.push_pin;
    if (parsedCodePoint == Icons.article_outlined.codePoint) {
      return Icons.article_outlined;
    }
    if (parsedCodePoint == Icons.notifications.codePoint) {
      return Icons.notifications;
    }
    if (parsedCodePoint == Icons.announcement.codePoint) {
      return Icons.announcement;
    }
    if (parsedCodePoint == Icons.event.codePoint) return Icons.event;
    if (parsedCodePoint == Icons.home.codePoint) return Icons.home;
    if (parsedCodePoint == Icons.storefront.codePoint) return Icons.storefront;
    if (parsedCodePoint == Icons.handshake.codePoint) return Icons.handshake;

    // Fallback to the exact Material icon selected by admins in Firestore.
    return IconData(parsedCodePoint, fontFamily: 'MaterialIcons');
  }

  static int? _parseCodePoint(dynamic codePoint) {
    if (codePoint is int) return codePoint;
    if (codePoint is num) return codePoint.toInt();
    if (codePoint is! String) return null;

    final raw = codePoint.trim();
    if (raw.isEmpty) return null;

    // Supports values like "0xe88a", "e88a", "U+E88A", and plain decimals.
    final normalized = raw.toLowerCase().replaceFirst('u+', '');
    final without0x =
        normalized.startsWith('0x') ? normalized.substring(2) : normalized;
    final isHex = RegExp(r'^[0-9a-f]+$').hasMatch(without0x);

    if (isHex &&
        (normalized.startsWith('0x') ||
            raw.startsWith('U+') ||
            raw.startsWith('u+'))) {
      return int.tryParse(without0x, radix: 16);
    }

    // If it looks like hex-only text and not a plain integer, parse as hex.
    if (isHex && int.tryParse(raw) == null) {
      return int.tryParse(without0x, radix: 16);
    }

    return int.tryParse(raw);
  }

  static String? _normalizeFontFamily(String? fontFamily) {
    final family = fontFamily?.trim();
    if (family == null || family.isEmpty) return null;
    return family.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
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
