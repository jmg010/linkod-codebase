import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/otp_service.dart';
import '../ui_constants.dart';
import 'otp_verification_processing_screen.dart';

/// Simplified registration: Phone number only, then OTP, then profile details
///
/// **Flow**:
/// 1. User enters phone number
/// 2. App validates format
/// 3. App gets FCM token
/// 4. App navigates to OTP processing screen
/// 5. After OTP verification, user fills profile details
class PhoneOnlyRegistrationScreen extends StatefulWidget {
  const PhoneOnlyRegistrationScreen({super.key});

  @override
  State<PhoneOnlyRegistrationScreen> createState() =>
      _PhoneOnlyRegistrationScreenState();
}

class _PhoneOnlyRegistrationScreenState
    extends State<PhoneOnlyRegistrationScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '+63'; // Default to Philippines
  String _selectedCountryName = 'Philippines';
  bool _isValidPhone = false;
  String? _error;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Philippine country code
  final Map<String, String> _philippineCountry = {
    'code': '+63',
    'name': 'Philippines',
    'flag': '🇵🇭',
  };

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_validatePhoneNumber);
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _validatePhoneNumber() {
    final phoneNumber = _phoneController.text.trim();
    final fullNumber = '$_selectedCountryCode$phoneNumber';
    final normalized = OtpService.normalizePhone(fullNumber);

    setState(() {
      _isValidPhone =
          OtpService.isValidPhoneNumber(normalized) && phoneNumber.isNotEmpty;
      _error = null;
    });
  }

  void _showError(String message) {
    setState(() => _error = message);
  }

  Future<void> _continueToOtp() async {
    final phoneNumber = _phoneController.text.trim();
    final fullPhoneNumber = '$_selectedCountryCode$phoneNumber';
    final normalizedPhone = OtpService.normalizePhone(fullPhoneNumber);

    // Get FCM token early
    final fcmToken = await FirebaseMessaging.instance.getToken();
    debugPrint('Retrieved FCM token: ${fcmToken?.substring(0, 20)}...');
    if (fcmToken == null) {
      _showError('Could not get device token. Please try again.');
      return;
    }

    if (!mounted) return;

    // Navigate to processing screen (which will request OTP and show verification)
    debugPrint('Navigating to processing screen with phone=$normalizedPhone');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => OtpVerificationProcessingScreen(
              phoneNumber: normalizedPhone,
              fcmToken: fcmToken,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00A651),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            Semantics(
              label: 'LINKod logo',
              child: Image.asset(
                'assets/images/linkod_logo.png',
                width: 182,
                height: 143,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          "Create an account",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          "Enter your phone number to get started",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // PHONE NUMBER INPUT
                      const Text("Phone Number"),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            // Country code selector
                            InkWell(
                              onTap: () {
                                // For now, only Philippines is supported
                                // Could expand to show country picker later
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      _philippineCountry['flag']!,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _philippineCountry['code']!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Phone number input
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                maxLength: 10, // Philippine mobile: 10 digits
                                decoration: InputDecoration(
                                  hintText: '9XX XXX XXXX',
                                  counterText: '',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      Text(
                        "We'll send a verification code to this number",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // CONTINUE BUTTON
                      Center(
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.7,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isValidPhone ? _continueToOtp : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A651),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // BACK TO LOGIN
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Already have an account? Sign in',
                            style: TextStyle(color: Color(0xFF00A651)),
                          ),
                        ),
                      ),
                    ],
                  ),
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
