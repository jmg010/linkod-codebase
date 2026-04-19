import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/otp_service.dart';
import '../ui_constants.dart';
import 'otp_verification_processing_screen.dart';

const Color _kLinkodGreen = Color(0xFF00A651);

/// First step of registration: User selects country and enters phone number
///
/// **Flow**:
/// 1. User selects country code
/// 2. User enters phone number
/// 3. App validates format
/// 4. App gets FCM token
/// 5. App navigates to verification processing screen
class PhoneRegistrationScreen extends StatefulWidget {
  const PhoneRegistrationScreen({super.key});

  @override
  State<PhoneRegistrationScreen> createState() =>
      _PhoneRegistrationScreenState();
}

class _PhoneRegistrationScreenState extends State<PhoneRegistrationScreen> {
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '+1'; // Default to US
  String _selectedCountryName = 'United States';
  bool _isValidPhone = false;
  String? _error;

  // Common country codes
  final List<Map<String, String>> _countries = [
    {'code': '+1', 'name': 'United States', 'flag': '🇺🇸'},
    {'code': '+1', 'name': 'Canada', 'flag': '🇨🇦'},
    {'code': '+44', 'name': 'United Kingdom', 'flag': '🇬🇧'},
    {'code': '+63', 'name': 'Philippines', 'flag': '🇵🇭'},
    {'code': '+65', 'name': 'Singapore', 'flag': '🇸🇬'},
    {'code': '+60', 'name': 'Malaysia', 'flag': '🇲🇾'},
    {'code': '+66', 'name': 'Thailand', 'flag': '🇹🇭'},
    {'code': '+62', 'name': 'Indonesia', 'flag': '🇮🇩'},
    {'code': '+84', 'name': 'Vietnam', 'flag': '🇻🇳'},
    {'code': '+91', 'name': 'India', 'flag': '🇮🇳'},
    {'code': '+81', 'name': 'Japan', 'flag': '🇯🇵'},
    {'code': '+82', 'name': 'South Korea', 'flag': '🇰🇷'},
    {'code': '+86', 'name': 'China', 'flag': '🇨🇳'},
    {'code': '+61', 'name': 'Australia', 'flag': '🇦🇺'},
    {'code': '+49', 'name': 'Germany', 'flag': '🇩🇪'},
    {'code': '+33', 'name': 'France', 'flag': '🇫🇷'},
    {'code': '+39', 'name': 'Italy', 'flag': '🇮🇹'},
    {'code': '+34', 'name': 'Spain', 'flag': '🇪🇸'},
  ];

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_validatePhoneNumber);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _validatePhoneNumber() {
    final phoneNumber = _phoneController.text.trim();
    final fullNumber = '$_selectedCountryCode$phoneNumber';

    setState(() {
      _isValidPhone =
          OtpService.isValidPhoneNumber(fullNumber) && phoneNumber.isNotEmpty;
      _error = null;
    });
  }

  void _selectCountry() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SizedBox(
            height: 400,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select Country',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _countries.length,
                    itemBuilder: (context, index) {
                      final country = _countries[index];
                      final isSelected =
                          country['code'] == _selectedCountryCode;

                      return ListTile(
                        leading: Text(
                          country['flag']!,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(country['name']!),
                        trailing: Text(
                          country['code']!,
                          style: TextStyle(
                            color: isSelected ? _kLinkodGreen : Colors.grey,
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedCountryCode = country['code']!;
                            _selectedCountryName = country['name']!;
                          });
                          _validatePhoneNumber();
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _continueToVerification() async {
    final phoneNumber = _phoneController.text.trim();
    final fullPhoneNumber = '$_selectedCountryCode$phoneNumber';

    // Get FCM token early
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) {
      _showError('Could not get device token. Please try again.');
      return;
    }

    if (!mounted) return;

    // Navigate to processing screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => OtpVerificationProcessingScreen(
              phoneNumber: fullPhoneNumber,
              fcmToken: fcmToken,
            ),
      ),
    );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Verification'),
        elevation: 0,
        foregroundColor:
            Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : _kLinkodGreen,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kPaddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: kPaddingLarge),

            // Header
            Text(
              'Enter your phone number',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: kPaddingSmall),
            Text(
              'We\'ll send you a verification code via push notification.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: kPaddingLarge * 2),

            // Country and Phone Input
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Country Code Button
                  InkWell(
                    onTap: _selectCountry,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.grey, width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _countries.firstWhere(
                              (c) => c['code'] == _selectedCountryCode,
                              orElse: () => {'flag': '🌍'},
                            )['flag']!,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedCountryCode,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  // Phone Number Input
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 15,
                      decoration: InputDecoration(
                        hintText: 'Phone number',
                        counterText: '',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        errorText: _error,
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: kPaddingLarge),

            // Continue Button
            ElevatedButton(
              onPressed: _isValidPhone ? _continueToVerification : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kLinkodGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: kPaddingLarge),

            // Info Section
            Container(
              padding: const EdgeInsets.all(kPaddingMedium),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green[200]!),
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
                        'How it works',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kPaddingSmall),
                  _buildInfoPoint(
                    'Select your country and enter your phone number',
                  ),
                  _buildInfoPoint(
                    'We\'ll send a 6-digit code via push notification',
                  ),
                  _buildInfoPoint('Code expires in 2 minutes for security'),
                  _buildInfoPoint('Make sure notifications are enabled'),
                ],
              ),
            ),
          ],
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
