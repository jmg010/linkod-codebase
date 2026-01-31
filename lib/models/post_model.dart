import 'package:cloud_firestore/cloud_firestore.dart';

enum PostCategory {
  health('Health'),
  livelihood('Livelihood'),
  youthActivity('Youth Activity');

  const PostCategory(this.displayName);
  final String displayName;
}

class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String title;
  final String content;
  final PostCategory category;
  final DateTime createdAt;
  final List<String> imageUrls;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isAnnouncement;
  final bool isActive;

  PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.title,
    required this.content,
    required this.category,
    required this.createdAt,
    this.imageUrls = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.isAnnouncement = false,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'title': title,
      'content': content,
      'category': category.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'imageUrls': imageUrls,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'isAnnouncement': isAnnouncement,
      'isActive': isActive,
    };
  }

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      category: PostCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => PostCategory.health,
      ),
      createdAt: _parseTimestamp(json['createdAt']),
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      sharesCount: (json['sharesCount'] as num?)?.toInt() ?? 0,
      isAnnouncement: json['isAnnouncement'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  // Helper to parse Firestore Timestamp or ISO string
  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  // Factory method for Firestore documents
  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }
}
