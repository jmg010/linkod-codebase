import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/fcm_token_service.dart';
import 'login_screen.dart';

/// Philippines mobile: 10 digits (9XX XXX XXXX) or 11 with leading 0 (09XX XXX XXXX). Max 11 digits.
const int kPhilippineMobileMaxDigits = 11;
const int kPhilippineMobileMinDigits = 10;

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscure = true;
  bool isLoading = false;
  /// Proof of residence: storage-ready. When Firebase Storage is enabled, set proofOfResidenceUrl from upload.
  String? _proofOfResidencePath;

  // Demographic categories (Tattoo removed per request)
  final List<String> categories = [
    "Senior", "Student", "PWD", "Youth", "Farmer",
    "Fisherman", "Tricycle Driver", "Small Business Owner",
    "4Ps", "Barangay Official", "Parent"
  ];

  final List<String> selectedCategories = [];

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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          "Create an account",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // FULL NAME
                      const Text("Full Name *"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // PHONE NUMBER (Philippines: 09XX XXX XXXX, max 11 digits)
                      const Text("Phone Number *"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 13,
                        decoration: InputDecoration(
                          hintText: '09XX XXX XXXX (11 digits)',
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // PASSWORD
                      const Text("Password (min 6 characters) *"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passwordController,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          hintText: 'At least 6 characters',
                          suffixIcon: IconButton(
                            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => obscure = !obscure),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text("Proof of residence (optional)", style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      const Text(
                        "Upload will be available when Firebase Storage is enabled.",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: Icon(_proofOfResidencePath != null ? Icons.check_circle : Icons.add_photo_alternate_outlined, size: 20),
                        label: Text(_proofOfResidencePath != null ? 'Photo selected' : 'Add proof of residence (e.g. ID or utility bill)'),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                          if (xFile != null && mounted) {
                            setState(() => _proofOfResidencePath = xFile.path);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Proof of residence photo selected. Upload will be available when Firebase Storage is enabled.'),
                              ),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFF00A651)),
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        "Select your demographic categories:",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories.map((cat) {
                          final bool isSelected = selectedCategories.contains(cat);
                          return ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: const Color(0xFF00A651),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                            backgroundColor: Colors.grey[200],
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  selectedCategories.add(cat);
                                } else {
                                  selectedCategories.remove(cat);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 30),

                      // SIGN UP BUTTON
                      Center(
                        child: SizedBox(
                          width: buttonWidth,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _signup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A651),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'Request sign up',
                                    style: TextStyle(fontSize: 18, color: Colors.white),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
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

  String _phoneToEmail(String phone) {
    final normalized = phone.trim();
    return '$normalized@linkod.com';
  }

  /// Returns digits-only from [input]. Used for Philippine mobile length check.
  static String _digitsOnly(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Normalize Philippine phone for storage: digits only, 11 chars (0 + 10 digits) when valid.
  /// Do not add leading 0 when input already has 10 digits starting with 0 (0XXXXXXXXX) to avoid 009...
  static String _normalizePhilippinePhone(String input) {
    final digits = _digitsOnly(input);
    if (digits.length == 11 && digits.startsWith('0')) return digits;
    if (digits.length == 10 && !digits.startsWith('0')) return '0$digits'; // 9XXXXXXXXX -> 09XXXXXXXXX
    if (digits.length == 10 && digits.startsWith('0')) return digits; // 0XXXXXXXXX: don't add 0 (would be 009...)
    if (digits.length == 12 && digits.startsWith('63')) return '0${digits.substring(2)}';
    return digits;
  }

  Future<void> _signup() async {
    final name = nameController.text.trim();
    final phoneRaw = phoneController.text.trim();
    final password = passwordController.text;

    if (name.isEmpty || phoneRaw.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }

    final digitsOnly = _digitsOnly(phoneRaw);
    if (digitsOnly.length < kPhilippineMobileMinDigits || digitsOnly.length > kPhilippineMobileMaxDigits) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid Philippine mobile number (10–11 digits, e.g. 09123456789).',
          ),
        ),
      );
      return;
    }

    final phone = _normalizePhilippinePhone(phoneRaw);

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.')),
      );
      return;
    }

    if (selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final email = '$phone@linkod.com';

      // Create Firebase Auth account so resident can log in and see "pending approval" instead of invalid credential
      final authCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = authCred.user?.uid;
      if (uid == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create account. Please try again.')),
        );
        return;
      }

      // Convert categories array to comma-separated string (per schema)
      final categoryString = selectedCategories.join(', ');

      // Get FCM token and store with request so admin can send push on approval
      final fcmToken = await FcmTokenService.instance.getTokenForAwaitingApproval();
      final fcmTokens = (fcmToken != null && fcmToken.isNotEmpty) ? [fcmToken] : <String>[];

      // Store approval request in awaitingApproval (with uid so admin can create users/{uid} on approve)
      await firestore.collection('awaitingApproval').add({
        'uid': uid,
        'fullName': name,
        'phoneNumber': phone,
        'password': password,
        'role': 'user',
        'category': categoryString,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'proofOfResidenceUrl': null,
        'fcmTokens': fcmTokens,
      });

      // Sign out so they see success and later use Login to see "pending approval" message
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Show success dialog
      _showSuccessDialog(context);
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to create account. Please try again.';
      if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that phone number. Try logging in or wait for admin approval.';
      } else if (e.code == 'weak-password') {
        message = 'The password is too weak.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } on FirebaseException catch (e) {
      String message = 'Something went wrong. Please try again.';
      if (e.code == 'permission-denied') {
        message = 'Permission denied. Please contact support.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong: ${e.toString()}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Green checkmark icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF20BF6B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                // Thank You heading
                const Text(
                  'Thank You!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                // Message
                const Text(
                  'Your request has been sent. We\'ll notify you once it\'s approved.',
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
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF20BF6B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Ok',
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
        );
      },
    );
  }
}