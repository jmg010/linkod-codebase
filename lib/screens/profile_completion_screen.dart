import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:linkod_platform/services/otp_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/fcm_token_service.dart';
import '../services/name_formatter.dart';
import '../services/storage_service.dart';
import '../widgets/xfile_preview_image.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../models/user_role.dart';

/// Profile completion screen after OTP verification
///
/// **Flow**:
/// 1. User fills out profile details (name, password, categories, proof)
/// 2. Creates Firebase Auth account
/// 3. Stores approval request
/// 4. Signs out and redirects to login
class ProfileCompletionScreen extends StatefulWidget {
  final String phoneNumber;
  final String fcmToken;

  const ProfileCompletionScreen({
    super.key,
    required this.phoneNumber,
    required this.fcmToken,
  });

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscure = true;
  bool isLoading = false;
  bool _noMiddleName = false;
  String? _selectedPurok;

  /// Proof of residence: picked file is uploaded to Firebase Storage on submit; URL stored in awaitingApproval.
  XFile? _proofFile;

  // Demographic categories (Tattoo removed per request)
  final List<String> categories = [
    "Senior",
    "Student",
    "PWD",
    "Youth",
    "Farmer",
    "Fisherman",
    "Tricycle Driver",
    "Small Business Owner",
    "4Ps",
    "Barangay Official",
    "Parent",
  ];

  final List<String> selectedCategories = [];
  final List<String> _purokOptions = const [
    'Purok 1',
    'Purok 2',
    'Purok 3',
    'Purok 4',
    'Purok 5',
  ];

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    passwordController.dispose();
    super.dispose();
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
                          "Complete your profile",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          "Phone: ${widget.phoneNumber}",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // FIRST NAME
                      const Text("First Name"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: firstNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // MIDDLE NAME
                      const Text("Middle Name"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: middleNameController,
                        enabled: !_noMiddleName,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText:
                              _noMiddleName ? 'No middle name selected' : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      CheckboxListTile(
                        value: _noMiddleName,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('I do not have a middle name'),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) {
                          setState(() {
                            _noMiddleName = value ?? false;
                            if (_noMiddleName) {
                              middleNameController.clear();
                            }
                          });
                        },
                      ),

                      const SizedBox(height: 6),

                      // LAST NAME
                      const Text("Last Name"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: lastNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // PUROK
                      const Text("Purok"),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedPurok,
                        decoration: InputDecoration(
                          hintText: 'Select your Purok',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items:
                            _purokOptions
                                .map(
                                  (purok) => DropdownMenuItem<String>(
                                    value: purok,
                                    child: Text(purok),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() => _selectedPurok = value);
                        },
                      ),

                      const SizedBox(height: 18),

                      // PASSWORD
                      const Text("Password (min 6 characters)"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passwordController,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          hintText: 'At least 6 characters',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () => setState(() => obscure = !obscure),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        "Proof of residence (optional)",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),

                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: Icon(
                          _proofFile != null
                              ? Icons.check_circle
                              : Icons.add_photo_alternate_outlined,
                          size: 20,
                        ),
                        label: Text(
                          _proofFile != null
                              ? 'Photo selected'
                              : 'Add proof of residence (e.g. ID or utility bill)',
                        ),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final xFile = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                          );
                          if (xFile != null && mounted) {
                            setState(() => _proofFile = xFile);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Proof of residence photo selected.',
                                ),
                              ),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFF00A651)),
                        ),
                      ),
                      if (_proofFile != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF00A651).withOpacity(0.3),
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              XFilePreviewImage(
                                xFile: _proofFile!,
                                width: 100,
                                height: 80,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Proof of residence will be uploaded when you submit.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      const Text(
                        "Select your demographic categories:",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            categories.map((cat) {
                              final bool isSelected = selectedCategories
                                  .contains(cat);
                              return ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                selectedColor: const Color(0xFF00A651),
                                labelStyle: TextStyle(
                                  color:
                                      isSelected ? Colors.white : Colors.black,
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

                      // CREATE ACCOUNT BUTTON
                      Center(
                        child: SizedBox(
                          width: buttonWidth,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _createAccount,
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
                                      'Request Sign Up',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
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

  Future<void> _createAccount() async {
    final firstName = firstNameController.text.trim();
    final middleName = middleNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final password = passwordController.text;

    if (firstName.isEmpty || lastName.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }

    if (!_noMiddleName && middleName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please provide your middle name or check no middle name.',
          ),
        ),
      );
      return;
    }

    final fullName = NameFormatter.buildFullName(
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      hasMiddleName: !_noMiddleName,
    );
    final displayName = NameFormatter.buildDisplayName(
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      hasMiddleName: !_noMiddleName,
    );

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
        ),
      );
      return;
    }

    if (selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category.')),
      );
      return;
    }

    if (_selectedPurok == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your purok.')),
      );
      return;
    }

    final selectedPurokNumber = int.parse(_selectedPurok!.split(' ').last);

    setState(() => isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final normalizedPhone = OtpService.normalizePhone(widget.phoneNumber);
      final email = '$normalizedPhone@linkod.com';

      // Create Firebase Auth account
      final authCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = authCred.user?.uid;
      if (uid == null) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not create account. Please try again.'),
            ),
          );
        return;
      }

      // Convert categories array to comma-separated string (per schema)
      final categoryString = selectedCategories.join(', ');

      // Upload proof of residence to Firebase Storage if one was selected
      String? proofOfResidenceUrl;
      if (_proofFile != null) {
        proofOfResidenceUrl = await StorageService.instance
            .uploadImageFromXFile(_proofFile!, StorageService.proofPath(uid));
      }

      final fcmTokens =
          (widget.fcmToken != null && widget.fcmToken.isNotEmpty)
              ? [widget.fcmToken]
              : <String>[];

      // Store approval request in awaitingApproval
      await firestore.collection('awaitingApproval').add({
        'uid': uid,
        'requestedByUid': uid,
        'firstName': firstName,
        'middleName': _noMiddleName ? '' : middleName,
        'lastName': lastName,
        'hasMiddleName': !_noMiddleName,
        'fullName': fullName,
        'displayName': displayName,
        'phoneNumber': OtpService.normalizePhone(widget.phoneNumber),
        'purok': selectedPurokNumber,
        'password': password,
        'role': 'user',
        'category': categoryString,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'proofOfResidenceUrl': proofOfResidenceUrl,
        'fcmTokens': fcmTokens,
      });

      // Backfill purok only when users/{uid} already exists (owners cannot create users docs by rules).
      final userDocRef = firestore.collection('users').doc(uid);
      final userDoc = await userDocRef.get();
      if (userDoc.exists) {
        await userDocRef.update({
          'purok': selectedPurokNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Save registration data for auto-fill on login screen
      await _saveRegistrationData(
        OtpService.normalizePhone(widget.phoneNumber),
        password,
        selectedPurokNumber,
      );

      // Sign out so they see login screen with "pending approval" message
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierColor: Colors.black.withOpacity(0.5),
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
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
                          Navigator.of(dialogContext).pop(); // Close dialog
                          Navigator.of(dialogContext).pushReplacement(
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
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to create account. Please try again.';
      if (e.code == 'email-already-in-use') {
        message =
            'An account already exists for that phone number. Try logging in or wait for admin approval.';
      } else if (e.code == 'weak-password') {
        message = 'The password is too weak.';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        setState(() => isLoading = false);
      }
    } on FirebaseException catch (e) {
      String message = 'Something went wrong. Please try again.';
      if (e.code == 'permission-denied') {
        message = 'Permission denied. Please contact support.';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: ${e.toString()}')),
        );
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _saveRegistrationData(
    String phone,
    String password,
    int selectedPurok,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_registered_phone', phone);
      await prefs.setString('last_registered_password', password);
      await prefs.setInt('last_registered_purok', selectedPurok);
    } catch (e) {
      // Silently fail if storage fails
      debugPrint('Failed to save registration data: $e');
    }
  }
}
