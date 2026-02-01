import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

class AnnouncementsService {
  static final CollectionReference _announcementsCollection =
      FirestoreService.instance.collection('announcements');
  static final CollectionReference _readsCollection =
      FirestoreService.instance.collection('userAnnouncementReads');

  /// Get all announcements ordered by date
  static Stream<List<Map<String, dynamic>>> getAnnouncementsStream() {
    return _announcementsCollection
        .snapshots()
        .map((snapshot) {
          final announcements = snapshot.docs
              .map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    // Filter by status and isActive in code to avoid index requirement
                    final status = data['status'] as String? ?? '';
                    final isActive = data['isActive'] as bool? ?? true;
                    if (status != 'published' || !isActive) return null;
                    return {
                      'id': doc.id,
                      ...data,
                      'date': FirestoreService.parseTimestamp(data['date'] ?? data['createdAt']),
                      'createdAt': FirestoreService.parseTimestamp(data['createdAt']),
                      'updatedAt': data['updatedAt'] != null
                          ? FirestoreService.parseTimestamp(data['updatedAt'])
                          : null,
                    };
                  })
              .whereType<Map<String, dynamic>>()
              .toList();
          // Sort by createdAt descending in code
          announcements.sort((a, b) {
            final aTime = a['createdAt'] as DateTime? ?? DateTime.now();
            final bTime = b['createdAt'] as DateTime? ?? DateTime.now();
            return bTime.compareTo(aTime);
          });
          return announcements;
        });
  }

  /// Get announcements filtered by user's categories
  static Stream<List<Map<String, dynamic>>> getAnnouncementsForUserStream(
    List<String> userCategories,
  ) {
    if (userCategories.isEmpty) {
      return getAnnouncementsStream();
    }
    
    // Normalize user categories to lowercase for comparison
    final normalizedUserCategories = userCategories.map((c) => c.trim().toLowerCase()).toSet();
    
    return _announcementsCollection
        .snapshots()
        .map((snapshot) {
          final announcements = snapshot.docs
              .map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    // Filter by status and isActive in code to avoid index requirement
                    final status = data['status'] as String? ?? '';
                    final isActive = data['isActive'] as bool? ?? true;
                    if (status != 'published' || !isActive) return null;
                    
                    // Filter by audiences in code to avoid index requirement
                    final audiences = data['audiences'] as List<dynamic>? ?? [];
                    final normalizedAudiences = audiences
                        .map((a) => (a as String?)?.trim().toLowerCase() ?? '')
                        .where((a) => a.isNotEmpty)
                        .toSet();
                    
                    // Check if any user category matches any announcement audience
                    final hasMatchingAudience = normalizedUserCategories
                        .any((userCat) => normalizedAudiences.contains(userCat));
                    
                    if (!hasMatchingAudience) return null;
                    
                    return {
                      'id': doc.id,
                      ...data,
                      'date': FirestoreService.parseTimestamp(data['date'] ?? data['createdAt']),
                      'createdAt': FirestoreService.parseTimestamp(data['createdAt']),
                      'updatedAt': data['updatedAt'] != null
                          ? FirestoreService.parseTimestamp(data['updatedAt'])
                          : null,
                    };
                  })
              .whereType<Map<String, dynamic>>()
              .toList();
          // Sort by createdAt descending in code
          announcements.sort((a, b) {
            final aTime = a['createdAt'] as DateTime? ?? DateTime.now();
            final bTime = b['createdAt'] as DateTime? ?? DateTime.now();
            return bTime.compareTo(aTime);
          });
          return announcements;
        });
  }

  /// Mark announcement as read and increment view count
  static Future<void> markAsRead(String announcementId, String userId) async {
    // Check if already read
    final existingRead = await _readsCollection
        .where('userId', isEqualTo: userId)
        .where('announcementId', isEqualTo: announcementId)
        .get();
    
    if (existingRead.docs.isEmpty) {
      await _readsCollection.add({
        'userId': userId,
        'announcementId': announcementId,
        'readAt': FieldValue.serverTimestamp(),
      });
      
      // Increment view count for this announcement
      await _announcementsCollection.doc(announcementId).update({
        'viewCount': FieldValue.increment(1),
      });
    }
  }

  /// Increment view count (called when announcement is viewed)
  static Future<void> incrementViewCount(String announcementId) async {
    await _announcementsCollection.doc(announcementId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  /// Check if announcement is read by user
  static Future<bool> isReadByUser(String announcementId, String userId) async {
    final read = await _readsCollection
        .where('userId', isEqualTo: userId)
        .where('announcementId', isEqualTo: announcementId)
        .get();
    return read.docs.isNotEmpty;
  }

  /// Get read status for multiple announcements
  static Future<Set<String>> getReadAnnouncementIds(String userId) async {
    final reads = await _readsCollection
        .where('userId', isEqualTo: userId)
        .get();
    return reads.docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['announcementId'] as String;
        })
        .toSet();
  }
}
