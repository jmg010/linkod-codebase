import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

enum OtpErrorType {
  invalidOtp,
  expiredOtp,
  tooManyRequests,
  network,
  invalidInput,
  server,
  unknown,
}

class OtpServiceException implements Exception {
  final OtpErrorType type;
  final String message;

  OtpServiceException(this.type, this.message);

  @override
  String toString() => message;
}

class PhoneAuthRequestResult {
  final String? verificationId;
  final int? resendToken;
  final bool autoVerified;

  const PhoneAuthRequestResult({
    this.verificationId,
    this.resendToken,
    this.autoVerified = false,
  });
}

/// Manages OTP state during registration/device verification.
///
/// **Flow**:
/// 1. App calls requestOtp(phoneNumber) with FCM token
/// 2. Backend generates OTP, sends via FCM data message
/// 3. App extracts OTP from push notification
/// 4. App calls verifyOtp(phoneNumber, otp)
/// 5. Backend validates and marks account as verified
///
/// **Security**:
/// - OTP expires after 2 minutes (120 seconds)
/// - Rate limiting: max 3 OTP requests per phone per 30 minutes
/// - OTP is 6 digits (0-999999)
/// - OTP sent via FCM data payload, not display notification
class OtpService {
  OtpService._();

  static final OtpService instance = OtpService._();

  static const String _otpRequestFunction = 'requestOtp';
  static const String _otpVerifyFunction = 'verifyOtp';

  static String? formatPhoneNumberForFirebase(String input) {
    var cleaned = input.replaceAll(RegExp(r'[\s\-\.\(\)]+'), '');
    cleaned = cleaned.trim();
    if (cleaned.isEmpty) return null;

    if (cleaned.startsWith('+')) {
      final digits = cleaned.substring(1);
      if (!RegExp(r'^\d{10,15}$').hasMatch(digits)) return null;
      return '+$digits';
    }

    final digitsOnly = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return null;

    if (digitsOnly.length == 11 && digitsOnly.startsWith('0')) {
      return '+63${digitsOnly.substring(1)}';
    }

    if (digitsOnly.length == 10) {
      return '+63$digitsOnly';
    }

    if (digitsOnly.length == 12 && digitsOnly.startsWith('63')) {
      return '+$digitsOnly';
    }

    if (digitsOnly.length >= 10 && digitsOnly.length <= 15) {
      return '+$digitsOnly';
    }

    return null;
  }

  String _mapPhoneErrorMessage(
    FirebaseAuthException e, {
    required bool isVerification,
  }) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();

    if (code == 'too-many-requests' || code == 'quota-exceeded') {
      return 'Too many requests. Please wait before trying again.';
    }

    if (code == 'billing-not-enabled') {
      return 'SMS sending is not enabled for this project yet. Please contact support.';
    }

    if (code == 'invalid-phone-number' || code == 'invalid-verification-id') {
      return 'Invalid phone number. Please check and try again.';
    }

    if (code == 'invalid-verification-code') {
      return 'Wrong verification code. Please try again.';
    }

    if (code == 'session-expired' || code == 'code-expired') {
      return 'OTP has expired. Please request a new one.';
    }

    if (code == 'app-not-authorized' ||
        code == 'invalid-app-credential' ||
        code == 'missing-client-identifier' ||
        code == 'missing-activity-for-recaptcha' ||
        code == 'operation-not-allowed') {
      return 'Phone authentication is not configured correctly for this app build. Please check Firebase Phone Auth, package name, and SHA fingerprints.';
    }

    if (message.contains('play integrity') ||
        message.contains('sha-1') ||
        message.contains('sha1') ||
        message.contains('sha-256') ||
        message.contains('sha256')) {
      return 'Phone authentication setup is incomplete for this app build. Verify Firebase SHA fingerprints and app configuration.';
    }

    if (message.contains('region') ||
        message.contains('country') ||
        message.contains('not allowed to send sms')) {
      return 'SMS is not allowed for this region in your Firebase phone auth settings.';
    }

    if (code == 'captcha-check-failed' ||
        code == 'web-context-cancelled' ||
        message.contains('recaptcha') ||
        message.contains('captcha')) {
      return 'Security verification was not completed. Please try again and finish the verification step.';
    }

    if (code == 'network-request-failed' ||
        code == 'network') {
      return 'No internet connection. Please check your network and try again.';
    }

    if (code == 'internal-error' || message.contains('internal error')) {
      return 'Verification service is temporarily unavailable. Please try again in a moment.';
    }

    if (isVerification) {
      return 'Unable to verify code right now. Please try again.';
    }

    return 'Unable to send verification code right now. Please try again. (Error: ${e.code})';
  }

  Future<void> _consumeTemporaryPhoneAuthUser(
    PhoneAuthCredential credential, {
    bool keepSignedIn = false,
  }) async {
    final auth = FirebaseAuth.instance;
    await auth.signInWithCredential(credential);

    if (keepSignedIn) {
      return;
    }

    final currentUser = auth.currentUser;
    if (currentUser != null) {
      await currentUser.delete();
    }

    await auth.signOut();
  }

  // Local state for received OTP (from FCM push)
  String? _receivedOtp;
  String? _receivedPhoneNumber;
  DateTime? _otpReceivedTime;

  final _otpReceived = StreamController<String>.broadcast();

  /// Stream that emits when OTP is received from FCM
  Stream<String> get otpStream => _otpReceived.stream;

  /// Call from push notification handler when OTP message arrives
  void handleOtpFromFcm({required String otp, required String phoneNumber}) {
    _receivedOtp = otp;
    _receivedPhoneNumber = phoneNumber;
    _otpReceivedTime = DateTime.now();
    _otpReceived.add(otp);
  }

  /// Get the most recently received OTP (from FCM notification)
  String? getReceivedOtp() => _receivedOtp;

  /// Get the phone number associated with received OTP
  String? getReceivedPhoneNumber() => _receivedPhoneNumber;

  /// Check if received OTP is still valid (not expired)
  bool isReceivedOtpValid() {
    if (_otpReceivedTime == null) return false;
    final age = DateTime.now().difference(_otpReceivedTime!);
    // OTP valid for 2 minutes
    return age.inSeconds < 120;
  }

  /// Clear stored OTP (after successful verification or timeout)
  void clearReceivedOtp() {
    _receivedOtp = null;
    _receivedPhoneNumber = null;
    _otpReceivedTime = null;
  }

  Future<PhoneAuthRequestResult> requestPhoneOtp({
    required String phoneNumber,
    int? forceResendingToken,
  }) async {
    try {
      final normalizedPhone = formatPhoneNumberForFirebase(phoneNumber);
      if (normalizedPhone == null) {
        throw OtpServiceException(
          OtpErrorType.invalidInput,
          'Invalid phone number. Please check and try again.',
        );
      }

      final completer = Completer<PhoneAuthRequestResult>();
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        forceResendingToken: forceResendingToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _consumeTemporaryPhoneAuthUser(credential);
            if (!completer.isCompleted) {
              completer.complete(
                const PhoneAuthRequestResult(autoVerified: true),
              );
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.completeError(
              OtpServiceException(
                e.code == 'too-many-requests' || e.code == 'quota-exceeded'
                    ? OtpErrorType.tooManyRequests
                    : e.code == 'invalid-phone-number'
                        ? OtpErrorType.invalidInput
                        : e.code == 'network-request-failed'
                            ? OtpErrorType.network
                            : OtpErrorType.server,
                _mapPhoneErrorMessage(e, isVerification: false),
              ),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!completer.isCompleted) {
            completer.complete(
              PhoneAuthRequestResult(
                verificationId: verificationId,
                resendToken: resendToken,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!completer.isCompleted) {
            completer.complete(
              PhoneAuthRequestResult(verificationId: verificationId),
            );
          }
        },
      );

      return await completer.future;
    } on FirebaseAuthException catch (e) {
      throw OtpServiceException(
        e.code == 'too-many-requests' || e.code == 'quota-exceeded'
            ? OtpErrorType.tooManyRequests
            : e.code == 'invalid-phone-number'
                ? OtpErrorType.invalidInput
                : e.code == 'network-request-failed'
                    ? OtpErrorType.network
                    : OtpErrorType.server,
        _mapPhoneErrorMessage(e, isVerification: false),
      );
    } catch (e) {
      throw _mapUnknownException(
        e,
        fallback:
            'Unable to send verification code right now. Please try again.',
      );
    }
  }

  Future<bool> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
    bool keepSignedIn = false,
  }) async {
    if (!_isValidOtpFormat(smsCode)) {
      throw OtpServiceException(
        OtpErrorType.invalidInput,
        'Invalid verification code format. Please enter 6 digits.',
      );
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _consumeTemporaryPhoneAuthUser(
        credential,
        keepSignedIn: keepSignedIn,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      throw OtpServiceException(
        e.code == 'invalid-verification-code'
            ? OtpErrorType.invalidOtp
            : e.code == 'session-expired' || e.code == 'code-expired'
                ? OtpErrorType.expiredOtp
                : e.code == 'invalid-verification-id'
                    ? OtpErrorType.invalidInput
                    : e.code == 'too-many-requests' || e.code == 'quota-exceeded'
                        ? OtpErrorType.tooManyRequests
                        : e.code == 'network-request-failed'
                            ? OtpErrorType.network
                            : OtpErrorType.server,
        _mapPhoneErrorMessage(e, isVerification: true),
      );
    } catch (e) {
      throw _mapUnknownException(
        e,
        fallback: 'Verification failed. Please try again.',
      );
    }
  }

  /// Request OTP to be sent to device via FCM
  ///
  /// Calls Cloud Function 'requestOtp' with:
  /// - phoneNumber: user's phone number
  /// - fcmToken: device's FCM token
  /// - email: compatibility field for backend validators that require email
  ///
  /// Returns true if request successful, false if rate limited
  /// Throws exception on other errors
  Future<bool> requestOtp({
    required String phoneNumber,
    required String fcmToken,
  }) async {
    try {
      final functions = FirebaseFunctions.instance;

      // ensure phone is in normalized 0-prefixed format
      final normalizedPhone = normalizePhone(phoneNumber);
      final email = _phoneToEmail(normalizedPhone);

      // Call the Cloud Function
      final callable = functions.httpsCallable('requestOtp');
      final result = await callable.call({
        'phoneNumber': normalizedPhone,
        'fcmToken': fcmToken,
        'email': email,
      });

      return result.data['success'] == true;
    } on FirebaseFunctionsException catch (e) {
      throw _mapFunctionsException(e, isVerifyFlow: false);
    } catch (e) {
      throw _mapUnknownException(
        e,
        fallback: 'Unable to send verification code right now. Please try again.',
      );
    }
  }

  /// Verify OTP submitted by user
  ///
  /// Calls Cloud Function 'verifyOtp' with:
  /// - phoneNumber: user's phone number
  /// - otp: 6-digit code from notification
  /// - email: compatibility field for backend validators that require email
  ///
  /// Returns true if OTP is valid and account marked as verified
  /// Throws exception on errors
  Future<bool> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    // Validate OTP format locally first
    if (!_isValidOtpFormat(otp)) {
      throw Exception('Invalid OTP format. Must be 6 digits.');
    }

    try {
      final functions = FirebaseFunctions.instance;
      final normalizedPhone = normalizePhone(phoneNumber);

      // Call the Cloud Function
      final callable = functions.httpsCallable('verifyOtp');
      final result = await callable.call({
        'phoneNumber': normalizedPhone,
        'otp': otp,
        'email': _phoneToEmail(normalizedPhone),
      });

      if (result.data['success'] == true) {
        clearReceivedOtp();
        return true;
      } else {
        throw OtpServiceException(
          OtpErrorType.unknown,
          'Verification failed. Please try again.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      throw _mapFunctionsException(e, isVerifyFlow: true);
    } catch (e) {
      if (e is OtpServiceException) rethrow;
      throw _mapUnknownException(
        e,
        fallback: 'Verification failed. Please try again.',
      );
    }
  }

  OtpServiceException _mapFunctionsException(
    FirebaseFunctionsException e, {
    required bool isVerifyFlow,
  }) {
    final message = e.message?.toLowerCase() ?? '';

    if (e.code == 'resource-exhausted') {
      return OtpServiceException(
        OtpErrorType.tooManyRequests,
        'Too many requests. Please wait before trying again.',
      );
    }

    if (e.code == 'unavailable' ||
        message.contains('network') ||
        message.contains('internet') ||
        message.contains('socket') ||
        message.contains('timed out') ||
        message.contains('failed to connect') ||
        message.contains('connection')) {
      return OtpServiceException(
        OtpErrorType.network,
        'No internet connection. Please check your network and try again.',
      );
    }

    if (isVerifyFlow) {
      if (e.code == 'not-found') {
        return OtpServiceException(
          OtpErrorType.invalidOtp,
          'Wrong verification code. Please try again.',
        );
      }

      if (e.code == 'failed-precondition') {
        return OtpServiceException(
          OtpErrorType.expiredOtp,
          'OTP has expired. Please request a new one.',
        );
      }

      if (e.code == 'invalid-argument') {
        return OtpServiceException(
          OtpErrorType.invalidInput,
          'Invalid verification code format. Please enter 6 digits.',
        );
      }

      return OtpServiceException(
        OtpErrorType.server,
        'Unable to verify code right now. Please try again.',
      );
    }

    if (e.code == 'invalid-argument') {
      return OtpServiceException(
        OtpErrorType.invalidInput,
        'Invalid phone number. Please check and try again.',
      );
    }

    return OtpServiceException(
      OtpErrorType.server,
      'Unable to send verification code right now. Please try again.',
    );
  }

  OtpServiceException _mapUnknownException(
    Object error, {
    required String fallback,
  }) {
    final text = error.toString().toLowerCase();

    if (text.contains('too-many-requests') || text.contains('quota')) {
      return OtpServiceException(
        OtpErrorType.tooManyRequests,
        'Too many requests. Please wait before trying again.',
      );
    }

    if (text.contains('billing')) {
      return OtpServiceException(
        OtpErrorType.server,
        'SMS sending is not enabled for this project yet. Please contact support.',
      );
    }

    if (text.contains('recaptcha') ||
        text.contains('captcha') ||
        text.contains('web context cancelled')) {
      return OtpServiceException(
        OtpErrorType.invalidInput,
        'Security verification was not completed. Please try again and finish the verification step.',
      );
    }

    if (text.contains('play integrity') ||
        text.contains('sha-1') ||
        text.contains('sha1') ||
        text.contains('sha-256') ||
        text.contains('sha256') ||
        text.contains('app-not-authorized') ||
        text.contains('invalid-app-credential') ||
        text.contains('missing-client-identifier')) {
      return OtpServiceException(
        OtpErrorType.server,
        'Phone authentication is not configured correctly for this app build. Please check Firebase Phone Auth, package name, and SHA fingerprints.',
      );
    }

    if (text.contains('region') ||
        text.contains('country') ||
        text.contains('not allowed to send sms')) {
      return OtpServiceException(
        OtpErrorType.server,
        'SMS is not allowed for this region in your Firebase phone auth settings.',
      );
    }

    if (text.contains('network') ||
        text.contains('internet') ||
        text.contains('socket') ||
        text.contains('timed out') ||
        text.contains('failed to connect') ||
        text.contains('connection')) {
      return OtpServiceException(
        OtpErrorType.network,
        'No internet connection. Please check your network and try again.',
      );
    }

    return OtpServiceException(OtpErrorType.unknown, fallback);
  }

  /// Validate OTP format (6 digits, numeric only)
  bool _isValidOtpFormat(String otp) {
    if (otp.length != 6) return false;
    return RegExp(r'^\d{6}$').hasMatch(otp);
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phoneNumber) {
    // Remove common formatting characters
    final cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\.\(\)]+'), '');

    // Allow test numbers for development
    if (cleaned == '+1234567890' ||
        cleaned == '1234567890' ||
        cleaned.startsWith('+63912345678')) {
      return true;
    }

    // Accept numbers starting with 0 as well
    final withoutPlus =
        cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;

    // Check if it's at least 10 digits and max 15 digits (international standard)
    if (withoutPlus.length < 10 || withoutPlus.length > 15) return false;

    // Check if it contains only digits
    return RegExp(r'^\d+$').hasMatch(withoutPlus);
  }

  void dispose() {
    _otpReceived.close();
  }

  /// Normalize Philippine phone numbers to start with 0
  /// Input may include "+63" prefix or just digits. Removes whitespace.
  static String normalizePhone(String input) {
    var cleaned = input.replaceAll(RegExp(r'[\s\-\.\(\)]+'), '');
    // digits only
    cleaned = cleaned.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.startsWith('+63')) {
      return '0${cleaned.substring(3)}';
    }
    if (cleaned.startsWith('63') && cleaned.length == 12) {
      return '0${cleaned.substring(2)}';
    }
    return cleaned;
  }

  static String _phoneToEmail(String normalizedPhone) {
    return '${normalizedPhone.trim()}@linkod.com';
  }
}
