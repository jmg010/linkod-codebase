import 'package:flutter/material.dart';
import '../ui_constants.dart';
import 'profile_completion_screen.dart';

/// Success screen shown after successful OTP verification
///
/// **Flow**:
/// 1. Shows success animation and message
/// 2. Displays verified phone number
/// 3. Provides "Continue" button to proceed to profile completion
class OtpSuccessScreen extends StatefulWidget {
  final String phoneNumber;
  final String fcmToken;

  const OtpSuccessScreen({
    super.key,
    required this.phoneNumber,
    required this.fcmToken,
  });

  @override
  State<OtpSuccessScreen> createState() => _OtpSuccessScreenState();
}

class _OtpSuccessScreenState extends State<OtpSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Start animations
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _continue() {
    // Navigate to profile completion screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (context) => ProfileCompletionScreen(
              phoneNumber: widget.phoneNumber,
              fcmToken: widget.fcmToken,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kFacebookBlue.withOpacity(0.1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(kPaddingLarge),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Success animation
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _opacityAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green.withOpacity(0.1),
                              border: Border.all(color: Colors.green, width: 3),
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              size: 60,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: kPaddingLarge),

                  // Success message
                  Text(
                    'Phone Verified!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: kPaddingMedium),

                  // Subtitle
                  Text(
                    'Your phone number has been successfully verified.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: kPaddingLarge),

                  // Phone number display
                  Container(
                    padding: const EdgeInsets.all(kPaddingMedium),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.green[200]!),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_android,
                          color: Colors.green[600],
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.phoneNumber,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.green[800],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.verified,
                          color: Colors.green[600],
                          size: 20,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: kPaddingLarge * 2),

                  // Continue button
                  ElevatedButton(
                    onPressed: _continue,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: kFacebookBlue,
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: kPaddingLarge),

                  // Additional info
                  Container(
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
                              Icons.security,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Security Features',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: kPaddingSmall),
                        _buildFeaturePoint('✅ One-time verification code'),
                        _buildFeaturePoint('⏰ Code expires in 2 minutes'),
                        _buildFeaturePoint(
                          '🔒 Secure push notification delivery',
                        ),
                        _buildFeaturePoint(
                          '🛡️ Protected against unauthorized access',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
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
