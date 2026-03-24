import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_role.dart';
import '../services/fcm_token_service.dart';
import 'create_account_screen.dart';
import 'phone_only_registration_screen.dart';
import 'home_screen.dart';
import 'declined_status_screen.dart';
import 'suspended_status_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;
  String? phoneError;
  String? passwordError;

  @override
  void initState() {
    super.initState();
    _loadLastLoginData();
  }

  /// Load last successful login credentials for auto-fill.
  /// Falls back to last registered values if no prior login exists on device.
  Future<void> _loadLastLoginData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone =
          prefs.getString('last_login_phone') ??
          prefs.getString('last_registered_phone');
      final password =
          prefs.getString('last_login_password') ??
          prefs.getString('last_registered_password');

      if (phone != null && password != null) {
        setState(() {
          phoneController.text = phone;
          passwordController.text = password;
        });
      }
    } catch (e) {
      debugPrint('Failed to load registration data: $e');
    }
  }

  Future<void> _saveLastLoginData({
    required String phone,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_login_phone', phone);
      await prefs.setString('last_login_password', password);
    } catch (e) {
      debugPrint('Failed to save last login data: $e');
    }
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String _phoneToEmail(String phone) {
    final normalized = phone.trim();
    return '$normalized@linkod.com';
  }

  int? _extractPurokNumber(dynamic raw) {
    if (raw is num) {
      final value = raw.toInt();
      if (value >= 1 && value <= 5) return value;
    }
    if (raw is String) {
      final match = RegExp(r'(\d+)').firstMatch(raw);
      if (match != null) {
        final parsed = int.tryParse(match.group(1)!);
        if (parsed != null && parsed >= 1 && parsed <= 5) return parsed;
      }
    }
    return null;
  }

  Future<void> _recoverAndBackfillPurok({
    required String uid,
    required String loginPhone,
    required Map<String, dynamic>? userData,
  }) async {
    final existing = _extractPurokNumber(userData?['purok']);
    if (existing != null) return;

    final fromLocation = _extractPurokNumber(userData?['location']);
    if (fromLocation != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'purok': fromLocation,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    try {
      final awaitingByOwner =
          await FirebaseFirestore.instance
              .collection('awaitingApproval')
              .where('requestedByUid', isEqualTo: uid)
              .limit(1)
              .get();
      if (awaitingByOwner.docs.isNotEmpty) {
        final purok = _extractPurokNumber(
          awaitingByOwner.docs.first.data()['purok'],
        );
        if (purok != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'purok': purok,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return;
        }
      }
    } catch (_) {
      // Non-blocking: user may not have access to awaitingApproval or doc may not exist.
    }

    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('last_registered_phone');
    final savedPurok = prefs.getInt('last_registered_purok');
    if (savedPhone == loginPhone &&
        savedPurok != null &&
        savedPurok >= 1 &&
        savedPurok <= 5) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'purok': savedPurok,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _handleLogin() async {
    if (isLoading) return;

    final phone = phoneController.text.trim();
    final password = passwordController.text;

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter phone number and password.'),
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
      phoneError = null;
      passwordError = null;
    });

    try {
      final email = _phoneToEmail(phone);
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'User not found.',
        );
      }

      // Fetch Firestore user profile by UID (per schema: UID is document ID)
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      UserRole role = UserRole.resident;
      if (doc.exists) {
        final data = doc.data();
        await _recoverAndBackfillPurok(
          uid: user.uid,
          loginPhone: phone,
          userData: data,
        );
        final accountStatus =
            (data?['accountStatus'] as String?)?.toLowerCase();
        final isApproved = data?['isApproved'] as bool? ?? false;

        // Persistence & governance: route by accountStatus
        if (accountStatus == 'declined') {
          if (!mounted) return;
          final adminNote = (data?['adminNote'] as String?) ?? '';
          final reapplyType = (data?['reapplyType'] as String?) ?? 'full';
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder:
                  (context) => DeclinedStatusScreen(
                    adminNote: adminNote,
                    reapplyType: reapplyType,
                  ),
            ),
          );
          return;
        }
        if (accountStatus == 'suspended') {
          if (!mounted) return;
          final adminNote = data?['adminNote'] as String?;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SuspendedStatusScreen(adminNote: adminNote),
            ),
          );
          return;
        }
        if (accountStatus == 'pending' ||
            (!isApproved && accountStatus != 'active')) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          _showPendingApprovalDialog(context);
          return;
        }

        final roleString = (data?['role'] as String?) ?? 'resident';
        final lower = roleString.toLowerCase();
        if (lower == 'official' || lower == 'admin') {
          role = UserRole.official;
        } else if (lower == 'vendor') {
          role = UserRole.vendor;
        } else {
          role = UserRole.resident;
        }
      } else {
        // User exists in Auth but not in Firestore — still awaiting admin/kapitan approval
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _showPendingApprovalDialog(context);
        return;
      }

      if (!mounted) return;

      // Register FCM token for this device so backend can send push notifications.
      unawaited(FcmTokenService.instance.registerCurrentTokenForUser(user.uid));

      // Save last successful login for next app launch auto-fill.
      unawaited(_saveLastLoginData(phone: phone, password: password));

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomeScreen(userRole: role)),
      );
    } on FirebaseAuthException catch (e) {
      String? passErr;
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        passErr = 'Wrong Phone Number or Password.';
      } else {
        passErr = 'Failed to sign in. Please try again.';
      }
      setState(() {
        phoneError = passErr != null ? '' : null;
        passwordError = passErr;
      });
    } catch (e) {
      setState(() {
        phoneError = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// Shows a floating popup notification when the resident has no users doc or status is pending (admin/kapitan has not approved yet).
  void _showPendingApprovalDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Yellow punctuation mark icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7B500),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.priority_high,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Account Pending heading
                  const Text(
                    'Account Pending Approval',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Message
                  const Text(
                    'Your account is still not approved. It needs to be reviewed by the admin or kapitan first. '
                    'You will be able to sign in once your account has been approved.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4C4C4C),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Ok button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A651),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double buttonWidth = MediaQuery.of(context).size.width * 0.7;
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
                          "Sign in your account",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _RequiredLabel(text: "Phone Number"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorText: phoneError,
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _RequiredLabel(text: "Password (min 6 characters)"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'At least 6 characters',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorText: passwordError,
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Center(
                        child: SizedBox(
                          width: buttonWidth,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A651),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child:
                                isLoading
                                    ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                    : const Text(
                                      'Sign in',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        const PhoneOnlyRegistrationScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "Don't have an account? Create one",
                          ),
                        ),
                      ),
                    ],
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

class _RequiredLabel extends StatelessWidget {
  final String text;
  const _RequiredLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
