import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/post_model.dart';
import '../models/product_model.dart';
import '../models/task_model.dart';
import '../models/user_role.dart';
import '../services/dummy_data_service.dart';
import '../ui_constants.dart';

enum CreateType {
  announcement('Announcement'),
  product('Product'),
  task('Task');

  const CreateType(this.displayName);
  final String displayName;
}

class CreatePostScreen extends StatefulWidget {
  final UserRole userRole;

  const CreatePostScreen({super.key, required this.userRole});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _aiPromptController = TextEditingController();
  final _typeFieldKey = GlobalKey<FormFieldState<CreateType>>();

  CreateType _selectedType = CreateType.announcement;
  PostCategory _selectedCategory = PostCategory.health;
  String _selectedProductCategory = 'General';
  TaskPriority _selectedPriority = TaskPriority.medium;
  final List<XFile> _selectedImages = [];
  final List<String> _selectedImagePaths = [];
  final ImagePicker _imagePicker = ImagePicker();
  final DummyDataService _dataService = DummyDataService();
  String _generatedMessage = '';
  bool _isGenerating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _aiPromptController.dispose();
    super.dispose();
  }

  Future<void> _handleImagePicker() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImages.add(image);
          _selectedImagePaths.add(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _selectedImagePaths.removeAt(index);
    });
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      switch (_selectedType) {
        case CreateType.announcement:
          final announcement = {
            'id': 'announcement-${DateTime.now().millisecondsSinceEpoch}',
            'title': _titleController.text.trim(),
            'description': _contentController.text.trim(),
            'postedBy': 'Barangay Official',
            'date': DateTime.now(),
            'category': _selectedCategory.displayName,
            'unreadCount': 0,
            'isRead': false,
          };
          _dataService.addAnnouncement(announcement);
          break;

        case CreateType.product:
          final price = double.tryParse(_priceController.text.trim());
          if (price == null || price <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter a valid price')),
            );
            return;
          }

          final product = ProductModel(
            id: 'product-${DateTime.now().millisecondsSinceEpoch}',
            sellerId: 'me',
            sellerName: 'You',
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            price: price,
            category: _selectedProductCategory,
            createdAt: DateTime.now(),
            isAvailable: true,
            imageUrls: _selectedImagePaths,
          );
          _dataService.addProduct(product);
          break;

        case CreateType.task:
          final task = TaskModel(
            id: 'task-${DateTime.now().millisecondsSinceEpoch}',
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            requesterName: 'Juan Dela Cruz',
            createdAt: DateTime.now(),
            status: TaskStatus.open,
            priority: _selectedPriority,
          );
          _dataService.addTask(task);
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedType.displayName} created successfully!'),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _generateAnnouncement() async {
    FocusScope.of(context).unfocus();
    final input = _aiPromptController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a prompt for the AI.')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedMessage = '';
    });

    await Future.delayed(const Duration(seconds: 2));

    final generated = generateAnnouncement(input);

    setState(() {
      _isGenerating = false;
      _generatedMessage = generated;
      _contentController.text = generated;
      _selectedType = CreateType.announcement;
      _typeFieldKey.currentState?.didChange(CreateType.announcement);
    });
  }

  void _postGeneratedAnnouncement() {
    if (_generatedMessage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generate an announcement first.')),
      );
      return;
    }

    _contentController.text = _generatedMessage;
    _selectedType = CreateType.announcement;
    _typeFieldKey.currentState?.didChange(CreateType.announcement);
    _handleSubmit();
  }

  static String generateAnnouncement(String input) {
    if (input.isEmpty) return '';
    final trimmed = input.trim();
    final capitalized = '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
    return '📢 Barangay Announcement:\n\n$capitalized. Please be guided accordingly.\n\n– Barangay Cagbaoto Council';
  }

  @override
  Widget build(BuildContext context) {
    final isAnnouncement = _selectedType == CreateType.announcement;
    final isProduct = _selectedType == CreateType.product;
    final isTask = _selectedType == CreateType.task;
    final isOfficial = widget.userRole == UserRole.official;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Post',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _handleSubmit,
            child: Text(
              'Submit',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: kFacebookBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Type dropdown
              DropdownButtonFormField<CreateType>(
                key: _typeFieldKey,
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Category/Module',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items:
                    CreateType.values.map((CreateType type) {
                      return DropdownMenuItem<CreateType>(
                        value: type,
                        child: Text(type.displayName),
                      );
                    }).toList(),
                onChanged: (CreateType? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedType = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              // Title field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText:
                      isTask
                          ? 'Task Title'
                          : (isProduct ? 'Product Name' : 'Title'),
                  hintText:
                      isTask
                          ? 'Enter task title'
                          : (isProduct ? 'Enter product name' : 'Enter title'),
                  prefixIcon: const Icon(Icons.title),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Price field (product only)
              if (isProduct) ...[
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price (₱)',
                    hintText: 'Enter price',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a price';
                    }
                    final price = double.tryParse(value.trim());
                    if (price == null || price <= 0) {
                      return 'Please enter a valid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              // Category dropdown (announcement or product)
              if (isAnnouncement)
                DropdownButtonFormField<PostCategory>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items:
                      PostCategory.values.map((PostCategory category) {
                        return DropdownMenuItem<PostCategory>(
                          value: category,
                          child: Text(category.displayName),
                        );
                      }).toList(),
                  onChanged: (PostCategory? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    }
                  },
                )
              else if (isProduct)
                DropdownButtonFormField<String>(
                  value: _selectedProductCategory,
                  decoration: const InputDecoration(
                    labelText: 'Product Category',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Food', child: Text('Food')),
                    DropdownMenuItem(
                      value: 'Handicrafts',
                      child: Text('Handicrafts'),
                    ),
                    DropdownMenuItem(value: 'Home', child: Text('Home')),
                    DropdownMenuItem(value: 'General', child: Text('General')),
                  ],
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedProductCategory = newValue;
                      });
                    }
                  },
                )
              else if (isTask)
                DropdownButtonFormField<TaskPriority>(
                  value: _selectedPriority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    prefixIcon: Icon(Icons.flag_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items:
                      TaskPriority.values.map((TaskPriority priority) {
                        String label;
                        switch (priority) {
                          case TaskPriority.low:
                            label = 'Low';
                            break;
                          case TaskPriority.medium:
                            label = 'Medium';
                            break;
                          case TaskPriority.high:
                            label = 'High';
                            break;
                          case TaskPriority.urgent:
                            label = 'Urgent';
                            break;
                        }
                        return DropdownMenuItem<TaskPriority>(
                          value: priority,
                          child: Text(label),
                        );
                      }).toList(),
                  onChanged: (TaskPriority? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedPriority = newValue;
                      });
                    }
                  },
                ),
              if (isAnnouncement || isProduct) const SizedBox(height: 16),
              // Content/Description field
              TextFormField(
                controller:
                    isProduct ? _descriptionController : _contentController,
                maxLines: isTask ? 6 : (isProduct ? 4 : 8),
                decoration: InputDecoration(
                  labelText:
                      isTask
                          ? 'Task Details'
                          : (isProduct ? 'Description' : 'Content'),
                  hintText:
                      isTask
                          ? 'Describe the task you need help with...'
                          : (isProduct
                              ? 'Describe your product'
                              : 'What\'s on your mind?'),
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return isTask
                        ? 'Please enter task details'
                        : (isProduct
                            ? 'Please enter product description'
                            : 'Please enter content');
                  }
                  return null;
                },
              ),
              if (isAnnouncement && isOfficial) ...[
                const SizedBox(height: 24),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generate Announcement with AI',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _aiPromptController,
                          decoration: const InputDecoration(
                            labelText: 'Enter what you want to announce',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.chat_outlined),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed:
                                  _isGenerating ? null : _generateAnnouncement,
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('Generate with AI'),
                            ),
                            if (_isGenerating) ...[
                              const SizedBox(width: 16),
                              const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_generatedMessage.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Generated Announcement',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _generatedMessage,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  _contentController.text = _generatedMessage;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'AI message copied into the editor.',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.file_copy_outlined),
                                label: const Text('Use as Draft'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _postGeneratedAnnouncement,
                                icon: const Icon(Icons.campaign_outlined),
                                label: const Text('Post Announcement'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Optional image picker placeholder
              if (isAnnouncement || isProduct) ...[
                const Text(
                  'Images (Optional)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _handleImagePicker,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add Image'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                if (_selectedImages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_selectedImages[index].path),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
              // Submit button
              ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isTask
                      ? 'Create Task'
                      : (isProduct ? 'Add Product' : 'Create Post'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
