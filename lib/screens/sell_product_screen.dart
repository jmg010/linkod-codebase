import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/marketplace_categories.dart';
import '../models/product_model.dart';
import '../services/products_service.dart';
import '../services/firestore_service.dart';
import '../services/admin_settings_service.dart';

class SellProductScreen extends StatefulWidget {
  final ProductModel? existingProduct;
  final bool isEdit;

  const SellProductScreen({
    super.key,
    this.existingProduct,
    this.isEdit = false,
  });

  @override
  State<SellProductScreen> createState() => _SellProductScreenState();
}

class _SellProductScreenState extends State<SellProductScreen> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactController = TextEditingController();
  String? _selectedCategory;

  bool get _isEdit => widget.isEdit && widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingProduct != null) {
      final p = widget.existingProduct!;
      _titleController.text = p.title;
      _priceController.text = p.price.toStringAsFixed(0);
      _descriptionController.text = p.description;
      _locationController.text = p.location;
      _contactController.text = p.contactNumber;
      _selectedCategory = p.category;
    }
    if (!_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserPhone());
    }
  }

  Future<void> _loadUserPhone() async {
    final user = FirestoreService.auth.currentUser;
    if (user == null) return;
    try {
      final doc = await FirestoreService.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists || !mounted) return;
      final phone = doc.data()?['phoneNumber'] as String?;
      if (phone != null && phone.isNotEmpty) {
        _contactController.text = phone;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _handlePost() async {
    if (_titleController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to post a product')),
      );
      return;
    }

    // Get user data from Firestore
    final userDoc = await FirestoreService.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    
    if (!userDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User profile not found')),
      );
      return;
    }

    final userData = userDoc.data() as Map<String, dynamic>;
    final userName = userData['fullName'] as String? ?? 'User';

    try {
      if (_isEdit) {
        final existing = widget.existingProduct!;
        await ProductsService.updateProduct(existing.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': price,
          'category': _selectedCategory!,
          'location': _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : 'Location not specified',
          'contactNumber': _contactController.text.trim().isNotEmpty
              ? _contactController.text.trim()
              : (userData['phoneNumber'] as String? ?? ''),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product updated')),
          );
          Navigator.of(context).pop();
        }
      } else {
        // Read auto-approve settings
        final autoSettings = await AdminSettingsService.getAutoApproveSettings();
        final shouldAutoApprove = autoSettings['products'] ?? false;
        final initialStatus = shouldAutoApprove ? 'Approved' : 'Pending';

        final product = ProductModel(
          id: '', // Will be set by Firestore
          sellerId: currentUser.uid,
          sellerName: userName,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: price,
          category: _selectedCategory!,
          createdAt: DateTime.now(),
          isAvailable: true,
          imageUrls: [], // Can be added later with image picker
          location: _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : 'Location not specified',
          contactNumber: _contactController.text.trim().isNotEmpty
              ? _contactController.text.trim()
              : (userData['phoneNumber'] as String? ?? ''),
          status: initialStatus, // Set based on auto-approve flag
        );

        await ProductsService.createProduct(product);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(shouldAutoApprove
                  ? 'Your listing has been posted!'
                  : 'Your listing is pending admin approval.'),
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    padding: EdgeInsets.zero,
                    splashRadius: 22,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isEdit ? 'Edit product' : 'Post a product',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Image picker coming soon')),
                  );
                },
                child: Container(
                  height: 190,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E3E3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 70,
                        height: 70,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.image_outlined,
                                size: 46, color: Color(0xFF646464)),
                            Positioned(
                              right: 4,
                              top: 6,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tap to add photos',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4C4C4C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Title ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              _buildInputField(controller: _titleController, hint: 'Enter product title'),
              const SizedBox(height: 14),
              const Text('Price ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              _buildInputField(
                controller: _priceController,
                hint: 'Enter price',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              const Text('Description ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              _buildInputField(
                controller: _descriptionController,
                hint: 'Describe your product',
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              const Text('Category *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    hint: const Text('Select category'),
                    items: MarketplaceCategories.ids.map((id) {
                      return DropdownMenuItem(
                        value: id,
                        child: Text(MarketplaceCategories.label(id)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Location', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              _buildInputField(
                controller: _locationController,
                hint: 'Enter location',
              ),
              const SizedBox(height: 14),
              const Text('Contact Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              _buildInputField(
                controller: _contactController,
                hint: 'Enter contact number',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handlePost,
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
                    'Post',
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final bool isMultiline = maxLines > 1;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: isMultiline ? maxLines : 1,
        minLines: isMultiline ? maxLines : 1,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ).copyWith(hintText: hint),
      ),
    );
  }
}

