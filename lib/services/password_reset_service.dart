import 'package:cloud_functions/cloud_functions.dart';

class PasswordResetException implements Exception {
  final String message;
  final String? code;

  PasswordResetException({
    required this.message,
    this.code,
  });

  @override
  String toString() => message;
}

class PasswordResetService {
  static final PasswordResetService _instance = PasswordResetService._internal();

  factory PasswordResetService() {
    return _instance;
  }

  PasswordResetService._internal();

  final _functions = FirebaseFunctions.instance;

  /// Looks up whether a user exists for a phone number.
  /// Returns {exists: true} if found.
  Future<Map<String, dynamic>> lookupUserByPhone(String phone) async {
    try {
      final callable = _functions.httpsCallable('lookupUserByPhone');
      final result = await callable.call({'phone': phone});
      return Map<String, dynamic>.from(result.data ?? {});
    } on FirebaseFunctionsException catch (e) {
      throw PasswordResetException(
        message: _mapErrorMessage(e.code, e.message),
        code: e.code,
      );
    } catch (e) {
      throw PasswordResetException(
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Resets a user's password after OTP verification.
  /// Requires a verified phone-auth session and phone + newPassword.
  Future<void> resetPassword({
    required String phone,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      throw PasswordResetException(
        message: 'Password must be at least 8 characters long',
      );
    }

    try {
      final callable = _functions.httpsCallable('resetPassword');
      await callable.call({
        'phone': phone,
        'newPassword': newPassword,
      });
    } on FirebaseFunctionsException catch (e) {
      throw PasswordResetException(
        message: _mapErrorMessage(e.code, e.message),
        code: e.code,
      );
    } catch (e) {
      throw PasswordResetException(
        message: 'Password reset failed. Please try again later.',
      );
    }
  }

  /// Maps Firebase function error codes to user-friendly messages.
  String _mapErrorMessage(String? code, String? message) {
    switch (code) {
      case 'not-found':
        return message ?? 'Phone number not found in any account. Please check and try again.';
      case 'invalid-argument':
        return message ?? 'Invalid input. Please check your information.';
      case 'already-exists':
        return message ?? 'Account already exists with this email.';
      case 'unauthenticated':
        return 'Phone verification expired. Please verify your phone again.';
      case 'permission-denied':
        return 'Phone verification does not match. Please verify again with OTP.';
      case 'failed-precondition':
        return message ?? 'Verification is required first.';
      case 'internal':
      case 'unknown':
        return message ?? 'An error occurred. Please try again later.';
      default:
        return message ?? 'An unexpected error occurred. Please try again.';
    }
  }
}
