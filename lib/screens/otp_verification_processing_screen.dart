import 'package:flutter/material.dart';
import '../services/otp_service.dart';
import '../ui_constants.dart';
import 'otp_verification_screen.dart';

/// Processing screen shown while requesting OTP from backend
///
/// **Flow**:
/// 1. Screen shows loading animation and "Sending verification code..."
/// 2. Calls OtpService.requestOtp() in background
/// 3. On success: navigates to OtpVerificationScreen
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
      debugPrint('FCM Token: ${widget.fcmToken.substring(0, 20)}...');

      // Request OTP from backend
      final success = await OtpService.instance.requestOtp(
        phoneNumber: widget.phoneNumber,
        fcmToken: widget.fcmToken,
      );

      debugPrint('OTP request success: $success');

      if (!mounted) return;

      if (!success) {
        setState(() {
          _isLoading = false;
          _error =
              'Too many OTP requests. Please wait 30 minutes before trying again.';
          _canRetry = false;
        });
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
                ),
          ),
        );
      }
    } catch (e) {
      debugPrint('OTP request error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error message: ${e.toString()}');

      if (mounted) {
        setState(() {
          _isLoading = false;
          // Show the actual error instead of generic message
          _error = 'Error: ${e.toString()}';
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
                    color: kFacebookBlue.withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    size: 60,
                    color: kFacebookBlue,
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
                  color: _error != null ? Colors.red : kFacebookBlue,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: kPaddingMedium),

              // Subtitle
              if (_isLoading)
                Text(
                  'Check your notifications for the 6-digit code',
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
                      valueColor: AlwaysStoppedAnimation<Color>(kFacebookBlue),
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
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue[200]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'What to expect',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: kPaddingSmall),
                      _buildInfoPoint('You\'ll receive a push notification'),
                      _buildInfoPoint('The code is 6 digits long'),
                      _buildInfoPoint('Code expires in 2 minutes'),
                      _buildInfoPoint('Make sure notifications are enabled'),
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
                color: Colors.blue[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.blue[700]),
            ),
          ),
        ],
      ),
    );
  }
}
