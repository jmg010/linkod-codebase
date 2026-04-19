import 'package:flutter/material.dart';
import 'package:linkod_platform/screens/otp_verification_screen.dart';
import 'package:linkod_platform/screens/reset_password_screen.dart';
import 'package:linkod_platform/services/password_reset_service.dart';

const Color _kLinkodGreen = Color(0xFF00A651);

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final phoneController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;
  final passwordResetService = PasswordResetService();

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  bool _isValidPhoneNumber(String phone) {
    // Valid formats: 09xxxxxxxxx (11 digits) or 9xxxxxxxxx (10 digits)
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length == 10) {
      // 9xxxxxxxxx format - add leading 0
      return cleanPhone.startsWith('9');
    } else if (cleanPhone.length == 11) {
      // 09xxxxxxxxx format
      return cleanPhone.startsWith('09');
    }
    return false;
  }

  String _normalizePhoneNumber(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length == 10 && cleanPhone.startsWith('9')) {
      return '0$cleanPhone';
    }
    return cleanPhone;
  }

  Future<void> _handleLookupAndVerify() async {
    final phone = phoneController.text.trim();

    if (phone.isEmpty) {
      setState(() => errorMessage = 'Please enter your phone number');
      return;
    }

    if (!_isValidPhoneNumber(phone)) {
      setState(() =>
          errorMessage =
              'Phone number must be 10 or 11 digits\n(e.g., 09xxxxxxxxx or 9xxxxxxxxx)');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final normalizedPhone = _normalizePhoneNumber(phone);

      // Look up user by phone
      final userInfo = await passwordResetService.lookupUserByPhone(normalizedPhone);
      final exists = userInfo['exists'] == true;
      if (!exists) {
        throw PasswordResetException(
          message:
              'No account found with this phone number. Please check and try again.',
        );
      }

      if (!mounted) return;

      // Navigate to OTP verification screen with returnResultOnSuccess=true
      final verificationResult = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            phoneNumber: normalizedPhone,
            fcmToken: '', // Not needed for forgot password
            returnResultOnSuccess: true, // Return result instead of navigating
            keepSignedInOnSuccess: true,
          ),
        ),
      );

      if (!mounted) return;

      // Check if OTP was verified
      if (verificationResult != null && verificationResult['verified'] == true) {
        // Navigate to reset password screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(
              phone: normalizedPhone,
            ),
          ),
        );
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : _kLinkodGreen,
        title: const Text('Forgot Password'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Reset Your Password',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your phone number to verify and reset your password',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // Error message
            if (errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Phone input
            TextField(
              controller: phoneController,
              enabled: !isLoading,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g., 09123456789',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                errorText:
                    phoneController.text.isNotEmpty && !_isValidPhoneNumber(phoneController.text)
                        ? 'Invalid phone number'
                        : null,
              ),
              onChanged: (value) {
                // Trigger rebuild to validate
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 32),

            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How it works:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '1. Enter your registered phone number\n'
                          '2. We\'ll send an OTP code to your phone\n'
                          '3. Verify the code\n'
                          '4. Set your new password',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleLookupAndVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Continue with Phone Verification',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
