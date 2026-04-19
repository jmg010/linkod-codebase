import 'package:flutter/material.dart';
import '../services/otp_service.dart';
import '../ui_constants.dart';
import 'otp_success_screen.dart';

const Color _kLinkodGreen = Color(0xFF00A651);

/// Second step of registration: User enters the 6-digit SMS code
///
/// **Features**:
/// - Manual input with 6 character fields
/// - Requests an SMS verification code from Firebase Auth
/// - Resend OTP option with 30-second cooldown
/// - Validation before submission
/// - Success navigation to confirmation screen
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String fcmToken;
  final String? verificationId;
  final int? resendToken;
  final bool returnResultOnSuccess;
  final bool keepSignedInOnSuccess;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.fcmToken,
    this.verificationId,
    this.resendToken,
    this.returnResultOnSuccess = false,
    this.keepSignedInOnSuccess = false,
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

  bool _isRequestingCode = false;
  bool _isVerifying = false;
  bool _verificationFinished = false;
  String? _error;
  int _resendCooldown = 0; // 30 seconds cooldown after resend
  bool _codeSent = false;
  String? _verificationId;
  int? _resendToken;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
    if (_verificationId != null) {
      _codeSent = true;
      _resendCooldown = 30;
      _startResendCooldown();
    } else {
      _requestVerificationCode();
    }
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

  Future<void> _requestVerificationCode({bool isResend = false}) async {
    if (_isRequestingCode || _verificationFinished) return;

    setState(() {
      _isRequestingCode = true;
      _error = null;
    });

    try {
      final result = await OtpService.instance.requestPhoneOtp(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: isResend ? _resendToken : null,
      );

      if (!mounted || _verificationFinished) return;

      if (result.autoVerified) {
        await _finishVerified();
        return;
      }

      setState(() {
        _verificationId = result.verificationId;
        _resendToken = result.resendToken;
        _codeSent = true;
        _resendCooldown = 30;
      });
      _startResendCooldown();
    } on OtpServiceException catch (e) {
      if (mounted) {
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showError('Unable to send verification code. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingCode = false);
      }
    }
  }

  void _startResendCooldown() {
    Future.doWhile(() async {
      if (!mounted || _verificationFinished) return false;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || _verificationFinished) return false;

      if (_resendCooldown <= 0) {
        return false;
      }

      setState(() {
        _resendCooldown--;
      });
      return _resendCooldown > 0;
    });
  }

  Future<void> _finishVerified() async {
    if (_verificationFinished || !mounted) return;
    setState(() {
      _verificationFinished = true;
      _isVerifying = false;
      _isRequestingCode = false;
    });

    if (widget.returnResultOnSuccess) {
      Navigator.of(context).pop(<String, dynamic>{'verified': true});
      return;
    }

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

  Future<void> _verifyOtp() async {
    final otp = _getEnteredOtp();

    if (otp.length != 6) {
      _showError('Please enter all 6 digits');
      return;
    }

    if (_verificationId == null || _verificationId!.isEmpty) {
      _showError('Verification code is still being prepared. Please try again.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final success = await OtpService.instance.verifyPhoneOtp(
        verificationId: _verificationId!,
        smsCode: otp,
        keepSignedIn: widget.keepSignedInOnSuccess,
      );

      if (!mounted) return;

      if (success) {
        await _finishVerified();
      } else {
        _showError('Invalid verification code. Please try again.');
      }
    } on OtpServiceException catch (e) {
      if (mounted) {
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showError('Verification failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_isVerifying || _isRequestingCode || _resendCooldown > 0) return;
    await _requestVerificationCode(isResend: true);
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
    final resendTimeString = _resendCooldown > 0 ? '($_resendCooldown)' : '';

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        foregroundColor: isDarkMode ? Colors.white : _kLinkodGreen,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : _kLinkodGreen,
        ),
        title: Text(
          'Verify Phone',
          style: TextStyle(
            color: isDarkMode ? Colors.white : _kLinkodGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
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
              'We sent a 6-digit SMS code to your phone number.',
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
                    style: TextButton.styleFrom(
                      foregroundColor: _kLinkodGreen,
                    ),
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

            // Code status
            Container(
              padding: const EdgeInsets.all(kPaddingMedium),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E3328) : Colors.green[50],
                border: Border.all(color: isDarkMode ? const Color(0xFF2D6A4F) : Colors.green[200]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sms_outlined, color: _kLinkodGreen),
                  const SizedBox(width: kPaddingSmall),
                  Expanded(
                    child: Text(
                      _isRequestingCode
                          ? 'Sending your SMS code...'
                          : _codeSent
                          ? 'Code sent. Enter the 6-digit SMS code below.'
                          : 'Preparing your verification code...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green[700],
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
              onPressed:
                  (_isVerifying || _isRequestingCode || !_codeSent || _verificationId == null)
                      ? null
                      : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kLinkodGreen,
                foregroundColor: Colors.white,
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
                  (_isVerifying || _isRequestingCode || _resendCooldown > 0)
                      ? null
                      : _resendOtp,
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
                          : _kLinkodGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: kPaddingLarge),

            // Info section
            Container(
              padding: const EdgeInsets.all(kPaddingMedium),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF163125) : Colors.green[50],
                border: Border.all(
                  color: isDarkMode ? const Color(0xFF2D6A4F) : Colors.green[200]!,
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
                        color: Colors.green[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Important',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kPaddingSmall),
                  _buildInfoBullet('Make sure your phone can receive SMS messages'),
                  _buildInfoBullet('If the code does not arrive, tap Resend Code'),
                  _buildInfoBullet('Do not share your code with anyone'),
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
                  ? _kLinkodGreen
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
        enabled: !_isVerifying && !_isRequestingCode && _codeSent,
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
                color: isDarkMode ? Colors.green[400] : Colors.green[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.green[200] : Colors.green[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
