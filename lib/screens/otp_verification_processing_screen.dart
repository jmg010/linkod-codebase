import 'package:flutter/material.dart';
import '../ui_constants.dart';
import '../services/otp_service.dart';
import 'otp_success_screen.dart';
import 'otp_verification_screen.dart';

const Color _kLinkodGreen = Color(0xFF00A651);

/// Processing screen shown while requesting the SMS verification code
///
/// **Flow**:
/// 1. Screen shows loading animation and "Sending verification code..."
/// 2. Calls Firebase phone auth via OtpService in background
/// 3. On code sent: navigates to OtpVerificationScreen
/// 4. On failure: shows error and allows retry
class OtpVerificationProcessingScreen extends StatefulWidget {
  final String phoneNumber;
  final String fcmToken;

  const OtpVerificationProcessingScreen({
    super.key,
    required this.phoneNumber,
    required this.fcmToken,
  });

  @override
  State<OtpVerificationProcessingScreen> createState() =>
      _OtpVerificationProcessingScreenState();
}

class _OtpVerificationProcessingScreenState
    extends State<OtpVerificationProcessingScreen> {
  bool _isLoading = true;
  String? _error;
  bool _canRetry = false;

  @override
  void initState() {
    super.initState();
    _requestOtp();
  }

  Future<void> _requestOtp() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _canRetry = false;
    });

    try {
      // Debug logging
      debugPrint('Requesting OTP for phone: ${widget.phoneNumber}');
      debugPrint('FCM Token length: ${widget.fcmToken.length}');

      // Request SMS verification code from Firebase Auth
      final result = await OtpService.instance.requestPhoneOtp(
        phoneNumber: widget.phoneNumber,
      );

      debugPrint('OTP request completed');

      if (!mounted) return;

      if (result.autoVerified) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (_) => OtpSuccessScreen(
                  phoneNumber: widget.phoneNumber,
                  fcmToken: widget.fcmToken,
                ),
          ),
        );
        return;
      }

      // Success - navigate to verification screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (_) => OtpVerificationScreen(
                  phoneNumber: widget.phoneNumber,
                  fcmToken: widget.fcmToken,
                  verificationId: result.verificationId,
                  resendToken: result.resendToken,
                ),
          ),
        );
      }
    } on OtpServiceException catch (e) {
      debugPrint('OTP request mapped error: ${e.type} - ${e.message}');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.message;
          _canRetry = e.type != OtpErrorType.tooManyRequests;
        });
      }
    } catch (e) {
      debugPrint('OTP request error: $e');
      debugPrint('Error type: ${e.runtimeType}');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _error =
              'Unable to send verification code. Please check your connection and try again.';
          _canRetry = true;
        });
      }
    }
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor:
            Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : _kLinkodGreen,
        title: const Text('Verification'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : _goBack,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(kPaddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Loading animation or error icon
              if (_isLoading)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kLinkodGreen.withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.sms_outlined,
                    size: 60,
                    color: _kLinkodGreen,
                  ),
                )
              else if (_error != null)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red,
                  ),
                ),

              const SizedBox(height: kPaddingLarge),

              // Status text
              Text(
                _isLoading
                    ? 'Sending verification code...'
                    : _error != null
                    ? 'Failed to send code'
                    : 'Code sent!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _error != null ? Colors.red : _kLinkodGreen,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: kPaddingMedium),

              // Subtitle
              if (_isLoading)
                Text(
                  'Check your phone for the SMS code',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                )
              else if (_error != null)
                Text(
                  _error!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.red[700]),
                  textAlign: TextAlign.center,
                ),

              const SizedBox(height: kPaddingLarge),

              // Loading indicator
              if (_isLoading)
                Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(_kLinkodGreen),
                    ),
                    const SizedBox(height: kPaddingMedium),
                    Text(
                      'This may take a few seconds...',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),

              // Error actions
              if (!_isLoading && _error != null)
                Column(
                  children: [
                    if (_canRetry)
                      ElevatedButton(
                        onPressed: _requestOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kLinkodGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Try Again'),
                      ),

                    const SizedBox(height: kPaddingMedium),

                    TextButton(
                      onPressed: _goBack,
                      style: TextButton.styleFrom(
                        foregroundColor: _kLinkodGreen,
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),

              // Info section
              if (_isLoading)
                Container(
                  margin: const EdgeInsets.only(top: kPaddingLarge * 2),
                  padding: const EdgeInsets.all(kPaddingMedium),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    border: Border.all(color: Colors.green[200]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.green[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'What to expect',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: kPaddingSmall),
                      _buildInfoPoint('You\'ll receive an SMS message'),
                      _buildInfoPoint('The code is 6 digits long'),
                      _buildInfoPoint('Use Resend if the message does not arrive'),
                      _buildInfoPoint('Make sure your phone can receive SMS'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 2),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.green[700]),
            ),
          ),
        ],
      ),
    );
  }
}
