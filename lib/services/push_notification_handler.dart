import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/product_model.dart';
import '../models/task_model.dart';
import '../screens/announcement_detail_screen.dart';
import '../screens/login_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/task_detail_screen.dart';
import 'firestore_service.dart';

/// Handles incoming FCM messages: shows a notification when in foreground and
/// navigates to announcement detail when user taps (using data payload announcementId).
/// Backend sends notifications with data payload { announcementId: "<id>" }.
class PushNotificationHandler {
  PushNotificationHandler(this._navigatorKey);

  final GlobalKey<NavigatorState> _navigatorKey;
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'linkod_announcements',
    'Announcements',
    description: 'Barangay announcement notifications',
    importance: Importance.defaultImportance,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Call after Firebase is initialized. Sets up foreground display and tap handling.
  /// No-op on web/desktop so the app does not depend on FCM there.
  Future<void> setup() async {
    if (_initialized) return;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    // Foreground: show a local notification so user sees it; tap uses payload.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Background/terminated: user tapped the system notification; navigate.
    FirebaseMessaging.onMessageOpenedApp.listen(_navigateFromMessage);

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    if (payload == 'account_approved') {
      _navigateToLoginClearStack();
      return;
    }

    // Payload format: "announcement:abc123" or "post:xyz789"
    if (payload.startsWith('announcement:')) {
      final id = payload.substring('announcement:'.length);
      if (id.isNotEmpty) {
        _pushAnnouncementDetail(id);
      }
    } else if (payload.startsWith('post:')) {
      final id = payload.substring('post:'.length);
      if (id.isNotEmpty) {
        _pushPostDetail(id);
      }
    } else {
      // Fallback: try as announcementId (for backward compatibility)
      _pushAnnouncementDetail(payload);
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final type = message.data['type'] as String?;
    if (type == 'account_approved') {
      final title = message.notification?.title ?? 'Account Approved';
      final body = message.notification?.body ??
          'Your account has been approved. You can now sign in.';
      _localNotifications.show(
        message.hashCode % 0x7FFFFFFF,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: 'account_approved',
      );
      return;
    }

    final announcementId = message.data['announcementId'] as String?;
    final postId = message.data['postId'] as String?;
    String? payload;
    String? contentType;

    if (announcementId != null && announcementId.isNotEmpty) {
      payload = 'announcement:$announcementId';
      contentType = 'announcement';
    } else if (postId != null && postId.isNotEmpty) {
      payload = 'post:$postId';
      contentType = 'post';
    }

    if (payload == null || payload.isEmpty) return;

    final title = message.notification?.title ??
        (contentType == 'announcement' ? 'Announcement' : 'Post');
    final body = message.notification?.body ??
        (contentType == 'announcement' ? 'New announcement' : 'New post');

    _localNotifications.show(
      message.hashCode % 0x7FFFFFFF,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  void _navigateFromMessage(RemoteMessage message) {
    if (message.data['type'] == 'account_approved') {
      _navigateToLoginClearStack();
      return;
    }
    final announcementId = message.data['announcementId'] as String?;
    final postId = message.data['postId'] as String?;
    if (announcementId != null && announcementId.isNotEmpty) {
      _pushAnnouncementDetail(announcementId);
    } else if (postId != null && postId.isNotEmpty) {
      _pushPostDetail(postId);
    }
  }

  /// Clears the navigation stack and shows LoginScreen (e.g. after account_approved tap).
  void _navigateToLoginClearStack() {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _pushAnnouncementDetail(String announcementId) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnnouncementDetailScreen(announcementId: announcementId),
      ),
    );
  }

  void _pushPostDetail(String postId) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailScreen(postId: postId),
      ),
    );
  }

  /// Shared navigation handler for in-app notifications (Firestore-driven) and
  /// data payloads (when needed).
  static Future<void> handleNotificationNavigation(
    GlobalKey<NavigatorState> navigatorKey,
    Map<String, dynamic> data,
  ) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final String? postId = data['postId'] as String?;
    final String? commentId = data['commentId'] as String?;
    final String? announcementId = data['announcementId'] as String?;
    final String? productId = data['productId'] as String?;
    final String? taskId = data['taskId'] as String?;
    final String? type = data['type'] as String?;

    if (type == 'comment' || type == 'reply' || type == 'like') {
      if (postId == null || postId.isEmpty) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PostDetailScreen(
            postId: postId,
            openCommentsOnLoad: type == 'comment' || type == 'reply',
            initialCommentId: commentId,
          ),
        ),
      );
      return;
    }

    if (taskId != null && taskId.isNotEmpty) {
      try {
        final snap =
            await FirestoreService.instance.collection('tasks').doc(taskId).get();
        if (!snap.exists) return;
        final task = TaskModel.fromFirestore(snap);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TaskDetailScreen(
              task: task,
              contactNumber: task.contactNumber,
            ),
          ),
        );
      } catch (_) {}
      return;
    }

    if (productId != null && productId.isNotEmpty) {
      try {
        final snap = await FirestoreService.instance
            .collection('products')
            .doc(productId)
            .get();
        if (!snap.exists) return;
        final product = ProductModel.fromFirestore(snap);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        );
      } catch (_) {}
      return;
    }

    if (announcementId != null && announcementId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AnnouncementDetailScreen(announcementId: announcementId),
        ),
      );
    } else if (postId != null && postId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PostDetailScreen(postId: postId),
        ),
      );
    }
  }

  /// Call once after first frame so navigator is available. Handles app opened
  /// from terminated state via notification tap.
  static Future<void> handleInitialMessage(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message == null) return;
    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (message.data['type'] == 'account_approved') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      return;
    }

    final announcementId = message.data['announcementId'] as String?;
    final postId = message.data['postId'] as String?;
    if (announcementId != null && announcementId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AnnouncementDetailScreen(announcementId: announcementId),
        ),
      );
    } else if (postId != null && postId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PostDetailScreen(postId: postId),
        ),
      );
    }
  }
}
