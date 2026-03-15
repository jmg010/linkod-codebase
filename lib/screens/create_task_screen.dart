import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/task_model.dart';
import '../services/tasks_service.dart';
import '../services/firestore_service.dart';
import '../services/admin_settings_service.dart';
import '../services/storage_service.dart';
import '../widgets/optimized_image.dart';

class CreateTaskScreen extends StatefulWidget {
  final Function(TaskModel)? onTaskCreated;
  final TaskModel? existingTask;
  final bool isEdit;

  const CreateTaskScreen({
    super.key,
    this.onTaskCreated,
    this.existingTask,
    this.isEdit = false,
  });

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedCategory;
  final List<XFile> _pickedImages = [];
  List<String> _existingImageUrls = [];
  final PageController _imagePageController = PageController();
  int _imagePageIndex = 0;

  final List<String> _categories = [
    'General',
    'Labor',
    'Tutoring',
    'Transportation',
    'Home Repair',
    'Other',
  ];

  bool get _isEdit => widget.isEdit && widget.existingTask != null;
  bool get _hasAnyImages =>
      _existingImageUrls.isNotEmpty || _pickedImages.isNotEmpty;
  int get _totalImageCount => _existingImageUrls.length + _pickedImages.length;

  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingTask != null) {
      final t = widget.existingTask!;
      _titleController.text = t.title;
      _descriptionController.text = t.description;
      _contactController.text = t.contactNumber ?? '';
      _selectedCategory = t.category;
      _existingImageUrls = List<String>.from(t.imageUrls);
      _locationController.text = t.location ?? '';
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
      final location = data?['location'] as String?;
      if (location != null && location.isNotEmpty) {
        _locationController.text = location;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    _locationController.dispose();
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
    if (!_formKey.currentState!.validate()) return;

    if (_isEdit) {
      if (_isPosting) return;
      setState(() => _isPosting = true);
      try {
        final currentUser = FirestoreService.auth.currentUser!;
        final List<String> newUrls = [];
        for (var i = 0; i < _pickedImages.length; i++) {
          final url = await StorageService.instance.uploadImageFromXFile(
            _pickedImages[i],
            StorageService.taskImagePath(currentUser.uid, i),
          );
          if (url != null) newUrls.add(url);
        }
        final imageUrls = [..._existingImageUrls, ...newUrls];
        await TasksService.updateTask(widget.existingTask!.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'contactNumber': _contactController.text.trim(),
          'category': _selectedCategory,
          'imageUrls': imageUrls,
          'location': _locationController.text.trim().isEmpty ? 'Location not specified' : _locationController.text.trim(),
        });
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your errand has been updated!'),
              duration: Duration(seconds: 2),
            ),
          );
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
      return;
    }

    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create a task')),
      );
      return;
    }

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

    if (_isPosting) return;
    setState(() => _isPosting = true);
    try {
      // Read auto-approve settings
      final autoSettings = await AdminSettingsService.getAutoApproveSettings();
      final shouldAutoApprove = autoSettings['tasks'] ?? false;
      final initialApprovalStatus = shouldAutoApprove ? 'Approved' : 'Pending';

      final List<String> imageUrls = [];
      for (var i = 0; i < _pickedImages.length; i++) {
        final url = await StorageService.instance.uploadImageFromXFile(
          _pickedImages[i],
          StorageService.taskImagePath(currentUser.uid, i),
        );
        if (url != null) imageUrls.add(url);
      }

      final task = TaskModel(
        id: '', // Will be set by Firestore
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        requesterName: userName,
        requesterId: currentUser.uid,
        createdAt: DateTime.now(),
        status: TaskStatus.open,
        priority: TaskPriority.medium,
        contactNumber:
            _contactController.text.trim().isNotEmpty
                ? _contactController.text.trim()
                : (userData['phoneNumber'] as String?),
        approvalStatus: initialApprovalStatus, // Set based on auto-approve flag
        category: _selectedCategory,
        imageUrls: imageUrls,
        location: _locationController.text.trim().isEmpty ? 'Location not specified' : _locationController.text.trim(),
      );

      await TasksService.createTask(task);

      widget.onTaskCreated?.call(task);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shouldAutoApprove
                  ? 'Your errand has been posted!'
                  : 'Your errand is pending admin approval.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
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
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isEdit ? 'Edit Errand/Job Post' : 'Create Errand/Job Post',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            // White card container with form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          hint: 'Enter task title',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Category ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildCategoryDropdown(),
                        const SizedBox(height: 16),
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
                          hint: 'Describe your task',
                          maxLines: 4,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a description';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Photos (optional) ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
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
                                SnackBar(
                                  content: Text('${_totalImageCount} image(s)'),
                                ),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                                        : const Color(
                                                          0xFF646464,
                                                        ),
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
                                                            ? const Color(
                                                              0xFF4C4C4C,
                                                            )
                                                            : Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          isDark
                                                              ? Colors
                                                                  .grey
                                                                  .shade600
                                                              : Colors
                                                                  .grey
                                                                  .shade400,
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
                                                  (i) => setState(
                                                    () => _imagePageIndex = i,
                                                  ),
                                              itemBuilder: (context, i) {
                                                final isUrl =
                                                    i <
                                                    _existingImageUrls.length;
                                                return Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    GestureDetector(
                                                      onTap:
                                                          () =>
                                                              _openImageFullScreen(
                                                                i,
                                                              ),
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        child:
                                                            isUrl
                                                                ? OptimizedNetworkImage(
                                                                  imageUrl:
                                                                      _existingImageUrls[i],
                                                                  width:
                                                                      double
                                                                          .infinity,
                                                                  height: 166,
                                                                  fit:
                                                                      BoxFit
                                                                          .cover,
                                                                  cacheWidth:
                                                                      400,
                                                                  cacheHeight:
                                                                      332,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        8,
                                                                      ),
                                                                )
                                                                : _TaskXFilePageImage(
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
                                                        shape:
                                                            const CircleBorder(),
                                                        child: InkWell(
                                                          onTap:
                                                              () =>
                                                                  _removeImageAt(
                                                                    i,
                                                                  ),
                                                          customBorder:
                                                              const CircleBorder(),
                                                          child: const Padding(
                                                            padding:
                                                                EdgeInsets.all(
                                                                  6,
                                                                ),
                                                            child: Icon(
                                                              Icons.close,
                                                              color:
                                                                  Colors.white,
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
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
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
                                                          shape:
                                                              BoxShape.circle,
                                                          color:
                                                              _imagePageIndex ==
                                                                      i
                                                                  ? const Color(
                                                                    0xFF20BF6B,
                                                                  )
                                                                  : Colors
                                                                      .grey
                                                                      .shade400,
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
                                                onTap: () async {
                                                  final picker = ImagePicker();
                                                  final xFile = await picker
                                                      .pickImage(
                                                        source:
                                                            ImageSource.gallery,
                                                        imageQuality: 85,
                                                      );
                                                  if (xFile != null &&
                                                      mounted) {
                                                    setState(
                                                      () => _pickedImages.add(
                                                        xFile,
                                                      ),
                                                    );
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          '${_totalImageCount} image(s)',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                                customBorder:
                                                    const CircleBorder(),
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
                        const SizedBox(height: 16),
                        Text(
                          'Contact Information ',
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
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter contact information';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Location ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildInputField(
                          controller: _locationController,
                          hint: 'Enter location',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a location';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isPosting ? null : _handlePost,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF20BF6B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? minLines,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMultiline = maxLines > 1;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      minLines: minLines ?? (isMultiline ? 2 : 1),
      keyboardType: keyboardType ?? (isMultiline ? TextInputType.multiline : TextInputType.text),
      textInputAction: isMultiline ? TextInputAction.newline : TextInputAction.next,
      validator: validator,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF20BF6B), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      decoration: InputDecoration(
        hintText: 'Category',
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF20BF6B), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
      ),
      items:
          _categories.map((category) {
            return DropdownMenuItem<String>(
              value: category,
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            );
          }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a category';
        }
        return null;
      },
      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF9E9E9E)),
    );
  }
}

/// Full-area preview for one picked image in the task image PageView.
class _TaskXFilePageImage extends StatelessWidget {
  const _TaskXFilePageImage({required this.xFile});

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
