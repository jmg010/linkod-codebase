# OTP Integration Examples

Ready-to-use code snippets for integrating OTP verification into your registration flow.

## Example 1: Simple Registration Flow

```dart
import 'package:flutter/material.dart';
import 'screens/phone_registration_screen.dart';

class RegistrationStartScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'New to LINKod?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PhoneRegistrationScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.phone_verified),
              label: const Text('Register with Phone'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Example 2: Registration with Profile Completion

```dart
import 'package:flutter/material.dart';
import 'screens/phone_registration_screen.dart';
import 'screens/profile_completion_screen.dart';

class RegistrationFlowScreen extends StatefulWidget {
  @override
  State<RegistrationFlowScreen> createState() => _RegistrationFlowScreenState();
}

class _RegistrationFlowScreenState extends State<RegistrationFlowScreen> {
  String? _verifiedPhoneNumber;

  @override
  Widget build(BuildContext context) {
    // If phone not verified, show registration screen
    if (_verifiedPhoneNumber == null) {
      return PhoneRegistrationScreen();
    }

    // After phone verification, proceed to profile completion
    return ProfileCompletionScreen(
      phoneNumber: _verifiedPhoneNumber!,
      onComplete: () {
        // Complete registration and navigate to main app
        Navigator.of(context).pushReplacementNamed('/home');
      },
    );
  }
}
```

## Example 3: Handle OTP Result

```dart
// In your registration screen
Future<void> _startPhoneRegistration() async {
  final result = await Navigator.of(context).push<dynamic>(
    MaterialPageRoute(
      builder: (_) => const PhoneRegistrationScreen(),
    ),
  );

  if (result != null) {
    setState(() {
      _verifiedPhoneNumber = result['phoneNumber'];
    });
    // Continue with next registration step
    _continueToProfileSetup();
  } else {
    // User canceled registration
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registration cancelled')),
    );
  }
}
```

## Example 4: Direct OTP Screen Access (for device verification)

```dart
import 'screens/otp_verification_screen.dart';
import 'services/fcm_token_service.dart';

Future<void> _verifyDevicePhone() async {
  final token = await FcmTokenService.instance.getTokenForAwaitingApproval();

  if (token == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not get device token')),
    );
    return;
  }

  final result = await Navigator.of(context).push<dynamic>(
    MaterialPageRoute(
      builder: (_) => OtpVerificationScreen(
        phoneNumber: _phoneNumber,
        fcmToken: token,
      ),
    ),
  );

  if (result?['verified'] == true) {
    _handleDeviceVerified();
  }
}
```

## Example 5: Custom OTP Display (Alternative UI)

```dart
import 'services/otp_service.dart';

class CustomOtpDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: OtpService.instance.otpStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('Waiting for OTP...');
        }

        final otp = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.green[50],
            border: Border.all(color: Colors.green),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text(
                'Code Received!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                otp,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Code will be used automatically',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

## Example 6: Testing OTP Service Manually

```dart
import 'services/otp_service.dart';
import 'services/fcm_token_service.dart';

Future<void> _manualTestOtp() async {
  try {
    // Get FCM token
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) throw Exception('No FCM token available');

    // Request OTP
    print('Requesting OTP for +1234567890...');
    final success = await OtpService.instance.requestOtp(
      phoneNumber: '+1234567890',
      fcmToken: token,
    );

    if (success) {
      print('✓ OTP request successful');

      // Simulate receiving OTP from FCM
      // (In real app, this comes via push notification)
      await Future.delayed(const Duration(seconds: 2));
      OtpService.instance.handleOtpFromFcm(
        otp: '123456',  // This would come from real FCM
        phoneNumber: '+1234567890',
      );

      // Verify OTP
      print('Verifying OTP...');
      final verified = await OtpService.instance.verifyOtp(
        phoneNumber: '+1234567890',
        otp: '123456',
      );

      if (verified) {
        print('✓ OTP verification successful');
      }
    } else {
      print('✗ Rate limited');
    }
  } catch (e) {
    print('✗ Error: $e');
  }
}
```

## Example 7: OTP with Error Recovery

```dart
import 'services/otp_service.dart';

class RobustOtpFlow {
  static Future<String?> verifyPhoneWithRetry({
    required String phoneNumber,
    required String fcmToken,
    int maxAttempts = 3,
  }) async {
    int attempts = 0;

    while (attempts < maxAttempts) {
      try {
        // Request OTP
        final success = await OtpService.instance.requestOtp(
          phoneNumber: phoneNumber,
          fcmToken: fcmToken,
        );

        if (!success) {
          // Rate limited
          return null;
        }

        // Wait for user to verify (with timeout)
        final verificationTimeout = Duration(minutes: 3);
        final verified = await _waitForVerification(
          phoneNumber: phoneNumber,
          timeout: verificationTimeout,
        );

        if (verified) {
          return phoneNumber;  // Success
        }

        attempts++;
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) {
          rethrow;
        }
        // Try again
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    return null;  // Failed after max attempts
  }

  static Future<bool> _waitForVerification({
    required String phoneNumber,
    required Duration timeout,
  }) async {
    // This would be implemented based on your UI flow
    // For now, return false (user should implement this)
    return false;
  }
}
```

## Example 8: Conditional Verification Flow

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'services/otp_service.dart';

class SmartRegistrationFlow extends StatefulWidget {
  @override
  State<SmartRegistrationFlow> createState() => _SmartRegistrationFlowState();
}

class _SmartRegistrationFlowState extends State<SmartRegistrationFlow> {
  Future<void> _startRegistration() async {
    final user = FirebaseAuth.instance.currentUser;

    // If user already has a verified phone, skip OTP
    final hasVerifiedPhone = await _checkVerifiedPhone();
    if (hasVerifiedPhone) {
      _navigateToProfileCompletion();
      return;
    }

    // Otherwise, require phone verification
    await _requirePhoneVerification();
  }

  Future<bool> _checkVerifiedPhone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Check if phone number is already in verifiedPhones collection
    final doc = await FirebaseFirestore.instance
        .collection('verifiedPhones')
        .doc(user.phoneNumber ?? '')
        .get();

    return doc.exists;
  }

  Future<void> _requirePhoneVerification() async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => const PhoneRegistrationScreen(),
      ),
    );

    if (result?['verified'] == true) {
      _navigateToProfileCompletion();
    }
  }

  void _navigateToProfileCompletion() {
    // Continue with registration flow
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _startRegistration,
          child: const Text('Start Registration'),
        ),
      ),
    );
  }
}
```

## Example 9: OTP Service Initialization in main.dart

```dart
import 'services/otp_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize OTP Service
  // (Optional: pre-warm the service)
  final otpService = OtpService.instance;

  // The service is now ready to receive OTP from FCM

  runApp(const LinkodApp());
}
```

## Example 10: Monitor OTP Lifecycle

```dart
import 'services/otp_service.dart';

class OtpMonitor extends StatefulWidget {
  @override
  State<OtpMonitor> createState() => _OtpMonitorState();
}

class _OtpMonitorState extends State<OtpMonitor> {
  late StreamSubscription<String> _otpSubscription;

  @override
  void initState() {
    super.initState();

    // Monitor OTP stream
    _otpSubscription = OtpService.instance.otpStream.listen(
      (otp) {
        print('📬 OTP Received: $otp');
        print('   Phone: ${OtpService.instance.getReceivedPhoneNumber()}');
        print('   Valid: ${OtpService.instance.isReceivedOtpValid()}');

        // Show toast or notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('OTP received and auto-filled'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      onError: (error) {
        print('❌ OTP Stream Error: $error');
      },
    );
  }

  @override
  void dispose() {
    _otpSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
```

---

## Integration Checklist

- [ ] Import `phone_registration_screen.dart` and `otp_verification_screen.dart`
- [ ] Add OTP service to your dependency injection (if using)
- [ ] Initialize OTP service in `main.dart`
- [ ] Testing: Verify device notifications are enabled
- [ ] Testing: Verify FCM token is being sent with OTP request
- [ ] Testing: Verify OTP arrives within 5 seconds
- [ ] Production: Deploy Cloud Functions
- [ ] Production: Update Firestore security rules
- [ ] Production: Enable Cloud Functions billing (Blaze plan)
- [ ] Production: Monitor Cloud Functions logs for errors
