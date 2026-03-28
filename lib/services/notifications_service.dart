import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class NotificationsService {
  static final CollectionReference _notificationsCollection = FirestoreService
      .instance
      .collection('notifications');

  /// Get notifications for a user
  static Stream<List<Map<String, dynamic>>> getUserNotificationsStream(
    String userId,
  ) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {
                  'notificationId': doc.id,
                  ...data,
                  'createdAt': FirestoreService.parseTimestamp(
                    data['createdAt'],
                  ),
                };
              }).toList(),
        );
  }

  /// Get unread notifications count
  static Stream<int> getUnreadCountStream(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Real-time stream of the latest unread notification for a user.
  static Stream<Map<String, dynamic>?> getLatestUnreadNotificationStream(
    String userId,
  ) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          final data = doc.data() as Map<String, dynamic>;
          return {
            'notificationId': doc.id,
            ...data,
            'createdAt': FirestoreService.parseTimestamp(data['createdAt']),
          };
        });
  }

  /// Stream of unread badge count from the user document.
  static Stream<int> getUnreadBadgeStream(String userId) {
    return FirestoreService.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
          final data = doc.data();
          if (data == null) return 0;
          final value = data['unreadNotificationCount'];
          if (value is int) return value;
          if (value is num) return value.toInt();
          return 0;
        });
  }

  /// Stream of unread volunteer_accepted notifications count.
  /// Used for Interacted Posts tab badge when user is assigned to a task.
  static Stream<int> getVolunteerAcceptedUnreadCountStream(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'volunteer_accepted')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Stream of unread task_volunteer notifications count.
  /// Used as a safety fallback for owner errand badges.
  static Stream<int> getTaskVolunteerUnreadCountStream(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'task_volunteer')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Stream of unread task chat notifications count.
  static Stream<int> getTaskChatUnreadCountStream(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'task_chat_message')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Stream of unread task_approved notifications count.
  static Stream<int> getTaskApprovedUnreadCountStream(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'task_approved')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Stream of unread errand-related notifications.
  /// Used for Job/Errands nav badge as a safety source so badge stays visible
  /// whenever unread errand notifications exist.
  static Stream<int> getUnreadErrandActivityCountStream(String userId) {
    const errandTypes = <String>{
      'task_volunteer',
      'volunteer_accepted',
      'task_chat_message',
      'task_approved',
    };

    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final type = data['type'] as String?;
            if (type == null) return false;
            if (errandTypes.contains(type)) return true;

            // Legacy fallback: task-linked notifications should count.
            final hasTaskId = (data['taskId'] as String?)?.isNotEmpty ?? false;
            return hasTaskId;
          }).length;
        });
  }

  /// Stream of unread marketplace interaction notifications.
  /// Includes comments/messages/replies related to products.
  static Stream<int> getUnreadMarketplaceActivityCountStream(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final hasProductId =
                (data['productId'] as String?)?.isNotEmpty ?? false;

            // Treat any unread notification linked to a product as marketplace activity.
            if (hasProductId) return true;

            // Keep product approval notifications in marketplace badge even
            // when productId is missing in legacy documents.
            final type = data['type'] as String?;
            return type == 'product_approved';
          }).length;
        });
  }

  /// Mark unread marketplace notifications as read for a specific product.
  static Future<void> markMarketplaceActivityAsReadByProduct(
    String userId,
    String productId,
  ) async {
    final notifications =
        await _notificationsCollection
            .where('userId', isEqualTo: userId)
            .where('productId', isEqualTo: productId)
            .where('isRead', isEqualTo: false)
            .get();

    if (notifications.docs.isEmpty) return;

    final batch = FirestoreService.instance.batch();
    int unreadCount = 0;

    for (final doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
      unreadCount++;
    }

    if (unreadCount == 0) return;

    final userRef = FirestoreService.instance.collection('users').doc(userId);
    batch.set(userRef, {
      'unreadNotificationCount': FieldValue.increment(-unreadCount),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Mark volunteer_accepted notifications as read for a specific task.
  /// Called when user opens a task from Interacted Posts to clear the badge.
  static Future<void> markVolunteerAcceptedAsReadByTask(
    String userId,
    String taskId,
  ) async {
    final notifications =
        await _notificationsCollection
            .where('userId', isEqualTo: userId)
            .where('type', isEqualTo: 'volunteer_accepted')
            .where('taskId', isEqualTo: taskId)
            .where('isRead', isEqualTo: false)
            .get();

    if (notifications.docs.isEmpty) return;

    final batch = FirestoreService.instance.batch();
    int unreadCount = 0;

    for (final doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
      unreadCount++;
    }

    await batch.commit();

    // Decrement unreadNotificationCount on user document
    if (unreadCount > 0) {
      final userRef = FirestoreService.instance.collection('users').doc(userId);
      await userRef.set({
        'unreadNotificationCount': FieldValue.increment(-unreadCount),
      }, SetOptions(merge: true));
    }
  }

  /// Mark task_volunteer notifications as read for a specific task.
  /// Called when task owner views volunteer requests.
  static Future<void> markTaskVolunteerAsReadByTask(
    String userId,
    String taskId,
  ) async {
    final notifications =
        await _notificationsCollection
            .where('userId', isEqualTo: userId)
            .where('type', isEqualTo: 'task_volunteer')
            .where('taskId', isEqualTo: taskId)
            .where('isRead', isEqualTo: false)
            .get();

    if (notifications.docs.isEmpty) return;

    final batch = FirestoreService.instance.batch();
    int unreadCount = 0;

    for (final doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
      unreadCount++;
    }

    await batch.commit();

    if (unreadCount > 0) {
      final userRef = FirestoreService.instance.collection('users').doc(userId);
      await userRef.set({
        'unreadNotificationCount': FieldValue.increment(-unreadCount),
      }, SetOptions(merge: true));
    }
  }

  /// Mark task_chat_message notifications as read for a specific task.
  static Future<void> markTaskChatAsReadByTask(
    String userId,
    String taskId,
  ) async {
    final notifications =
        await _notificationsCollection
            .where('userId', isEqualTo: userId)
            .where('type', isEqualTo: 'task_chat_message')
            .where('taskId', isEqualTo: taskId)
            .where('isRead', isEqualTo: false)
            .get();

    if (notifications.docs.isEmpty) return;

    final batch = FirestoreService.instance.batch();
    int unreadCount = 0;

    for (final doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
      unreadCount++;
    }

    await batch.commit();

    if (unreadCount > 0) {
      final userRef = FirestoreService.instance.collection('users').doc(userId);
      await userRef.set({
        'unreadNotificationCount': FieldValue.increment(-unreadCount),
      }, SetOptions(merge: true));
    }
  }

  /// Mark notification as read and decrement unreadNotificationCount atomically.
  static Future<void> markAsRead(String notificationId) async {
    final docRef = _notificationsCollection.doc(notificationId);
    await FirestoreService.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final isRead = data['isRead'] as bool? ?? false;
      if (isRead) return;
      final userId = data['userId'] as String?;
      tx.update(docRef, {'isRead': true});
      if (userId != null) {
        final userRef = FirestoreService.instance
            .collection('users')
            .doc(userId);
        tx.set(userRef, {
          'unreadNotificationCount': FieldValue.increment(-1),
        }, SetOptions(merge: true));
      }
    });
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead(String userId) async {
    final unread =
        await _notificationsCollection
            .where('userId', isEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .get();

    if (unread.docs.isEmpty) {
      await FirestoreService.instance.collection('users').doc(userId).set({
        'unreadNotificationCount': 0,
      }, SetOptions(merge: true));
      return;
    }

    final batch = FirestoreService.instance.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    final userRef = FirestoreService.instance.collection('users').doc(userId);
    batch.set(userRef, {'unreadNotificationCount': 0}, SetOptions(merge: true));
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
