import 'dart:convert';

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
import '../screens/task_edit_screen.dart';
import 'firestore_service.dart';
import 'notifications_service.dart';
import 'otp_service.dart';

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
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
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

    if (payload.startsWith('data:')) {
      final raw = payload.substring('data:'.length);
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          PushNotificationHandler.handleNotificationNavigation(
            _navigatorKey,
            decoded,
          );
          return;
        }
        if (decoded is Map) {
          PushNotificationHandler.handleNotificationNavigation(
            _navigatorKey,
            Map<String, dynamic>.from(decoded),
          );
          return;
        }
      } catch (_) {
        // fall through to legacy payload handling
      }
    }

    if (payload == 'account_approved') {
      _navigateToLoginClearStack();
      return;
    }
    if (payload.startsWith('product_approved:')) {
      final id = payload.substring('product_approved:'.length);
      if (id.isNotEmpty) {
        PushNotificationHandler.handleNotificationNavigation(_navigatorKey, {
          'type': 'product_approved',
          'productId': id,
        });
      }
      return;
    }
    if (payload.startsWith('task_approved:')) {
      final id = payload.substring('task_approved:'.length);
      if (id.isNotEmpty) {
        PushNotificationHandler.handleNotificationNavigation(_navigatorKey, {
          'type': 'task_approved',
          'taskId': id,
        });
      }
      return;
    }

    // Payload format: "announcement:abc123" or "post:postId" or "post:postId:commentId"
    if (payload.startsWith('announcement:')) {
      final id = payload.substring('announcement:'.length);
      if (id.isNotEmpty) {
        _pushAnnouncementDetail(id);
      }
    } else if (payload.startsWith('post:')) {
      final rest = payload.substring('post:'.length);
      final parts = rest.split(':');
      final id = parts.isNotEmpty ? parts[0] : '';
      final commentIdPart = parts.length >= 2 ? parts[1] : null;
      if (id.isNotEmpty) {
        if (commentIdPart != null && commentIdPart.isNotEmpty) {
          PushNotificationHandler.handleNotificationNavigation(_navigatorKey, {
            'type': 'comment',
            'postId': id,
            'commentId': commentIdPart,
          });
        } else {
          _pushPostDetail(id);
        }
      }
    } else {
      // Fallback: try as announcementId (for backward compatibility)
      _pushAnnouncementDetail(payload);
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final type = message.data['type'] as String?;

    // Handle OTP messages (data-only); show the code and disable autofill
    if (type == 'otp') {
      final otp = message.data['otp'] as String?;
      final phoneNumber = message.data['phoneNumber'] as String?;

      if (otp != null &&
          otp.isNotEmpty &&
          phoneNumber != null &&
          phoneNumber.isNotEmpty) {
        // Do NOT pass OTP to OtpService – user will type it manually

        // Show a notification with the actual 6‑digit code
        _localNotifications.show(
          'otp'.hashCode % 0x7FFFFFFF,
          'Your LINKod verification code',
          otp,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentSound: true,
              presentBadge: false,
            ),
          ),
          payload: 'otp:$phoneNumber',
        );
      }
      return;
    }

    if (type == 'account_approved') {
      final title = message.notification?.title ?? 'Account Approved';
      final body =
          message.notification?.body ??
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

    final productId = message.data['productId'] as String?;
    final taskId = message.data['taskId'] as String?;
    if (type == 'product_approved' &&
        productId != null &&
        productId.isNotEmpty) {
      _localNotifications.show(
        message.hashCode % 0x7FFFFFFF,
        message.notification?.title ?? 'Listing approved',
        message.notification?.body ?? 'Your marketplace listing was approved.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: 'product_approved:$productId',
      );
      return;
    }
    if (type == 'task_approved' && taskId != null && taskId.isNotEmpty) {
      _localNotifications.show(
        message.hashCode % 0x7FFFFFFF,
        message.notification?.title ?? 'Errand approved',
        message.notification?.body ?? 'Your errand was approved.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: 'task_approved:$taskId',
      );
      return;
    }

    final announcementId = message.data['announcementId'] as String?;
    final postId = message.data['postId'] as String?;
    final commentId = message.data['commentId'] as String?;
    String? payload;
    String? contentType;

    if (announcementId != null && announcementId.isNotEmpty) {
      payload = 'announcement:$announcementId';
      contentType = 'announcement';
    } else if (postId != null && postId.isNotEmpty) {
      // Include commentId when present so tap opens post with comments
      payload =
          (commentId != null && commentId.isNotEmpty)
              ? 'post:$postId:$commentId'
              : 'post:$postId';
      contentType = 'post';
    }

    // For interaction types (task/product/chat/reply/etc.), carry full data so
    // taps can use the shared navigation handler.
    if ((payload == null || payload.isEmpty) && message.data.isNotEmpty) {
      payload = 'data:${jsonEncode(message.data)}';
      contentType = 'notification';
    }

    if (payload == null || payload.isEmpty) return;

    final title =
        message.notification?.title ??
        (() {
          switch (type) {
            case 'task_volunteer':
              return 'New volunteer';
            case 'volunteer_accepted':
              return 'You were accepted';
            case 'task_chat_message':
              return 'New task message';
            case 'product_message':
              return 'New marketplace message';
            case 'reply':
              return 'New reply';
            case 'comment':
              return 'New comment';
            case 'like':
              return 'New like';
            default:
              return contentType == 'announcement'
                  ? 'Announcement'
                  : 'Notification';
          }
        })();
    final body =
        message.notification?.body ??
        (contentType == 'announcement'
            ? 'New announcement'
            : (type == 'task_volunteer'
                ? 'Someone volunteered for your errand.'
                : type == 'volunteer_accepted'
                ? 'You were accepted as volunteer.'
                : type == 'task_chat_message'
                ? 'You received a new errand chat message.'
                : type == 'product_message'
                ? 'You received a new marketplace message.'
                : 'You have a new notification.'));

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
    // Handle OTP tap: no autofill, just return so user can type it manually.
    if (message.data['type'] == 'otp') {
      // nothing to do here; the visible notification already shows the code
      // and the verification screen will expect manual entry.
      return;
    }

    if (message.data['type'] == 'account_approved') {
      _navigateToLoginClearStack();
      return;
    }
    final type = message.data['type'] as String?;
    if (type == 'product_approved' || type == 'task_approved') {
      final context = _navigatorKey.currentContext;
      if (context != null) {
        PushNotificationHandler.handleNotificationNavigation(
          _navigatorKey,
          Map<String, dynamic>.from(message.data),
        );
      }
      return;
    }
    final announcementId = message.data['announcementId'] as String?;
    final postId = message.data['postId'] as String?;
    final productId = message.data['productId'] as String?;
    final taskId = message.data['taskId'] as String?;
    if (announcementId != null && announcementId.isNotEmpty) {
      _pushAnnouncementDetail(announcementId);
      return;
    }
    if ((postId != null && postId.isNotEmpty) ||
        (productId != null && productId.isNotEmpty) ||
        (taskId != null && taskId.isNotEmpty)) {
      PushNotificationHandler.handleNotificationNavigation(
        _navigatorKey,
        Map<String, dynamic>.from(message.data),
      );
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
        builder:
            (_) => AnnouncementDetailScreen(announcementId: announcementId),
      ),
    );
  }

  void _pushPostDetail(String postId) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PostDetailScreen(postId: postId)),
    );
  }

  /// Shared navigation handler for in-app notifications (Firestore-driven) and
  /// data payloads (when needed). Ensures id fields are strings for reliability.
  static Future<void> handleNotificationNavigation(
    GlobalKey<NavigatorState> navigatorKey,
    Map<String, dynamic> data,
  ) async {
    final String? postId = _str(data['postId']);
    final String? commentId = _str(data['commentId']);
    final String? announcementId = _str(data['announcementId']);
    final String? productId = _str(data['productId']);
    final String? taskId = _str(data['taskId']);
    final String? type = _str(data['type']);
    final String? notificationId = _str(data['notificationId']);

    if (notificationId != null && notificationId.isNotEmpty) {
      try {
        await NotificationsService.markAsRead(notificationId);
      } catch (_) {
        // Non-blocking: navigation should continue even if read status update fails.
      }
    }

    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (type == 'comment' || type == 'reply' || type == 'like') {
      if (postId != null && postId.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder:
                (_) => PostDetailScreen(
                  postId: postId,
                  openCommentsOnLoad: type == 'comment' || type == 'reply',
                  initialCommentId: commentId,
                ),
          ),
        );
      }
      return;
    }

    if (taskId != null && taskId.isNotEmpty) {
      try {
        final snap =
            await FirestoreService.instance
                .collection('tasks')
                .doc(taskId)
                .get();
        if (snap.exists) {
          final task = TaskModel.fromFirestore(snap);
          final currentUid = FirestoreService.auth.currentUser?.uid;
          final isOwner = currentUid != null && currentUid == task.requesterId;
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) {
                // If the requester is tapping a "someone volunteered" notification,
                // deep-link to the owner management screen (accept/reject + messaging).
                if (isOwner && type == 'task_volunteer') {
                  return TaskEditScreen(
                    task: task,
                    contactNumber: task.contactNumber,
                  );
                }
                return TaskDetailScreen(
                  task: task,
                  contactNumber: task.contactNumber,
                );
              },
            ),
          );
        }
      } catch (_) {}
      return;
    }

    if (productId != null && productId.isNotEmpty) {
      try {
        final snap =
            await FirestoreService.instance
                .collection('products')
                .doc(productId)
                .get();
        if (snap.exists) {
          final product = ProductModel.fromFirestore(snap);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder:
                  (_) => ProductDetailScreen(
                    product: product,
                    notificationId: notificationId,
                  ),
            ),
          );
        }
      } catch (_) {}
      return;
    }

    if (announcementId != null && announcementId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder:
              (_) => AnnouncementDetailScreen(announcementId: announcementId),
        ),
      );
      return;
    }

    if (postId != null && postId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PostDetailScreen(postId: postId),
        ),
      );
    }
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v is String ? v : v.toString();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  /// Call once after first frame so navigator is available. Handles app opened
  /// from terminated state via notification tap.
  static Future<void> handleInitialMessage(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message == null) return;

    // Handle OTP from initial message
    if (message.data['type'] == 'otp') {
      final otp = message.data['otp'] as String?;
      final phoneNumber = message.data['phoneNumber'] as String?;

      if (otp != null &&
          otp.isNotEmpty &&
          phoneNumber != null &&
          phoneNumber.isNotEmpty) {
        OtpService.instance.handleOtpFromFcm(
          otp: otp,
          phoneNumber: phoneNumber,
        );
      }
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (message.data['type'] == 'account_approved') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      return;
    }

    final type = message.data['type'] as String?;
    if (type == 'product_approved' || type == 'task_approved') {
      await PushNotificationHandler.handleNotificationNavigation(
        navigatorKey,
        Map<String, dynamic>.from(message.data),
      );
      return;
    }

    final announcementId = message.data['announcementId'] as String?;
    final postId = message.data['postId'] as String?;
    final productId = message.data['productId'] as String?;
    final taskId = message.data['taskId'] as String?;
    if (announcementId != null && announcementId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder:
              (_) => AnnouncementDetailScreen(announcementId: announcementId),
        ),
      );
    } else if ((postId != null && postId.isNotEmpty) ||
        (productId != null && productId.isNotEmpty) ||
        (taskId != null && taskId.isNotEmpty)) {
      await PushNotificationHandler.handleNotificationNavigation(
        navigatorKey,
        Map<String, dynamic>.from(message.data),
      );
    }
  }
}
