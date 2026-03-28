import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
  static const String _installationIdPrefKey = 'linkod_fcm_installation_id';

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
    // Do not use String.hashCode: it may vary across runs and create duplicate docs.
    return base64Url.encode(utf8.encode(token)).replaceAll('=', '');
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

    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      _,
    ) async {
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
          print(
            'FcmTokenService: addTokenToAwaitingApprovalDocument — no token',
          );
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
      final installationId = await _getOrCreateInstallationId();
      final devicesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('devices');

      if (token != null && token.trim().isNotEmpty) {
        final tid = tokenIdFromToken(token);
        await devicesRef.doc(tid).delete();
      }

      final sameInstallationDocs =
          await devicesRef
              .where('installationId', isEqualTo: installationId)
              .get();
      if (sameInstallationDocs.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in sameInstallationDocs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
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
    final permissionRequested =
        prefs.getBool('notification_permission_requested') ?? false;

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
        final androidImplementation =
            FlutterLocalNotificationsPlugin()
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
        if (androidImplementation != null) {
          final granted =
              await androidImplementation.requestNotificationsPermission();
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

    final shouldUseDevices = await _shouldSaveTokenToUserDevices(user.uid);
    if (shouldUseDevices) {
      await _saveTokenToDevices(uid: user.uid, token: token);
    } else {
      await _saveTokenToAwaitingApproval(uid: user.uid, token: token);
    }
  }

  Future<String> _getOrCreateInstallationId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_installationIdPrefKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    final id = base64Url.encode(bytes).replaceAll('=', '');
    await prefs.setString(_installationIdPrefKey, id);
    return id;
  }

  /// Determines where to store token for the current session.
  ///
  /// For backward compatibility, a user doc without `isApproved` is treated as
  /// active unless accountStatus is explicitly pending/declined/suspended.
  Future<bool> _shouldSaveTokenToUserDevices(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) return false;

      final data = doc.data();
      final isApproved = data?['isApproved'] as bool?;
      final accountStatus = (data?['accountStatus'] as String?)?.toLowerCase();

      if (accountStatus == 'pending' ||
          accountStatus == 'declined' ||
          accountStatus == 'suspended') {
        return false;
      }

      if (isApproved == true || accountStatus == 'active') {
        return true;
      }

      // Legacy docs may not have isApproved/accountStatus but are valid users.
      if (isApproved == null && accountStatus == null) {
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FcmTokenService: _shouldSaveTokenToUserDevices failed: $e');
      }
      return false;
    }
  }

  /// Store token in users/{uid}/devices/{tokenId}. Used when user is approved and logged in.
  Future<void> _saveTokenToDevices({
    required String uid,
    required String token,
  }) async {
    try {
      final tid = tokenIdFromToken(token);
      final installationId = await _getOrCreateInstallationId();
      final devicesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('devices');

      await devicesRef.doc(tid).set({
        'fcmToken': token,
        'installationId': installationId,
        'platform': _platform,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Cleanup legacy duplicate docs that contain the same token.
      final sameTokenDocs =
          await devicesRef.where('fcmToken', isEqualTo: token).get();
      final stale =
          sameTokenDocs.docs
              .where((doc) => doc.id != tid)
              .map((d) => d.reference)
              .toList();
      if (stale.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final ref in stale) {
          batch.delete(ref);
        }
        await batch.commit();
      }

      // Ensure one active token per app installation for this user.
      final sameInstallationDocs =
          await devicesRef
              .where('installationId', isEqualTo: installationId)
              .get();
      final staleInstallationRefs =
          sameInstallationDocs.docs
              .where((doc) => doc.id != tid)
              .map((d) => d.reference)
              .toList();
      if (staleInstallationRefs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final ref in staleInstallationRefs) {
          batch.delete(ref);
        }
        await batch.commit();
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FcmTokenService: _saveTokenToDevices failed: $e');
      }
    }
  }

  /// Add token to awaitingApproval doc (fcmTokens array) when user is not approved.
  /// Finds doc by uid field; avoids duplicates via arrayUnion.
  Future<void> _saveTokenToAwaitingApproval({
    required String uid,
    required String token,
  }) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('awaitingApproval')
              .where('uid', isEqualTo: uid)
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
