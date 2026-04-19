import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linkod_platform/screens/login_screen.dart';
import 'package:linkod_platform/services/password_reset_service.dart';

const Color _kLinkodGreen = Color(0xFF00A651);

class ResetPasswordScreen extends StatefulWidget {
  final String phone;

  const ResetPasswordScreen({
    Key? key,
    required this.phone,
  }) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool showPassword = false;
  bool showConfirmPassword = false;
  bool isLoading = false;
  String? errorMessage;
  final passwordResetService = PasswordResetService();

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isPasswordStrong(String password) {
    if (password.length < 8) return false;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    return hasUppercase && hasLowercase && hasNumber;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  Future<void> _handleResetPassword() async {
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    // Validate passwords
    final passwordError = _validatePassword(password);
    if (passwordError != null) {
      setState(() => errorMessage = passwordError);
      return;
    }

    if (password != confirmPassword) {
      setState(() => errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Call the reset password function
      await passwordResetService.resetPassword(
        phone: widget.phone,
        newPassword: password,
      );

      // Clear temporary phone-auth session from forgot-password OTP flow.
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
              ),
              const SizedBox(height: 12),
              const Text(
                'Password Reset Successfully',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            'Your password has been reset. You can now log in with your new password.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700], height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                // Navigate to login screen
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
              ),
              child: const Text('Go to Login', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
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
    final surfaceColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final subtleTextColor = isDarkMode ? Colors.white70 : Colors.grey[600]!;
    final mutedBorderColor = isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey[200]!;
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;
    final isPasswordStrong = _isPasswordStrong(password);
    final passwordsMatch = password.isNotEmpty && password == confirmPassword;
    final canSubmit = isPasswordStrong && passwordsMatch && !isLoading;

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        foregroundColor: isDarkMode ? Colors.white : _kLinkodGreen,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : _kLinkodGreen,
        ),
        title: Text(
          'Create New Password',
          style: TextStyle(
            color: isDarkMode ? Colors.white : _kLinkodGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
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
              'Set Your New Password',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a strong password to secure your account',
              style: TextStyle(
                fontSize: 14,
                color: subtleTextColor,
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

            // New Password field
            TextField(
              controller: passwordController,
              enabled: !isLoading,
              obscureText: !showPassword,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock),
                prefixIconColor: _kLinkodGreen,
                floatingLabelStyle: const TextStyle(color: _kLinkodGreen),
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[50],
                suffixIcon: IconButton(
                  icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => showPassword = !showPassword),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: mutedBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kLinkodGreen),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Confirm Password field
            TextField(
              controller: confirmPasswordController,
              enabled: !isLoading,
              obscureText: !showConfirmPassword,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock),
                prefixIconColor: _kLinkodGreen,
                floatingLabelStyle: const TextStyle(color: _kLinkodGreen),
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[50],
                suffixIcon: IconButton(
                  icon: Icon(showConfirmPassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => showConfirmPassword = !showConfirmPassword),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: mutedBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kLinkodGreen),
                ),
                errorText: password.isNotEmpty && !passwordsMatch ? 'Passwords do not match' : null,
              ),
            ),
            const SizedBox(height: 24),

            // Password requirements
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF163125) : Colors.green[50],
                border: Border.all(
                  color: isDarkMode ? const Color(0xFF2D6A4F) : Colors.green[200]!,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Password Requirements:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDarkMode ? Colors.green[200] : Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _requirementItem(
                    'At least 8 characters',
                    password.length >= 8,
                  ),
                  _requirementItem(
                    'At least one uppercase letter (A-Z)',
                    password.contains(RegExp(r'[A-Z]')),
                  ),
                  _requirementItem(
                    'At least one lowercase letter (a-z)',
                    password.contains(RegExp(r'[a-z]')),
                  ),
                  _requirementItem(
                    'At least one number (0-9)',
                    password.contains(RegExp(r'[0-9]')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Match indicator
            if (password.isNotEmpty && confirmPassword.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    passwordsMatch ? Icons.check_circle : Icons.cancel,
                    color: passwordsMatch ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    passwordsMatch ? 'Passwords match' : 'Passwords do not match',
                    style: TextStyle(
                      fontSize: 12,
                      color: passwordsMatch ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: canSubmit ? _handleResetPassword : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kLinkodGreen,
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
                        'Reset Password',
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

  Widget _requirementItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isMet ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? Colors.green : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
