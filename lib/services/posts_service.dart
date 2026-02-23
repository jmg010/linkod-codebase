import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import 'firestore_service.dart';

class PostsService {
  static final CollectionReference _postsCollection =
      FirestoreService.instance.collection('posts');

  /// Get all posts ordered by creation date
  static Stream<List<PostModel>> getPostsStream() {
    return _postsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .where((post) => post.isActive) // Filter in code to avoid index requirement
            .toList());
  }

  /// Get posts by category
  static Stream<List<PostModel>> getPostsByCategoryStream(PostCategory category) {
    return _postsCollection
        .where('category', isEqualTo: category.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .where((post) => post.isActive) // Filter in code
            .toList());
  }

  /// Get posts by user
  static Stream<List<PostModel>> getUserPostsStream(String userId) {
    return _postsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .where((post) => post.isActive) // Filter in code
            .toList());
  }

  /// Create a new post
  static Future<String> createPost(PostModel post) async {
    final docRef = await _postsCollection.add(post.toJson());
    return docRef.id;
  }

  /// Update a post
  static Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    await _postsCollection.doc(postId).update(updates);
  }

  /// Delete a post (soft delete by setting isActive to false)
  static Future<void> deletePost(String postId) async {
    await _postsCollection.doc(postId).update({'isActive': false});
  }

  /// Like a post
  static Future<void> likePost(String postId, String userId, String userName) async {
    final likesRef = _postsCollection.doc(postId).collection('likes');
    
    // Check if already liked
    final existingLike = await likesRef.where('userId', isEqualTo: userId).get();
    if (existingLike.docs.isNotEmpty) {
      // Unlike: remove the like
      await likesRef.doc(existingLike.docs.first.id).delete();
      // Decrement likesCount
      await _postsCollection.doc(postId).update({
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      // Like: add the like
      await likesRef.add({
        'userId': userId,
        'userName': userName,
        'likedAt': FieldValue.serverTimestamp(),
      });
      // Increment likesCount
      await _postsCollection.doc(postId).update({
        'likesCount': FieldValue.increment(1),
      });
    }
  }

  /// Check if user has liked a post
  static Future<bool> hasUserLikedPost(String postId, String userId) async {
    final likesRef = _postsCollection.doc(postId).collection('likes');
    final like = await likesRef.where('userId', isEqualTo: userId).get();
    return like.docs.isNotEmpty;
  }

  /// Add a comment to a post
  static Future<String> addComment(
    String postId,
    String userId,
    String userName,
    String content,
  ) async {
    final commentsRef = _postsCollection.doc(postId).collection('comments');
    final docRef = await commentsRef.add({
      'userId': userId,
      'userName': userName,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isEdited': false,
      'isDeleted': false,
    });
    
    // Increment commentsCount
    await _postsCollection.doc(postId).update({
      'commentsCount': FieldValue.increment(1),
    });
    
    return docRef.id;
  }

  /// Get a single post by ID (e.g. for notification deep link).
  static Future<PostModel?> getPostById(String postId) async {
    final doc = await _postsCollection.doc(postId).get();
    if (!doc.exists) return null;
    try {
      return PostModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Get comments for a post
  static Stream<List<Map<String, dynamic>>> getCommentsStream(String postId) {
    return _postsCollection
        .doc(postId)
        .collection('comments')
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return <String, dynamic>{
                    'commentId': doc.id,
                    ...data,
                    'createdAt': FirestoreService.parseTimestamp(data['createdAt']),
                  };
                })
            .toList());
  }

  /// Mark post comments as read by this user (e.g. when post owner opens the post).
  static Future<void> markPostCommentsAsRead(String postId, String userId) async {
    await _postsCollection
        .doc(postId)
        .collection('comment_read')
        .doc(userId)
        .set({'lastReadAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  /// Unread = comments by others (userId != ownerUserId) after lastReadAt.
  static Stream<int> getUnreadCommentsCountForPostStream(String postId, String ownerUserId) {
    return getCommentsStream(postId).asyncMap((comments) async {
      try {
        final readDoc = await _postsCollection
            .doc(postId)
            .collection('comment_read')
            .doc(ownerUserId)
            .get();
        final data = readDoc.data() as Map<String, dynamic>?;
        final lastReadAt = data?['lastReadAt'] != null
            ? (data!['lastReadAt'] is Timestamp)
                ? (data['lastReadAt'] as Timestamp).toDate()
                : DateTime(1970)
            : DateTime(1970);
        return comments
            .where((c) {
              final commentUserId = c['userId'] as String? ?? '';
              final createdAt = c['createdAt'] as DateTime? ?? DateTime(1970);
              return commentUserId != ownerUserId && createdAt.isAfter(lastReadAt);
            })
            .length;
      } catch (_) {
        return 0;
      }
    });
  }

  /// Total unread comment count across all posts owned by this user.
  static Stream<int> getTotalUnreadCommentsOnMyPostsStream(String ownerUserId) {
    return getUserPostsStream(ownerUserId).asyncMap((posts) async {
      try {
        int total = 0;
        for (final p in posts) {
          total += await getUnreadCommentsCountForPostStream(p.id, ownerUserId).first;
        }
        return total;
      } catch (_) {
        return 0;
      }
    });
  }
}
