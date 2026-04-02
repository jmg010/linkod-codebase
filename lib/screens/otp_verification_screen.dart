import 'package:flutter/material.dart';
import '../services/otp_service.dart';
import '../ui_constants.dart';
import 'otp_success_screen.dart';

/// Second step of registration: User enters 6-digit OTP from push notification
///
/// **Features**:
/// - Manual input with 6 character fields
/// - Auto-filled if OTP received via FCM (via otpStream)
/// - Countdown timer showing OTP expiration
/// - Resend OTP option with 30-second cooldown
/// - Validation before submission
/// - Success navigation to confirmation screen
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String fcmToken;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.fcmToken,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocuses = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  String? _error;
  int _secondsRemaining = 120; // 2 minutes
  bool _isExpired = false;
  int _resendCooldown = 0; // 30 seconds cooldown after resend
  bool _otpAutoFilled = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _listenForOtpFromFcm();
    // OTP already requested in OtpVerificationProcessingScreen - don't request again
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocuses) {
      node.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      if (!mounted) return false;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;

      if (_secondsRemaining <= 0) {
        setState(() {
          _isExpired = true;
        });
        return false;
      }

      setState(() {
        _secondsRemaining--;
        if (_resendCooldown > 0) {
          _resendCooldown--;
        }
      });
      return true;
    });
  }

  void _listenForOtpFromFcm() {
    OtpService.instance.otpStream.listen((otp) {
      if (!mounted || _otpAutoFilled) return;

      // Auto-fill the OTP fields
      for (var i = 0; i < 6 && i < otp.length; i++) {
        _otpControllers[i].text = otp[i];
      }

      setState(() => _otpAutoFilled = true);

      // Show indication that OTP was received
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📱 OTP received! Code auto-filled below.'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );

      // Auto-verify if all fields are filled
      final enteredOtp = _getEnteredOtp();
      if (enteredOtp.length == 6 && !_isExpired) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _verifyOtp();
        });
      }
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _getEnteredOtp();

    if (otp.length != 6) {
      _showError('Please enter all 6 digits');
      return;
    }

    if (_isExpired) {
      _showError('OTP has expired. Please request a new one.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final success = await OtpService.instance.verifyOtp(
        phoneNumber: widget.phoneNumber,
        otp: otp,
      );

      if (!mounted) return;

      if (success) {
        // Navigate to success screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder:
                  (_) => OtpSuccessScreen(
                    phoneNumber: widget.phoneNumber,
                    fcmToken: widget.fcmToken,
                  ),
            ),
          );
        }
      } else {
        _showError('Invalid verification code. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showError(
          'Verification failed. Please check your connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_isVerifying || _resendCooldown > 0) return;

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final success = await OtpService.instance.requestOtp(
        phoneNumber: widget.phoneNumber,
        fcmToken: widget.fcmToken,
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _secondsRemaining = 120;
          _isExpired = false;
          _resendCooldown = 30; // 30 second cooldown
          _otpAutoFilled = false; // Reset auto-fill flag
        });
        _startCountdown();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📤 New verification code sent!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        _showError('Too many requests. Please wait before trying again.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to resend code. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  String _getEnteredOtp() {
    return _otpControllers.map((c) => c.text).join();
  }

  void _showError(String message) {
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final subtleTextColor = isDarkMode ? Colors.white70 : Colors.grey[600]!;
    final mutedBorderColor = isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey[200]!;

    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    final timeString = '$minutes:${seconds.toString().padLeft(2, '0')}';
    final resendTimeString = _resendCooldown > 0 ? '($_resendCooldown)' : '';

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        foregroundColor: isDarkMode ? Colors.white : Colors.black87,
        title: const Text('Verify Phone'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isVerifying ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kPaddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: kPaddingLarge),

            // Header
            Text(
              'Enter Verification Code',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: kPaddingSmall),
            Text(
              'We sent a 6-digit code to your phone via push notification.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: subtleTextColor),
            ),
            const SizedBox(height: kPaddingLarge),

            // Phone number display
            Container(
              padding: const EdgeInsets.all(kPaddingMedium),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[50],
                border: Border.all(color: mutedBorderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_android, color: subtleTextColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.phoneNumber,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed:
                        _isVerifying ? null : () => Navigator.of(context).pop(),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: kPaddingLarge),

            // OTP Input Fields
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) => _buildOtpField(index)),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: kPaddingMedium),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: kPaddingLarge),

            // Expiration timer
            Container(
              padding: const EdgeInsets.all(kPaddingMedium),
              decoration: BoxDecoration(
                color:
                    _isExpired
                        ? (isDarkMode ? const Color(0xFF3A1F1F) : Colors.red[50])
                        : (isDarkMode ? const Color(0xFF1E2A3A) : Colors.blue[50]),
                border: Border.all(
                  color:
                      _isExpired
                          ? (isDarkMode ? const Color(0xFF8B3A3A) : Colors.red[200]!)
                          : (isDarkMode ? const Color(0xFF3D5A80) : Colors.blue[200]!),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _isExpired ? Icons.error_outline : Icons.schedule,
                    color: _isExpired ? Colors.red : Colors.blue,
                  ),
                  const SizedBox(width: kPaddingSmall),
                  Expanded(
                    child: Text(
                      _isExpired
                          ? 'Code expired. Please request a new one.'
                          : 'Code expires in $timeString',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _isExpired ? Colors.red[700] : Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: kPaddingLarge * 2),

            // Verify button
            ElevatedButton(
              onPressed: (_isVerifying || _isExpired) ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isVerifying
                      ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Verifying...'),
                        ],
                      )
                      : const Text(
                        'Verify Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),

            const SizedBox(height: kPaddingMedium),

            // Resend button
            TextButton(
              onPressed:
                  (_isVerifying || _resendCooldown > 0) ? null : _resendOtp,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                _resendCooldown > 0
                    ? 'Resend Code $resendTimeString'
                    : 'Resend Code',
                style: TextStyle(
                  color:
                      _resendCooldown > 0
                          ? (isDarkMode ? Colors.white38 : Colors.grey)
                          : kFacebookBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: kPaddingLarge),

            // Info section
            Container(
              padding: const EdgeInsets.all(kPaddingMedium),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF332A10) : Colors.amber[50],
                border: Border.all(
                  color: isDarkMode ? const Color(0xFF7B6528) : Colors.amber[200]!,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.amber[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Important',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kPaddingSmall),
                  _buildInfoBullet('Make sure notifications are enabled'),
                  _buildInfoBullet('Code is valid for 2 minutes only'),
                  _buildInfoBullet('Do not share your code with anyone'),
                  if (_otpAutoFilled)
                    _buildInfoBullet('Code was auto-filled from notification'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpField(int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hasValue = _otpControllers[index].text.isNotEmpty;

    return Container(
      width: 50,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color:
              _error != null
                  ? Colors.red
                  : _otpFocuses[index].hasFocus
                  ? kFacebookBlue
                  : hasValue
                  ? Colors.green
                  : Colors.grey[300]!,
          width: _otpFocuses[index].hasFocus ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color:
            hasValue
                ? (isDarkMode ? const Color(0xFF1D3A27) : Colors.green[50])
                : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.white),
      ),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocuses[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        enabled: !_isVerifying && !_isExpired,
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color:
              hasValue
                  ? Colors.green[700]
                  : (isDarkMode ? Colors.white : Colors.black),
        ),
        onChanged: (value) {
          if (value.isNotEmpty) {
            // Move to next field if entered
            if (index < 5) {
              _otpFocuses[index + 1].requestFocus();
            } else {
              // Last field, hide keyboard
              _otpFocuses[index].unfocus();
            }
          } else if (value.isEmpty && index > 0) {
            // If cleared, move to previous field
            _otpFocuses[index - 1].requestFocus();
          }

          // Clear error when user starts typing
          if (_error != null) {
            setState(() => _error = null);
          }
        },
      ),
    );
  }

  Widget _buildInfoBullet(String text) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 4),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDarkMode ? Colors.amber[400] : Colors.amber[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.amber[200] : Colors.amber[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
