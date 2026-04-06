import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
