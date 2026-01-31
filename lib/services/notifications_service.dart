import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class NotificationsService {
  static final CollectionReference _notificationsCollection =
      FirestoreService.instance.collection('notifications');

  /// Get notifications for a user
  static Stream<List<Map<String, dynamic>>> getUserNotificationsStream(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    'notificationId': doc.id,
                    ...data,
                    'createdAt': FirestoreService.parseTimestamp(data['createdAt']),
                  };
                })
            .toList());
  }

  /// Get unread notifications count
  static Stream<int> getUnreadCountStream(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    await _notificationsCollection.doc(notificationId).update({
      'isRead': true,
    });
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead(String userId) async {
    final unread = await _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    
    final batch = FirestoreService.instance.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Create a notification
  static Future<String> createNotification({
    required String userId,
    required String type,
    required String message,
    String? taskId,
    String? productId,
    String? postId,
    String? announcementId,
  }) async {
    final docRef = await _notificationsCollection.add({
      'userId': userId,
      'type': type,
      'message': message,
      'taskId': taskId,
      'productId': productId,
      'postId': postId,
      'announcementId': announcementId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }
}
