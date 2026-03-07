import 'package:flutter/material.dart';
import 'bulletin_category_model.dart';

class BulletinModel {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String categoryId;
  final DateTime date;
  final String? location;
  final DateTime createdAt;
  final bool isPinned;

  const BulletinModel({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.categoryId,
    required this.date,
    this.location,
    required this.createdAt,
    this.isPinned = false,
  });

  // Get the category model for this bulletin
  BulletinCategoryModel? get category {
    return BulletinCategoryModel.getById(categoryId);
  }

  factory BulletinModel.fromJson(Map<String, dynamic> json) {
    return BulletinModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      categoryId: json['categoryId'] as String? ?? '',
      date: json['date'] is DateTime
          ? json['date'] as DateTime
          : DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      location: json['location'] as String?,
      createdAt: json['createdAt'] is DateTime
          ? json['createdAt'] as DateTime
          : DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'categoryId': categoryId,
      'date': date.toIso8601String(),
      'location': location,
      'createdAt': createdAt.toIso8601String(),
      'isPinned': isPinned,
    };
  }
}
