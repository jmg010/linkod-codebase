import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/fcm_token_service.dart';
import '../services/name_formatter.dart';
import '../services/storage_service.dart';
import '../widgets/xfile_preview_image.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';

/// Philippines mobile: 10 digits (9XX XXX XXXX) or 11 with leading 0 (09XX XXX XXXX). Max 11 digits.
const int kPhilippineMobileMaxDigits = 11;
const int kPhilippineMobileMinDigits = 10;

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  static const String _termsVersion = '2026-03-29';

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

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
    phoneController.dispose();
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
                          "Create an account",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // FIRST NAME
                      const Text("First Name "),
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
                      const Text("Middle Name "),
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
                      const Text("Last Name "),
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

                      // PHONE NUMBER (Philippines: 09XX XXX XXXX, max 11 digits)
                      const Text("Phone Number "),
                      const SizedBox(height: 6),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 13,
                        decoration: InputDecoration(
                          hintText: '09XX XXX XXXX',
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // PUROK
                      const Text("Purok "),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPurok,
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
                      const Text("Password (min 6 characters) "),
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

                      const SizedBox(height: 18),

                      const Text(
                        'Sub-demography (optional)',
                        style: TextStyle(fontWeight: FontWeight.w600),
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
                        const Text(
                          'Add household sub-demographies:',
                          style: TextStyle(fontWeight: FontWeight.w600),
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
                                            : Colors.black,
                                  ),
                                  backgroundColor: Colors.grey[200],
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
                            child:
                                isLoading
                                    ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                    : const Text(
                                      'Request sign up',
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
    if (digits.length == 10 && !digits.startsWith('0')) {
      return '0$digits'; // 9XXXXXXXXX -> 09XXXXXXXXX
    }
    if (digits.length == 10 && digits.startsWith('0')) {
      return digits; // 0XXXXXXXXX: don't add 0 (would be 009...)
    }
    if (digits.length == 12 && digits.startsWith('63')) {
      return '0${digits.substring(2)}';
    }
    return digits; // fallback: return as-is
  }

  /// Save registration data for auto-fill on login screen
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

  Future<void> _signup() async {
    final firstName = firstNameController.text.trim();
    final middleName = middleNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final phoneRaw = phoneController.text.trim();
    final password = passwordController.text;

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        phoneRaw.isEmpty ||
        password.isEmpty) {
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

    final digitsOnly = _digitsOnly(phoneRaw);
    if (digitsOnly.length < kPhilippineMobileMinDigits ||
        digitsOnly.length > kPhilippineMobileMaxDigits) {
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
      // Get FCM token before OTP (don't create account yet)
      final fcmToken =
          await FcmTokenService.instance.getTokenForAwaitingApproval();

      if (!mounted) return;

      // Navigate to OTP verification BEFORE creating Firebase Auth account
      // This ensures user is not signed in if OTP verification fails
      final verificationResult = await Navigator.of(
        context,
      ).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder:
              (context) => OtpVerificationScreen(
                phoneNumber: phone,
                fcmToken: fcmToken ?? '',
              ),
        ),
      );

      // Only create account AFTER OTP verification succeeds
      if (verificationResult != null &&
          verificationResult['verified'] == true) {
        if (!mounted) return;

        final firestore = FirebaseFirestore.instance;
        final email = '$phone@linkod.com';

        // NOW create Firebase Auth account after phone verification
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
            (fcmToken != null && fcmToken.isNotEmpty) ? [fcmToken] : <String>[];

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
          'phoneNumber': phone,
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
        await _saveRegistrationData(phone, password, selectedPurokNumber);

        // Sign out so they see login screen with "pending approval" message
        await FirebaseAuth.instance.signOut();

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      } else if (mounted) {
        // OTP verification was cancelled or failed
        setState(() => isLoading = false);
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
                  child: const Icon(Icons.check, size: 50, color: Colors.white),
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
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
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
