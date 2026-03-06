import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../services/storage_service.dart';
import '../widgets/xfile_preview_image.dart';
import 'landing_screen.dart';

/// Philippines mobile: 10–11 digits.
const int _kPhilippineMobileMinDigits = 10;
const int _kPhilippineMobileMaxDigits = 11;

/// Re-apply screen: same design as account registration.
/// proof_only = resubmit proof of residence; full = fill credentials again.
class ReapplyScreen extends StatefulWidget {
  const ReapplyScreen({
    super.key,
    required this.uid,
    this.reapplyType = 'full',
  });

  final String uid;
  final String reapplyType;

  @override
  State<ReapplyScreen> createState() => _ReapplyScreenState();
}

class _ReapplyScreenState extends State<ReapplyScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  XFile? _proofFile;
  final List<String> _categories = [
    'Senior', 'Student', 'PWD', 'Youth', 'Farmer',
    'Fisherman', 'Tricycle Driver', 'Small Business Owner',
    '4Ps', 'Barangay Official', 'Parent',
  ];
  final Set<String> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    if (widget.reapplyType == 'full') {
      _loadCurrentUser();
    }
  }

  Future<void> _loadCurrentUser() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    if (doc.exists && mounted) {
      final d = doc.data();
      _nameController.text = (d?['fullName'] as String?) ?? '';
      _phoneController.text = (d?['phoneNumber'] as String?) ?? '';
      final cat = (d?['category'] as String?) ?? '';
      if (cat.isNotEmpty) {
        _selectedCategories.addAll(cat.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  static String _digitsOnly(String input) =>
      input.replaceAll(RegExp(r'[^0-9]'), '');

  static String _normalizePhilippinePhone(String input) {
    final digits = _digitsOnly(input);
    if (digits.length == 11 && digits.startsWith('0')) return digits;
    if (digits.length == 10 && !digits.startsWith('0')) return '0$digits';
    if (digits.length == 10 && digits.startsWith('0')) return digits;
    if (digits.length == 12 && digits.startsWith('63')) return '0${digits.substring(2)}';
    return digits;
  }

  Future<void> _submitProofOnly() async {
    if (_proofFile == null) {
      setState(() => _errorMessage = 'Please add proof of residence.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final proofUrl = await StorageService.instance.uploadImageFromXFile(
        _proofFile!,
        StorageService.proofPath(widget.uid),
      );
      if (proofUrl == null && mounted) {
        setState(() {
          _errorMessage = 'Failed to upload proof. Try again.';
          _isLoading = false;
        });
        return;
      }
      final docRef = FirebaseFirestore.instance.collection('users').doc(widget.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        setState(() => _errorMessage = 'Account not found.');
        return;
      }
      final currentCount = (doc.data()?['reapplicationCount'] as int?) ?? 0;
      final updates = <String, dynamic>{
        'accountStatus': 'pending',
        'reapplicationCount': currentCount + 1,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (proofUrl != null) updates['proofOfResidenceUrl'] = proofUrl;
      await docRef.update(updates);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Re-application submitted. You will be notified when reviewed.')),
      );
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LandingScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) setState(() {
        _errorMessage = 'Failed to submit: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitFull() async {
    final name = _nameController.text.trim();
    final phoneRaw = _phoneController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Full name is required.');
      return;
    }
    final digits = _digitsOnly(phoneRaw);
    if (digits.length < _kPhilippineMobileMinDigits || digits.length > _kPhilippineMobileMaxDigits) {
      setState(() => _errorMessage = 'Enter a valid Philippine mobile number (10–11 digits).');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }
    if (_selectedCategories.isEmpty) {
      setState(() => _errorMessage = 'Select at least one category.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final phone = _normalizePhilippinePhone(phoneRaw);
      final categoryString = _selectedCategories.join(', ');
      final docRef = FirebaseFirestore.instance.collection('users').doc(widget.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        setState(() => _errorMessage = 'Account not found.');
        return;
      }
      final currentCount = (doc.data()?['reapplicationCount'] as int?) ?? 0;
      await docRef.update({
        'fullName': name,
        'phoneNumber': phone,
        'category': categoryString,
        'categories': _selectedCategories.toList(),
        'accountStatus': 'pending',
        'reapplicationCount': currentCount + 1,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Re-application submitted. You will be notified when reviewed.')),
      );
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LandingScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) setState(() {
        _errorMessage = 'Failed to submit: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isProofOnly = widget.reapplyType == 'proof_only';
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
                errorBuilder: (_, __, ___) => const SizedBox(height: 143),
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
                          'Re-apply for approval',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (isProofOnly) ...[
                        const Text(
                          'Resubmit a valid proof of residence (e.g. ID or utility bill).',
                          style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                        ),
                        const SizedBox(height: 18),
                        const Text('Proof of residence *', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          icon: Icon(_proofFile != null ? Icons.check_circle : Icons.add_photo_alternate_outlined, size: 20),
                          label: Text(_proofFile != null ? 'Photo selected' : 'Add proof of residence'),
                          onPressed: () async {
                            final picker = ImagePicker();
                            final xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                            if (xFile != null && mounted) {
                              setState(() => _proofFile = xFile);
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
                              border: Border.all(color: const Color(0xFF00A651).withOpacity(0.3)),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: XFilePreviewImage(
                              xFile: _proofFile!,
                              width: 120,
                              height: 90,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ] else ...[
                        const Text('Update your information and submit for review.', style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
                        const SizedBox(height: 18),
                        const Text('Full Name *'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text('Phone Number *'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 13,
                          decoration: InputDecoration(
                            hintText: '09XX XXX XXXX (11 digits)',
                            counterText: '',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text('Password (min 6 characters) *'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            hintText: 'At least 6 characters',
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text('Select your demographic categories:', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categories.map((cat) {
                            final isSelected = _selectedCategories.contains(cat);
                            return ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              selectedColor: const Color(0xFF00A651),
                              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                              onSelected: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedCategories.add(cat);
                                  } else {
                                    _selectedCategories.remove(cat);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Center(
                        child: SizedBox(
                          width: buttonWidth,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () => isProofOnly ? _submitProofOnly() : _submitFull(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A651),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'Submit re-application',
                                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
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
