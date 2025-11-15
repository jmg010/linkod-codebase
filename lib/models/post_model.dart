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
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'title': title,
      'content': content,
      'category': category.name,
      'createdAt': createdAt.toIso8601String(),
      'imageUrls': imageUrls,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
    };
  }

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String,
      category: PostCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => PostCategory.health,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      likesCount: json['likesCount'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
    );
  }
}
