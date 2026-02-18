import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FCM token registration for the LINKod mobile app.
///
/// **Core rules**
/// - FCM tokens identify DEVICES, not users.
/// - Tokens are linked only to the CURRENT user session.
/// - On logout we remove the device token from users/{uid}/devices so shared
///   devices do not receive notifications for the previous user.
///
/// **Firestore structure**
/// - Approved & logged-in: tokens stored in users/{uid}/devices/{tokenId}.
/// - Not approved (pending): token added to awaitingApproval doc's fcmTokens array.
///
/// **When tokens are written**
/// - App start / login: authStateChanges or explicit register → get token, check
///   users/{uid}.isApproved → save to devices/ or awaitingApproval.
/// - Token refresh: same routing by approval status.
/// OTP is not used; design is compatible with future OTP addition.
class FcmTokenService {
  FcmTokenService._();

  static final FcmTokenService instance = FcmTokenService._();

  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _started = false;

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  /// Stable document ID for a token (same token → same id). Used in users/{uid}/devices/{tokenId}.
  static String tokenIdFromToken(String token) {
    return token.hashCode.abs().toRadixString(16);
  }

  static String get _platform {
    return defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';
  }

  /// Starts listeners: on auth state change and token refresh, route the current
  /// FCM token to users/{uid}/devices (if approved) or awaitingApproval (if pending).
  /// Safe to call multiple times; only starts once.
  void start() {
    if (_started) return;
    _started = true;

    if (!_isSupportedPlatform) return;

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) return;
      unawaited(_registerTokenForCurrentUser());
    });

    _tokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _registerTokenForCurrentUser();
    });
  }

  /// Request notification permission on first app run (called from main.dart)
  Future<void> requestPermissionOnFirstRun() async {
    if (!_isSupportedPlatform) return;
    await _requestPermissionIfNeeded();
  }

  /// Fetches the current FCM token and stores it in the correct collection
  /// based on approval status. Call after login for immediate registration if desired.
  Future<void> registerCurrentTokenForUser(String uid) async {
    if (!_isSupportedPlatform) return;
    await _requestPermissionIfNeeded();
    await _registerTokenForCurrentUser();
  }

  /// Returns the current FCM token for inclusion in the initial awaitingApproval doc.
  /// Use this when creating the doc so we don't need a follow-up update (avoids permission issues when not signed in).
  Future<String?> getTokenForAwaitingApproval() async {
    if (!_isSupportedPlatform) return null;
    try {
      await _requestPermissionIfNeeded();
      final token = await FirebaseMessaging.instance.getToken();
      return (token != null && token.trim().isNotEmpty) ? token : null;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FcmTokenService: getTokenForAwaitingApproval failed: $e');
      }
      return null;
    }
  }

  /// Writes the current device's FCM token into an awaitingApproval document.
  /// Call this when the user submits their sign-up/approval request so the
  /// backend can send the approval push to this device when the admin approves.
  Future<void> addTokenToAwaitingApprovalDocument(
    DocumentReference docRef,
  ) async {
    if (!_isSupportedPlatform) return;
    try {
      await _requestPermissionIfNeeded();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('FcmTokenService: addTokenToAwaitingApprovalDocument — no token');
        }
        return;
      }
      await docRef.update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FcmTokenService: addTokenToAwaitingApprovalDocument failed: $e');
      }
    }
  }

  /// Removes the current device's FCM token from users/{uid}/devices.
  /// Call this before signing out so the device does not receive notifications
  /// for the next user on shared devices.
  Future<void> removeTokenOnLogout(String uid) async {
    if (!_isSupportedPlatform) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      final tid = tokenIdFromToken(token);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(tid)
          .delete();
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FcmTokenService: removeTokenOnLogout failed: $e');
      }
    }
  }

  Future<void> _requestPermissionIfNeeded() async {
    if (kIsWeb) return;
    
    // Check if this is first run - only request permission on first run
    final prefs = await SharedPreferences.getInstance();
    final permissionRequested = prefs.getBool('notification_permission_requested') ?? false;
    
    if (permissionRequested) {
      // Permission already requested, skip
      return;
    }
    
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await prefs.setBool('notification_permission_requested', true);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // For Android 13+ (API 33+), request POST_NOTIFICATIONS permission
      if (Platform.isAndroid) {
        final androidImplementation = FlutterLocalNotificationsPlugin()
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          final granted = await androidImplementation.requestNotificationsPermission();
          if (granted == true) {
            await prefs.setBool('notification_permission_requested', true);
          }
        }
      }
    }
  }

  Future<void> _registerTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _requestPermissionIfNeeded();

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.trim().isEmpty) return;

    final approved = await _isUserApproved(user.uid);
    if (approved) {
      await _saveTokenToDevices(uid: user.uid, token: token);
    } else {
      await _saveTokenToAwaitingApproval(uid: user.uid, token: token);
    }
  }

  Future<bool> _isUserApproved(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      return data?['isApproved'] as bool? ?? false;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FcmTokenService: _isUserApproved failed: $e');
      }
      return false;
    }
  }

  /// Store token in users/{uid}/devices/{tokenId}. Used when user is approved and logged in.
  Future<void> _saveTokenToDevices({required String uid, required String token}) async {
    try {
      final tid = tokenIdFromToken(token);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(tid)
          .set({
        'fcmToken': token,
        'platform': _platform,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FcmTokenService: _saveTokenToDevices failed: $e');
      }
    }
  }

  /// Add token to awaitingApproval doc (fcmTokens array) when user is not approved.
  /// Finds doc by userId; avoids duplicates via arrayUnion.
  Future<void> _saveTokenToAwaitingApproval({required String uid, required String token}) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('awaitingApproval')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return;

      await snapshot.docs.first.reference.update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FcmTokenService: _saveTokenToAwaitingApproval failed: $e');
      }
    }
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenRefreshSub?.cancel();
    _authSub = null;
    _tokenRefreshSub = null;
    _started = false;
  }
}
