import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/fcm_token_service.dart';
import 'login_screen.dart';

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

  // Demographic categories
  final List<String> categories = [
    "Senior", "Student", "PWD", "Youth", "Farmer",
    "Fisherman", "Tricycle Driver", "Small Business Owner",
    "4Ps", "Tattoo", "Barangay Official", "Parent"
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

                      // PHONE NUMBER
                      const Text("Phone Number *"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // PASSWORD
                      const Text("Password *"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passwordController,
                        obscureText: obscure,
                        decoration: InputDecoration(
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

  Future<void> _signup() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text;

    if (name.isEmpty || phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
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
      // Create Firebase Auth account first (so user can log in after approval)
      final email = _phoneToEmail(phone);
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'user-null', message: 'User not created.');
      }

      final uid = user.uid;
      final firestore = FirebaseFirestore.instance;

      // Convert categories array to comma-separated string (per schema)
      final categoryString = selectedCategories.join(', ');

      // Store approval request in awaitingApproval collection (auto-generated ID).
      // requestedByUid lets Firestore rules allow this user to update the doc (e.g. add fcmTokens).
      final docRef = await firestore.collection('awaitingApproval').add({
        'userId': uid,
        'requestedByUid': uid, // Auth uid at sign-up; required so rule allows update for addTokenToAwaitingApprovalDocument
        'fullName': name,
        'phoneNumber': phone,
        'password': password, // Store password for admin to create account after approval
        'role': 'user', // Per schema: "admin" or "user" (will be mapped to "resident" or "official")
        'category': categoryString, // Comma-separated string, not array
        'status': 'pending', // pending | approved | rejected
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Write this device's FCM token so the backend can send approval push when admin approves
      await FcmTokenService.instance.addTokenToAwaitingApprovalDocument(docRef);

      if (!mounted) return;

      // Show success dialog
      _showSuccessDialog(context);
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to create account. Please try again.';
      if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that phone number.';
      } else if (e.code == 'weak-password') {
        message = 'The password is too weak.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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