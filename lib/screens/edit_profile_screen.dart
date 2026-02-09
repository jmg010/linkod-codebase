import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_role.dart';
import '../services/firestore_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _phoneController;
  late TextEditingController _purokController;
  late TextEditingController _nameController;
  int _selectedPurok = 1;
  File? _selectedImage;
  String? _profileImageUrl;
  String? _fullName;
  List<String> _demographyCategories = [];
  bool _isLoading = true;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _purokController = TextEditingController();
    _nameController = TextEditingController();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _purokController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final userDoc = await FirestoreService.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        // Parse demography categories from comma-separated string
        final categoryString = data?['category'] as String? ?? '';
        final categories = categoryString
            .split(',')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        setState(() {
          _fullName = data?['fullName'] as String? ?? 'User';
          _phoneController.text = data?['phoneNumber'] as String? ?? '';
          _selectedPurok = (data?['purok'] as num?)?.toInt() ?? 1;
          _purokController.text = _selectedPurok.toString();
          _nameController.text = _fullName ?? 'User';
          _profileImageUrl = data?['profileImageUrl'] as String?;
          _demographyCategories = categories;
          _isLoading = false;
        });
      } else {
        setState(() {
          _fullName = 'User';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      setState(() {
        _fullName = 'User';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateProfile() async {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to update your profile'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final purok = _selectedPurok;

    if (phone.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final updates = <String, dynamic>{
        'fullName': name,
        'phoneNumber': phone,
        'email': '$phone@linkod.com', // Update email when phone number changes
        'purok': purok,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // TODO: Upload profile image to Firebase Storage and update profileImageUrl
      // For now, we'll just update the text fields
      if (_profileImageUrl != null) {
        updates['profileImageUrl'] = _profileImageUrl;
      }

      await FirestoreService.instance
          .collection('users')
          .doc(currentUser.uid)
          .update(updates);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: ${e.toString()}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Picture Section
          Center(
            child: GestureDetector(
              onTap: _showImageSourceDialog,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF20BF6B),
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                            ? NetworkImage(_profileImageUrl!)
                            : null) as ImageProvider?,
                    child: _selectedImage == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                        ? Text(
                            (_fullName?.isNotEmpty ?? false) ? _fullName![0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF20BF6B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // User Name Field
          const Text(
            'Full Name',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(height: 32),
          // Phone Number Field
          const Text(
            'Phone Number',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(height: 24),
          // Purok Field
          const Text(
            'Purok',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _purokController,
                  readOnly: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                      onPressed: () {
                        if (_selectedPurok < 5) {
                          setState(() {
                            _selectedPurok++;
                            _purokController.text = _selectedPurok.toString();
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                      onPressed: () {
                        if (_selectedPurok > 1) {
                          setState(() {
                            _selectedPurok--;
                            _purokController.text = _selectedPurok.toString();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Demography Section (Read-only)
          const Text(
            'Demography',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _demographyCategories.isEmpty
                ? Text(
                    'No demographics set',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _demographyCategories.map((category) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF20BF6B).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF20BF6B),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contact a barangay official to update your demographics.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 32),
          // Update Profile Button
          ElevatedButton(
            onPressed: _updateProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20BF6B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Update Profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

