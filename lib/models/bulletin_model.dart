import 'package:flutter/material.dart';
import 'bulletin_category_model.dart';

class BulletinModel {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final List<String> imageUrls; // Support for multiple images
  final String categoryId;
  final DateTime date;
  final String? location;
  final DateTime createdAt;
  final bool isPinned;
  final String? pdfUrl;
  final String? pdfName;

  const BulletinModel({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.imageUrls = const [],
    required this.categoryId,
    required this.date,
    this.location,
    required this.createdAt,
    this.isPinned = false,
    this.pdfUrl,
    this.pdfName,
  });

  // Get the category model for this bulletin
  BulletinCategoryModel? get category {
    return BulletinCategoryModel.getById(categoryId);
  }

  // Get all image URLs (combines single imageUrl and imageUrls list, avoiding duplicates)
  List<String> get allImageUrls {
    final urls = <String>[];
    // Add imageUrl only if it's not empty and not already in imageUrls
    if (imageUrl != null && imageUrl!.isNotEmpty && !imageUrls.contains(imageUrl)) {
      urls.add(imageUrl!);
    }
    // Add all non-empty URLs from imageUrls list
    urls.addAll(imageUrls.where((url) => url.isNotEmpty));
    return urls;
  }

  bool get hasImages => allImageUrls.isNotEmpty;
  bool get hasPdf => pdfUrl != null && pdfUrl!.isNotEmpty;

  factory BulletinModel.fromJson(Map<String, dynamic> json) {
    final imageUrls = (json['imageUrls'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];
    
    return BulletinModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      imageUrls: imageUrls,
      categoryId: json['categoryId'] as String? ?? '',
      date: json['date'] is DateTime
          ? json['date'] as DateTime
          : DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      location: json['location'] as String?,
      createdAt: json['createdAt'] is DateTime
          ? json['createdAt'] as DateTime
          : DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      isPinned: json['isPinned'] as bool? ?? false,
      pdfUrl: json['pdfUrl'] as String?,
      pdfName: json['pdfName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'categoryId': categoryId,
      'date': date.toIso8601String(),
      'location': location,
      'createdAt': createdAt.toIso8601String(),
      'isPinned': isPinned,
      'pdfUrl': pdfUrl,
      'pdfName': pdfName,
    };
  }
}
