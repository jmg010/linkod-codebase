import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../models/task_model.dart';
import '../screens/announcement_detail_screen.dart';
import '../screens/emergency_alert_setup_screen.dart';
import '../screens/announcement_priority_alert_screen.dart';
import '../screens/login_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/task_chat_screen.dart';
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
  static const MethodChannel _androidCapabilitiesChannel = MethodChannel(
    'linkod.notification_capabilities',
  );
  static const MethodChannel _androidOverlayChannel = MethodChannel(
    'linkod.overlay_control',
  );
  static const bool _enablePriorityOverlayDemoMode = false;
  static bool _overlayPermissionRequestedThisSession = false;
  static const String _emergencySetupPromptSeenKey =
      'emergency_alert_setup_prompt_seen';
  static const String _emergencySetupPromptDisabledKey =
      'emergency_alert_setup_prompt_disabled';
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'linkod_announcements',
    'Announcements',
    description: 'Barangay announcement notifications',
    importance: Importance.defaultImportance,
  );
  static const AndroidNotificationChannel _priorityChannel =
      AndroidNotificationChannel(
        'linkod_announcements_priority',
        'Priority Announcements',
        description: 'High-priority barangay announcement alerts',
        importance: Importance.high,
      );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static final Map<String, DateTime> _recentForegroundNotifKeys =
      <String, DateTime>{};
  static String? _pendingLocalNotificationPayload;

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

    final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        _pendingLocalNotificationPayload = payload;
      }
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_priorityChannel);

      if (_enablePriorityOverlayDemoMode) {
        unawaited(_ensureOverlayPermissionForDemo());
      }
    }

    // We always render our own local notification for foreground messages.
    // Disable OS foreground presentation to avoid showing two notifications.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );

    // Foreground: show a local notification so user sees it; tap uses payload.
    FirebaseMessaging.onMessage.listen((message) {
      unawaited(_showForegroundNotification(message));
    });

    // Background/terminated: user tapped the system notification; navigate.
    FirebaseMessaging.onMessageOpenedApp.listen(_navigateFromMessage);

    _initialized = true;
  }

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    if (!_isPriorityAnnouncement(message)) {
      return;
    }

    final data = Map<String, dynamic>.from(message.data);
    final canDrawOverlay = await _canDrawOverlay();
    final canUseFullScreenIntent = await _canUseFullScreenIntentStatic();

    _logPriorityDeliveryEvent(
      'priority_background_received',
      data: <String, dynamic>{
        'announcementId': _dataString(data, 'announcementId'),
        'canDrawOverlay': canDrawOverlay,
        'canUseFullScreenIntent': canUseFullScreenIntent,
      },
    );

    if (_enablePriorityOverlayDemoMode && canDrawOverlay) {
      final shown = await _tryShowPriorityAnnouncementOverlay(data);
      if (shown) {
        _logPriorityDeliveryEvent(
          'priority_overlay_shown',
          data: <String, dynamic>{
            'announcementId': _dataString(data, 'announcementId'),
          },
        );
        return;
      }
      _logPriorityDeliveryEvent(
        'priority_overlay_failed',
        data: <String, dynamic>{
          'announcementId': _dataString(data, 'announcementId'),
        },
      );
    } else {
      _logPriorityDeliveryEvent(
        'priority_overlay_skipped',
        data: <String, dynamic>{
          'announcementId': _dataString(data, 'announcementId'),
          'reason': !_enablePriorityOverlayDemoMode
              ? 'overlay_mode_disabled'
              : 'overlay_permission_missing',
        },
      );
    }

    await _showPriorityAnnouncementLocalNotification(
      message,
      fullScreenIntent: canUseFullScreenIntent,
    );

    if (canUseFullScreenIntent) {
      _logPriorityDeliveryEvent(
        'priority_fullscreen_used',
        data: <String, dynamic>{
          'announcementId': _dataString(data, 'announcementId'),
        },
      );
    } else {
      _logPriorityDeliveryEvent(
        'priority_heads_up_only',
        data: <String, dynamic>{
          'announcementId': _dataString(data, 'announcementId'),
        },
      );
    }
  }

  static Future<bool> _canDrawOverlay() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      return await _androidOverlayChannel.invokeMethod<bool>('canDrawOverlay') ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _canUseFullScreenIntentStatic() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      final result = await _androidCapabilitiesChannel.invokeMethod<bool>(
        'canUseFullScreenIntent',
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static void _logPriorityDeliveryEvent(
    String event, {
    Map<String, dynamic>? data,
  }) {
    final suffix = (data == null || data.isEmpty) ? '' : ' | ${jsonEncode(data)}';
    debugPrint('[priority-alert] $event$suffix');
  }

  static Future<bool> _tryShowPriorityAnnouncementOverlay(
    Map<String, dynamic> data,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    final announcementId = _dataString(data, 'announcementId');
    if (announcementId == null) {
      return false;
    }

    try {
      final result = await _androidOverlayChannel.invokeMethod<bool>(
        'showAnnouncementOverlay',
        <String, dynamic>{
          'announcementId': announcementId,
          'title': _dataString(data, 'title') ?? 'Barangay Announcement',
          'body': _dataString(data, 'body') ?? 'New barangay announcement.',
          'type': _dataString(data, 'type') ?? 'announcement',
          'priority': _dataString(data, 'priority') ?? 'high',
          'alertStyle': _dataString(data, 'alertStyle') ?? 'announcement_priority',
          'attemptFullScreen': _dataString(data, 'attemptFullScreen') ?? 'true',
        },
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _ensureOverlayPermissionForDemo() async {
    if (_overlayPermissionRequestedThisSession) {
      return;
    }
    _overlayPermissionRequestedThisSession = true;

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final granted =
          await _androidOverlayChannel.invokeMethod<bool>('canDrawOverlay') ?? false;
      if (!granted) {
        await _androidOverlayChannel.invokeMethod<bool>('requestOverlayPermission');
      }
    } catch (_) {
      // Keep notification fallback when overlay permission bridge is unavailable.
    }
  }

  Future<void> maybePromptEmergencyAlertSetup() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final isDisabled = prefs.getBool(_emergencySetupPromptDisabledKey) ?? false;
    if (isDisabled) return;

    final alreadyPrompted = prefs.getBool(_emergencySetupPromptSeenKey) ?? false;
    if (alreadyPrompted) return;

    final hasNotificationPermission =
        await _hasNotificationPermissionForAndroid();
    final canDrawOverlay = await _canDrawOverlay();
    final canUseFullScreenIntent = await _canUseFullScreenIntentStatic();

    final setupComplete =
        hasNotificationPermission && canDrawOverlay && canUseFullScreenIntent;
    if (setupComplete) {
      await prefs.setBool(_emergencySetupPromptSeenKey, true);
      return;
    }

    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Enable Emergency Alerts'),
            content: const Text(
              'To maximize emergency alert visibility, complete emergency alert setup.',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await prefs.setBool(_emergencySetupPromptDisabledKey, true);
                  await prefs.setBool(_emergencySetupPromptSeenKey, true);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop('never');
                  }
                },
                child: const Text('Don\'t show again'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop('later');
                },
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  final routeContext = _navigatorKey.currentContext;
                  if (routeContext == null) return;
                  unawaited(
                    prefs.setBool(_emergencySetupPromptSeenKey, true),
                  );
                  Navigator.of(routeContext).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EmergencyAlertSetupScreen(),
                    ),
                  );
                },
                child: const Text('Configure now'),
              ),
            ],
          ),
    );

    if (choice == 'later') {
      await prefs.setBool(_emergencySetupPromptSeenKey, false);
    }
  }

  static Future<bool> _hasNotificationPermissionForAndroid() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  static Future<void> handleInitialOverlayLaunch(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final payloadJson = await _androidOverlayChannel.invokeMethod<String>(
        'getInitialOverlayPayload',
      );
      if (payloadJson == null || payloadJson.isEmpty) {
        return;
      }
      final decoded = jsonDecode(payloadJson);
      if (decoded is Map<String, dynamic>) {
        if (_isPriorityAnnouncementData(decoded)) {
          _pushAnnouncementPriorityAlert(navigatorKey, decoded);
        }
        return;
      }
      if (decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);
        if (_isPriorityAnnouncementData(data)) {
          _pushAnnouncementPriorityAlert(navigatorKey, data);
        }
      }
    } catch (_) {
      // Ignore bridge failures and keep the normal notification flow.
    }
  }

  static Future<void> handleInitialLocalNotificationLaunch(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    final payload = _pendingLocalNotificationPayload;
    if (payload == null || payload.isEmpty) {
      return;
    }
    _pendingLocalNotificationPayload = null;
    await handleLocalNotificationPayload(navigatorKey, payload);
  }

  static String _foregroundDedupKey(RemoteMessage message) {
    final data = message.data;
    final notificationId = data['notificationId']?.toString();
    if (notificationId != null &&
        notificationId.isNotEmpty &&
        notificationId != 'null') {
      return 'nid:$notificationId';
    }

    final type = data['type']?.toString() ?? 'unknown';
    final taskId = data['taskId']?.toString() ?? '';
    final productId = data['productId']?.toString() ?? '';
    final postId = data['postId']?.toString() ?? '';
    final messageId = data['messageId']?.toString() ?? '';
    final senderId = data['senderId']?.toString() ?? '';
    final body = message.notification?.body ?? '';
    return 'fallback:$type|$taskId|$productId|$postId|$messageId|$senderId|$body';
  }

  static bool _shouldSuppressForegroundDuplicate(RemoteMessage message) {
    final now = DateTime.now();
    final key = _foregroundDedupKey(message);

    _recentForegroundNotifKeys.removeWhere(
      (_, ts) => now.difference(ts).inSeconds > 20,
    );

    final seenAt = _recentForegroundNotifKeys[key];
    if (seenAt != null && now.difference(seenAt).inSeconds <= 20) {
      return true;
    }

    _recentForegroundNotifKeys[key] = now;
    return false;
  }

  static String? _dataString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    return text;
  }

  static bool _isPriorityAnnouncement(RemoteMessage message) {
    final data = message.data;
    final type = _dataString(data, 'type');
    final announcementId = _dataString(data, 'announcementId');
    if (type != 'announcement' || announcementId == null) {
      return false;
    }

    final priority = _dataString(data, 'priority')?.toLowerCase();
    final alertStyle = _dataString(data, 'alertStyle');
    final attemptFullScreen = _dataString(data, 'attemptFullScreen')?.toLowerCase();
    return priority == 'high' ||
        alertStyle == 'announcement_priority' ||
        attemptFullScreen == 'true';
  }

  static bool _isPriorityAnnouncementData(Map<String, dynamic> data) {
    final type = _dataString(data, 'type');
    final announcementId = _dataString(data, 'announcementId');
    if (type != 'announcement' || announcementId == null) {
      return false;
    }

    final priority = _dataString(data, 'priority')?.toLowerCase();
    final alertStyle = _dataString(data, 'alertStyle');
    final attemptFullScreen = _dataString(data, 'attemptFullScreen')?.toLowerCase();
    return priority == 'high' ||
        alertStyle == 'announcement_priority' ||
        attemptFullScreen == 'true';
  }

  static void _pushAnnouncementPriorityAlert(
    GlobalKey<NavigatorState> navigatorKey,
    Map<String, dynamic> data,
  ) {
    final announcementId = _dataString(data, 'announcementId');
    if (announcementId == null) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder:
            (_) => AnnouncementPriorityAlertScreen(
              announcementId: announcementId,
              title: _dataString(data, 'title') ?? 'Barangay Announcement',
              body: _dataString(data, 'body') ?? 'New barangay announcement.',
            ),
      ),
    );
  }

  static Future<void> _showPriorityAnnouncementLocalNotification(
    RemoteMessage message, {
    required bool fullScreenIntent,
  }) async {
    final data = Map<String, dynamic>.from(message.data);
    final announcementId = _dataString(data, 'announcementId');
    if (announcementId == null) {
      return;
    }

    final localNotifications = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
    );
    await localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      await localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_priorityChannel);
    }

    final title =
        message.notification?.title ??
        _dataString(data, 'title') ??
        'Announcement';
    final body =
        message.notification?.body ??
        _dataString(data, 'body') ??
        'New barangay announcement.';
    final localNotificationId = announcementId.hashCode & 0x7FFFFFFF;

    try {
      // Create Android notification details with full-screen intent
      final androidDetails = AndroidNotificationDetails(
        _priorityChannel.id,
        _priorityChannel.name,
        channelDescription: _priorityChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        fullScreenIntent: fullScreenIntent,
      );

      await localNotifications.show(
        localNotificationId,
        title,
        body,
        NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(),
        ),
        payload: 'data:${jsonEncode(data)}',
      );

      // If full-screen intent should be used on Android, launch the alert activity directly
      if (fullScreenIntent && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _androidCapabilitiesChannel.invokeMethod<void>(
            'showAnnouncementAlertActivity',
            <String, dynamic>{
              'announcementId': announcementId,
              'title': title,
              'body': body,
            },
          );
        } catch (_) {
          // If method channel fails, the notification will still show as fallback
        }
      }
    } catch (_) {
      // If the OS blocks the alert, the notification will still be handled by the system.
    }
  }

  static Future<void> handleLocalNotificationPayload(
    GlobalKey<NavigatorState> navigatorKey,
    String payload,
  ) async {
    if (payload.startsWith('data:')) {
      final raw = payload.substring('data:'.length);
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          await PushNotificationHandler.handleNotificationNavigation(
            navigatorKey,
            decoded,
          );
          return;
        }
        if (decoded is Map) {
          await PushNotificationHandler.handleNotificationNavigation(
            navigatorKey,
            Map<String, dynamic>.from(decoded),
          );
          return;
        }
      } catch (_) {
        // fall through to legacy payload handling
      }
    }

    if (payload == 'account_approved') {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
      return;
    }

    if (payload.startsWith('product_approved:')) {
      final id = payload.substring('product_approved:'.length);
      if (id.isNotEmpty) {
        await PushNotificationHandler.handleNotificationNavigation(navigatorKey, {
          'type': 'product_approved',
          'productId': id,
        });
      }
      return;
    }

    if (payload.startsWith('task_approved:')) {
      final id = payload.substring('task_approved:'.length);
      if (id.isNotEmpty) {
        await PushNotificationHandler.handleNotificationNavigation(navigatorKey, {
          'type': 'task_approved',
          'taskId': id,
        });
      }
      return;
    }

    if (payload.startsWith('announcement:')) {
      final id = payload.substring('announcement:'.length);
      if (id.isNotEmpty) {
        PushNotificationHandler.handleNotificationNavigation(navigatorKey, {
          'type': 'announcement',
          'announcementId': id,
        });
      }
      return;
    }

    if (payload.startsWith('post:')) {
      final rest = payload.substring('post:'.length);
      final parts = rest.split(':');
      final id = parts.isNotEmpty ? parts[0] : '';
      final commentIdPart = parts.length >= 2 ? parts[1] : null;
      if (id.isNotEmpty) {
        if (commentIdPart != null && commentIdPart.isNotEmpty) {
          await PushNotificationHandler.handleNotificationNavigation(navigatorKey, {
            'type': 'comment',
            'postId': id,
            'commentId': commentIdPart,
          });
        } else {
          final context = navigatorKey.currentContext;
          if (context != null) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PostDetailScreen(postId: id),
              ),
            );
          }
        }
      }
      return;
    }

    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AnnouncementDetailScreen(announcementId: payload),
        ),
      );
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    unawaited(handleLocalNotificationPayload(_navigatorKey, payload));
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (_shouldSuppressForegroundDuplicate(message)) {
      return;
    }

    final type = message.data['type'] as String?;
    final rawNotificationId = message.data['notificationId']?.toString();
    final localNotificationId =
        (rawNotificationId != null &&
                rawNotificationId.isNotEmpty &&
                rawNotificationId != 'null')
            ? rawNotificationId.hashCode & 0x7FFFFFFF
            : message.hashCode % 0x7FFFFFFF;

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
          localNotificationId,
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
        localNotificationId,
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
        localNotificationId,
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
        localNotificationId,
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

    if (_isPriorityAnnouncement(message)) {
      // Foreground flow should avoid in-app modal interruption.
      await _showPriorityAnnouncementLocalNotification(
        message,
        fullScreenIntent: false,
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
      localNotificationId,
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
      if (_isPriorityAnnouncement(message)) {
        _pushAnnouncementPriorityAlert(_navigatorKey, Map<String, dynamic>.from(message.data));
        return;
      }
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
    final String? senderId = _str(data['senderId']);

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

          if (type == 'task_chat_message' && currentUid != null) {
            String? otherPartyId;
            String otherPartyName = 'Resident';

            if (senderId != null &&
                senderId.isNotEmpty &&
                senderId != currentUid) {
              otherPartyId = senderId;
            } else if (currentUid == task.requesterId) {
              otherPartyId = task.assignedTo;
            } else {
              otherPartyId = task.requesterId;
            }

            if (otherPartyId == task.requesterId) {
              otherPartyName = task.requesterName;
            } else if (task.assignedTo != null &&
                otherPartyId == task.assignedTo) {
              final assignedName = task.assignedByName;
              if (assignedName != null && assignedName.isNotEmpty) {
                otherPartyName = assignedName;
              }
            }

            if (otherPartyId != null && otherPartyId.isNotEmpty) {
              final chatOtherPartyId = otherPartyId;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => TaskChatScreen(
                        taskId: task.id,
                        taskTitle: task.title,
                        otherPartyName: otherPartyName,
                        otherPartyId: chatOtherPartyId,
                        currentUserId: currentUid,
                      ),
                ),
              );
              return;
            }
          }

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
      if (_isPriorityAnnouncementData(data)) {
        _pushAnnouncementPriorityAlert(navigatorKey, data);
        return;
      }
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
      if (_isPriorityAnnouncementData(Map<String, dynamic>.from(message.data))) {
        _pushAnnouncementPriorityAlert(
          navigatorKey,
          Map<String, dynamic>.from(message.data),
        );
        return;
      }
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
