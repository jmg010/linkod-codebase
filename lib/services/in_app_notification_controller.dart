import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

import 'firestore_service.dart';
import 'notifications_service.dart';
import 'current_post_tracker.dart';
import 'push_notification_handler.dart';

/// Listens to Firestore notifications for the current user and shows a
/// lightweight in-app banner when a new unread notification arrives.
class InAppNotificationController {
  InAppNotificationController(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;

  StreamSubscription? _authSub;
  StreamSubscription? _notificationSub;
  String? _lastNotificationId;

  void start() {
    // React to login/logout.
    _authSub ??=
        FirestoreService.auth.authStateChanges().listen(_handleAuthChange);

    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser != null && _notificationSub == null) {
      _attachNotificationStream(currentUser.uid);
    }
  }

  void dispose() {
    _authSub?.cancel();
    _notificationSub?.cancel();
  }

  void _handleAuthChange(User? user) {
    _notificationSub?.cancel();
    _notificationSub = null;
    _lastNotificationId = null;

    if (user == null) return;
    _attachNotificationStream(user.uid);
  }

  void _attachNotificationStream(String userId) {
    debugPrint('Attaching notification stream for user: $userId');
    _notificationSub = NotificationsService
        .getLatestUnreadNotificationStream(userId)
        .listen(
          _onNotification,
          onError: (error) => debugPrint('Notification stream error: $error'),
        );
  }

  void _onNotification(Map<String, dynamic>? notification) {
    debugPrint('Received notification: $notification');
    if (notification == null) {
      debugPrint('Notification is null, skipping');
      return;
    }

    final notificationId = notification['notificationId'] as String?;
    if (notificationId != null && notificationId == _lastNotificationId) {
      // Avoid duplicate banners for the same document.
      debugPrint('Duplicate notification detected: $notificationId');
      return;
    }
    _lastNotificationId = notificationId;

    final postId = notification['postId'] as String?;
    if (postId != null &&
        postId.isNotEmpty &&
        CurrentPostTracker.currentPostId.value == postId) {
      // Do not show banner if user is already viewing this post.
      debugPrint('User is viewing post $postId, skipping notification');
      return;
    }

    final message =
        notification['message'] as String? ?? 'New activity on your post';
    debugPrint('Showing in-app notification: $message');

    // Defer to next frame so OverlaySupport overlay is mounted and visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final id = notification['notificationId'] as String?;
          if (id != null) {
            NotificationsService.markAsRead(id);
          }
          // Build a string-only payload so navigation always gets valid ids.
          final payload = <String, dynamic>{
            'type': notification['type']?.toString(),
            'postId': notification['postId']?.toString(),
            'commentId': notification['commentId']?.toString(),
            'productId': notification['productId']?.toString(),
            'taskId': notification['taskId']?.toString(),
            'announcementId': notification['announcementId']?.toString(),
          };
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PushNotificationHandler.handleNotificationNavigation(
              navigatorKey,
              payload,
            );
          });
        },
        child: _buildRoundedBanner(message),
      );

      showSimpleNotification(
        content,
        position: NotificationPosition.top,
        background: Colors.transparent,
        autoDismiss: true,
        slideDismissDirection: DismissDirection.up,
        duration: const Duration(seconds: 4),
        elevation: 0,
      );
    });
  }

  Widget _buildRoundedBanner(String message) {
    // Banner height increased by ~30%: more padding and slightly larger text/icon
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Row(
            children: [
              const Icon(Icons.notifications, color: Colors.green, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

