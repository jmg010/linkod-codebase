import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/marketplace_categories.dart';
import '../constants/purok.dart';
import '../models/product_model.dart';
import '../services/products_service.dart';
import '../services/firestore_service.dart';
import '../services/admin_settings_service.dart';
import '../services/storage_service.dart';
import '../widgets/optimized_image.dart';

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
  final _contactController = TextEditingController();
  String? _selectedCategory;

  /// Purok 1-5 for location (Barangay Cagbaoto). Default 1.
  int _selectedPurok = 1;
  final List<XFile> _pickedImages = [];

  /// When editing, URLs already on the product (user can remove).
  List<String> _existingImageUrls = [];
  final PageController _imagePageController = PageController();
  int _imagePageIndex = 0;

  /// Pricing unit: kg, pcs, piece, etc.
  static const List<String> _priceUnitOptions = [
    'pcs',
    'kg',
    'piece',
    'bunch',
    'sack',
    'liter',
    'pack',
    'box',
  ];
  String _selectedPriceUnit = 'pcs';

  bool get _isEdit => widget.isEdit && widget.existingProduct != null;
  bool get _hasAnyImages =>
      _existingImageUrls.isNotEmpty || _pickedImages.isNotEmpty;
  int get _totalImageCount => _existingImageUrls.length + _pickedImages.length;

  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingProduct != null) {
      final p = widget.existingProduct!;
      _titleController.text = p.title;
      _priceController.text = p.price.toStringAsFixed(0);
      _descriptionController.text = p.description;
      _selectedPurok = purokFromDisplayName(p.location);
      if (_selectedPurok < 1 || _selectedPurok > 5) _selectedPurok = 1;
      _contactController.text = p.contactNumber;
      _selectedCategory = p.category;
      _existingImageUrls = List<String>.from(p.imageUrls);
      _selectedPriceUnit = p.priceUnit ?? 'pcs';
      if (!_priceUnitOptions.contains(_selectedPriceUnit)) {
        _selectedPriceUnit = 'pcs';
      }
    }
    if (!_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserData());
    }
  }

  Future<void> _loadUserData() async {
    final user = FirestoreService.auth.currentUser;
    if (user == null) return;
    try {
      final doc =
          await FirestoreService.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (!doc.exists || !mounted) return;
      final data = doc.data();
      final phone = data?['phoneNumber'] as String?;
      if (phone != null && phone.isNotEmpty) {
        _contactController.text = phone;
      }
      final purok = (data?['purok'] as num?)?.toInt();
      if (purok != null && purok >= 1 && purok <= 5) {
        setState(() => _selectedPurok = purok);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _removeImageAt(int index) {
    if (index < _existingImageUrls.length) {
      setState(() {
        _existingImageUrls.removeAt(index);
        _syncImagePageAfterRemove(index);
      });
    } else {
      setState(() {
        _pickedImages.removeAt(index - _existingImageUrls.length);
        _syncImagePageAfterRemove(index);
      });
    }
  }

  void _syncImagePageAfterRemove(int removedIndex) {
    final n = _totalImageCount;
    if (n == 0) return;
    if (_imagePageIndex >= n) {
      _imagePageIndex = n - 1;
      if (_imagePageController.hasClients) {
        _imagePageController.jumpToPage(_imagePageIndex);
      }
    } else if (removedIndex <= _imagePageIndex && _imagePageIndex > 0) {
      _imagePageIndex--;
      if (_imagePageController.hasClients) {
        _imagePageController.jumpToPage(_imagePageIndex);
      }
    }
  }

  Future<void> _addMoreImages() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xFile != null && mounted) {
      setState(() => _pickedImages.add(xFile));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${_totalImageCount} image(s)')));
    }
  }

  void _openImageFullScreen(int index) {
    if (index < _existingImageUrls.length) {
      openFullScreenImages(context, _existingImageUrls, initialIndex: index);
      return;
    }
    final xFile = _pickedImages[index - _existingImageUrls.length];
    xFile.readAsBytes().then((bytes) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierColor: Colors.black,
        barrierDismissible: true,
        builder:
            (ctx) => GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              behavior: HitTestBehavior.opaque,
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.zero,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4,
                        child: Center(
                          child: Image.memory(bytes, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );
    });
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
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

    if (_isPosting) return;
    setState(() => _isPosting = true);

    // Get user data from Firestore
    final userDoc =
        await FirestoreService.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

    if (!userDoc.exists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User profile not found')));
      return;
    }

    final userData = userDoc.data() as Map<String, dynamic>;
    final userName = userData['fullName'] as String? ?? 'User';

    try {
      if (_isEdit) {
        final existing = widget.existingProduct!;
        final List<String> newUrls = [];
        for (var i = 0; i < _pickedImages.length; i++) {
          final url = await StorageService.instance.uploadImageFromXFile(
            _pickedImages[i],
            StorageService.productImagePath(currentUser.uid, i),
          );
          if (url != null) newUrls.add(url);
        }
        final imageUrls = [..._existingImageUrls, ...newUrls];
        await ProductsService.updateProduct(existing.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': price,
          'category': _selectedCategory!,
          'location': purokDisplayName(_selectedPurok),
          'contactNumber':
              _contactController.text.trim().isNotEmpty
                  ? _contactController.text.trim()
                  : (userData['phoneNumber'] as String? ?? ''),
          'imageUrls': imageUrls,
          'priceUnit': _selectedPriceUnit,
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Product updated')));
          Navigator.of(context).pop();
        }
      } else {
        // Read auto-approve settings
        final autoSettings =
            await AdminSettingsService.getAutoApproveSettings();
        final shouldAutoApprove = autoSettings['products'] ?? false;
        final initialStatus = shouldAutoApprove ? 'Approved' : 'Pending';

        final List<String> imageUrls = [];
        for (var i = 0; i < _pickedImages.length; i++) {
          final url = await StorageService.instance.uploadImageFromXFile(
            _pickedImages[i],
            StorageService.productImagePath(currentUser.uid, i),
          );
          if (url != null) imageUrls.add(url);
        }

        final product = ProductModel(
          id: '', // Will be set by Firestore
          sellerId: currentUser.uid,
          sellerName: userName,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: price,
          priceUnit: _selectedPriceUnit,
          category: _selectedCategory!,
          createdAt: DateTime.now(),
          isAvailable: true,
          imageUrls: imageUrls,
          location: purokDisplayName(_selectedPurok),
          contactNumber:
              _contactController.text.trim().isNotEmpty
                  ? _contactController.text.trim()
                  : (userData['phoneNumber'] as String? ?? ''),
          status: initialStatus, // Set based on auto-approve flag
        );

        await ProductsService.createProduct(product);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                shouldAutoApprove
                    ? 'Your listing has been posted!'
                    : 'Your listing is pending admin approval.',
              ),
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
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
                    color: isDark ? Colors.white : Colors.black87,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isEdit ? 'Edit product' : 'Post a product',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final xFile = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (xFile != null && mounted) {
                    setState(() => _pickedImages.add(xFile));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${_totalImageCount} image(s)')),
                    );
                  }
                },
                child: Container(
                  height: 190,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color:
                        _hasAnyImages
                            ? (isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.grey.shade100)
                            : (isDark
                                ? const Color(0xFF2C2C2C)
                                : const Color(0xFFE3E3E3)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      !_hasAnyImages
                          ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 70,
                                height: 70,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_outlined,
                                      size: 46,
                                      color:
                                          isDark
                                              ? Colors.grey.shade400
                                              : const Color(0xFF646464),
                                    ),
                                    Positioned(
                                      right: 4,
                                      top: 6,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color:
                                              isDark
                                                  ? const Color(0xFF4C4C4C)
                                                  : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color:
                                                isDark
                                                    ? Colors.grey.shade600
                                                    : Colors.grey.shade400,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          size: 14,
                                          color:
                                              isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tap to add photos',
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      isDark
                                          ? Colors.grey.shade400
                                          : const Color(0xFF4C4C4C),
                                ),
                              ),
                            ],
                          )
                          : Padding(
                            padding: const EdgeInsets.all(12),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                SizedBox(
                                  height: 166,
                                  width: double.infinity,
                                  child: PageView.builder(
                                    controller: _imagePageController,
                                    itemCount: _totalImageCount,
                                    onPageChanged:
                                        (i) =>
                                            setState(() => _imagePageIndex = i),
                                    itemBuilder: (context, i) {
                                      final isUrl =
                                          i < _existingImageUrls.length;
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          GestureDetector(
                                            onTap:
                                                () => _openImageFullScreen(i),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child:
                                                  isUrl
                                                      ? OptimizedNetworkImage(
                                                        imageUrl:
                                                            _existingImageUrls[i],
                                                        width: double.infinity,
                                                        height: 166,
                                                        fit: BoxFit.cover,
                                                        cacheWidth: 400,
                                                        cacheHeight: 332,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      )
                                                      : _XFilePageImage(
                                                        xFile:
                                                            _pickedImages[i -
                                                                _existingImageUrls
                                                                    .length],
                                                      ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Material(
                                              color: Colors.black54,
                                              shape: const CircleBorder(),
                                              child: InkWell(
                                                onTap: () => _removeImageAt(i),
                                                customBorder:
                                                    const CircleBorder(),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(6),
                                                  child: Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                if (_totalImageCount > 1)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 8,
                                    child: Center(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(
                                            _totalImageCount,
                                            (i) => Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                  ),
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color:
                                                    _imagePageIndex == i
                                                        ? const Color(
                                                          0xFF20BF6B,
                                                        )
                                                        : Colors.grey.shade400,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  left: 0,
                                  bottom: 0,
                                  child: Material(
                                    elevation: 2,
                                    color: const Color(0xFF20BF6B),
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      onTap: _addMoreImages,
                                      customBorder: const CircleBorder(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Icon(
                                          Icons.add,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Title ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              _buildInputField(
                controller: _titleController,
                hint: 'Enter product title',
              ),
              const SizedBox(height: 14),
              Text(
                'Price ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildInputField(
                      controller: _priceController,
                      hint: 'Enter price',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            isDark
                                ? Colors.grey.shade700
                                : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPriceUnit,
                        isDense: true,
                        dropdownColor:
                            isDark ? const Color(0xFF2C2C2C) : Colors.white,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                        items:
                            _priceUnitOptions.map((u) {
                              return DropdownMenuItem(value: u, child: Text(u));
                            }).toList(),
                        onChanged:
                            (v) =>
                                setState(() => _selectedPriceUnit = v ?? 'pcs'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Description ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              _buildInputField(
                controller: _descriptionController,
                hint: 'Describe your product',
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              Text(
                'Category *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        isDark ? Colors.grey.shade700 : const Color(0xFFE0E0E0),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    dropdownColor:
                        isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                    hint: Text(
                      'Select category',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.black54,
                      ),
                    ),
                    items:
                        MarketplaceCategories.ids.map((id) {
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
              Text(
                'Location (Purok)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: purokDisplayName(_selectedPurok),
                dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor:
                      isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        isDark
                            ? BorderSide(color: Colors.grey.shade700)
                            : BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        isDark
                            ? BorderSide(color: Colors.grey.shade700)
                            : BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                items:
                    purokLabels
                        .map(
                          (label) => DropdownMenuItem(
                            value: label,
                            child: Text(label),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null)
                    setState(
                      () => _selectedPurok = purokFromDisplayName(value),
                    );
                },
              ),
              const SizedBox(height: 14),
              Text(
                'Contact Number',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
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
                  onPressed: _isPosting ? null : _handlePost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF20BF6B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child:
                      _isPosting
                          ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : const Color(0xFFE0E0E0),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: isMultiline ? maxLines : 1,
        minLines: isMultiline ? maxLines : 1,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.black54,
          ),
        ),
      ),
    );
  }
}

/// Full-area preview for one picked image in the swipeable PageView.
class _XFilePageImage extends StatelessWidget {
  const _XFilePageImage({required this.xFile});

  final XFile xFile;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: xFile.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              color: Colors.grey.shade300,
              alignment: Alignment.center,
              child: Icon(
                Icons.broken_image_outlined,
                size: 40,
                color: Colors.grey.shade600,
              ),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            snapshot.data!,
            width: double.infinity,
            height: 166,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}
