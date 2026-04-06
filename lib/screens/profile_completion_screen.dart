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
  static const String _termsVersion = '2026-03-29';

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool obscure = true;
  bool isLoading = false;
  bool _noMiddleName = false;
  bool _acceptedTerms = false;
  String? _selectedPurok;

  /// Proof of residence: picked file is uploaded to Firebase Storage on submit; URL stored in awaitingApproval.
  XFile? _proofFile;

  // Demographic categories
  final List<String> categories = [
    "Senior",
    "Pregnant/Lactating Mother",
    "Student",
    "PWD",
    "Youth",
    "Farmer",
    "Fisherman",
    "Public Utility Drivers",
    "Small Business Owner",
    "4Ps",
    "Tanod",
    "Barangay Official",
    "Barangay Health Worker(BHW)",
    "Indigenous People(IP)",
    "Parent",
  ];

  final List<String> selectedCategories = [];
  bool _enableSubDemography = false;
  final List<String> _selectedSubDemographies = [];
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
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double buttonWidth = MediaQuery.of(context).size.width * 0.7;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final formSurfaceColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final formTextColor = isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = isDarkMode ? Colors.white70 : Colors.grey;
    final inputFillColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final inputBorderColor = isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey.shade400;
    final chipBackground = isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[200];

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
                decoration: BoxDecoration(
                  color: formSurfaceColor,
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
                      Center(
                        child: Text(
                          "Complete your profile",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: formTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          "Phone: ${widget.phoneNumber}",
                          style: TextStyle(
                            fontSize: 16,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // FIRST NAME
                      Text("First Name", style: TextStyle(color: formTextColor)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: firstNameController,
                        style: TextStyle(color: formTextColor),
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // MIDDLE NAME
                      Text("Middle Name", style: TextStyle(color: formTextColor)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: middleNameController,
                        enabled: !_noMiddleName,
                        style: TextStyle(color: formTextColor),
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText:
                              _noMiddleName ? 'No middle name selected' : null,
                          hintStyle: TextStyle(
                            color: isDarkMode ? Colors.white54 : Colors.black45,
                          ),
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: inputBorderColor),
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
                      Text("Last Name", style: TextStyle(color: formTextColor)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: lastNameController,
                        style: TextStyle(color: formTextColor),
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // PUROK
                      Text("Purok", style: TextStyle(color: formTextColor)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPurok,
                        dropdownColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                        style: TextStyle(color: formTextColor),
                        decoration: InputDecoration(
                          hintText: 'Select your Purok',
                          hintStyle: TextStyle(
                            color: isDarkMode ? Colors.white54 : Colors.black45,
                          ),
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: inputBorderColor),
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
                      Text(
                        "Password (min 6 characters)",
                        style: TextStyle(color: formTextColor),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passwordController,
                        obscureText: obscure,
                        style: TextStyle(color: formTextColor),
                        decoration: InputDecoration(
                          hintText: 'At least 6 characters',
                          hintStyle: TextStyle(
                            color: isDarkMode ? Colors.white54 : Colors.black45,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () => setState(() => obscure = !obscure),
                          ),
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text(
                        "Confirm Password",
                        style: TextStyle(color: formTextColor),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: obscure,
                        style: TextStyle(color: formTextColor),
                        decoration: InputDecoration(
                          hintText: 'Re-type your password',
                          hintStyle: TextStyle(
                            color: isDarkMode ? Colors.white54 : Colors.black45,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () => setState(() => obscure = !obscure),
                          ),
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text(
                        "Proof of residence (optional)",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: formTextColor,
                        ),
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
                            color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
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
                                    color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      Text(
                        "Select your demographic categories:",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: formTextColor,
                        ),
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
                                    isSelected
                                      ? Colors.white
                                      : (isDarkMode
                                        ? Colors.white70
                                        : Colors.black),
                                ),
                                backgroundColor: chipBackground,
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

                      const SizedBox(height: 18),

                      Text(
                        'Sub-demography (optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: formTextColor,
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'I represent household members without phones',
                        ),
                        value: _enableSubDemography,
                        onChanged: (value) {
                          setState(() {
                            _enableSubDemography = value ?? false;
                            if (!_enableSubDemography) {
                              _selectedSubDemographies.clear();
                            }
                          });
                        },
                      ),
                      if (_enableSubDemography) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Add household sub-demographies:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: formTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              categories.map((cat) {
                                final bool isSelected = _selectedSubDemographies
                                    .contains(cat);
                                return FilterChip(
                                  label: Text(cat),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFF00A651),
                                  labelStyle: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.white
                                        : (isDarkMode
                                          ? Colors.white70
                                          : Colors.black),
                                  ),
                                  backgroundColor: chipBackground,
                                  onSelected: (value) {
                                    setState(() {
                                      if (value) {
                                        _selectedSubDemographies.add(cat);
                                      } else {
                                        _selectedSubDemographies.remove(cat);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                        ),
                      ],

                      const SizedBox(height: 14),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _acceptedTerms,
                        onChanged: (value) {
                          setState(() => _acceptedTerms = value ?? false);
                        },
                        title: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          children: [
                            const Text('I agree to the'),
                            InkWell(
                              onTap: _showTermsAndConditions,
                              child: const Text(
                                'Terms and Conditions',
                                style: TextStyle(
                                  color: Color(0xFF00A651),
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const Text('of LINKod.'),
                          ],
                        ),
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
    final confirmPassword = confirmPasswordController.text;

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

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    if (selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category.')),
      );
      return;
    }

    if (_enableSubDemography && _selectedSubDemographies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one sub-demography.'),
        ),
      );
      return;
    }

    if (_selectedPurok == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your purok.')),
      );
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms and Conditions to continue.'),
        ),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not create account. Please try again.'),
            ),
          );
        }
        return;
      }

      final mergedCategories =
          <String>{
            ...selectedCategories,
            if (_enableSubDemography) ..._selectedSubDemographies,
          }.toList();

      // Keep legacy category string for compatibility while also writing categories array.
      final categoryString = mergedCategories.join(', ');

      // Upload proof of residence to Firebase Storage if one was selected
      String? proofOfResidenceUrl;
      if (_proofFile != null) {
        proofOfResidenceUrl = await StorageService.instance
            .uploadImageFromXFile(_proofFile!, StorageService.proofPath(uid));
      }

      final fcmTokens =
          (widget.fcmToken.isNotEmpty) ? [widget.fcmToken] : <String>[];

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
        'categories': mergedCategories,
        'subDemographyEnabled': _enableSubDemography,
        'subDemographies':
            _enableSubDemography
                ? List<String>.from(_selectedSubDemographies)
                : <String>[],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'termsAccepted': true,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
        'termsVersion': _termsVersion,
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

  void _showTermsAndConditions() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'LINKod Terms and Conditions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Effective date: $_termsVersion',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: const [
                        _TermsParagraph(
                          '1. Service scope',
                          'LINKod is a barangay communication and services platform for announcements, resident coordination, and account approval workflows. Your account access depends on barangay approval and compliance with these terms.',
                        ),
                        _TermsParagraph(
                          '2. Account details and truthful information',
                          'You agree to provide accurate profile details, contact number, and residence-related information. Impersonation, fake identity, or misleading submissions may result in denial, suspension, or removal of account access.',
                        ),
                        _TermsParagraph(
                          '3. Acceptable use',
                          'You will use LINKod only for lawful barangay-related purposes. Prohibited actions include harassment, hate speech, fraud, misinformation, unauthorized selling, malicious uploads, attempts to bypass security, or attempts to access data that is not yours.',
                        ),
                        _TermsParagraph(
                          '4. Content and moderation',
                          'Announcements and other records may be moderated by authorized barangay administrators. Content that violates barangay rules or applicable laws may be removed, and your access may be limited.',
                        ),
                        _TermsParagraph(
                          '5. Personal data processing',
                          'By continuing, you consent to the collection and processing of your registration data (such as name, phone number, purok, categories, optional proof of residence, and device token) for account verification, approvals, service notifications, and platform security.',
                        ),
                        _TermsParagraph(
                          '6. Privacy and legal basis',
                          'Data processing follows Republic Act No. 10173 (Data Privacy Act of 2012), including principles of transparency, legitimate purpose, and proportionality, and data subject rights (such as access and correction).',
                        ),
                        _TermsParagraph(
                          '7. Third-party infrastructure',
                          'LINKod uses Firebase services for authentication, cloud storage, messaging, and backend processing. As documented by Firebase privacy and security guidance, service data may be processed in Google infrastructure to provide these functions.',
                        ),
                        _TermsParagraph(
                          '8. Security responsibilities',
                          'You are responsible for keeping your credentials confidential and for activities under your account. Report suspected compromise to barangay support promptly so mitigation steps can be taken.',
                        ),
                        _TermsParagraph(
                          '9. Availability and updates',
                          'Features may be changed, paused, or updated for maintenance, compliance, or security reasons. Continued use after updates may require renewed acceptance of revised terms.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A651),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TermsParagraph extends StatelessWidget {
  final String heading;
  final String body;

  const _TermsParagraph(this.heading, this.body);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(height: 1.45),
          ),
        ],
      ),
    );
  }
}
