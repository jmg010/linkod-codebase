import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import '../models/product_model.dart';
import '../services/products_service.dart';
import '../services/firestore_service.dart';
import 'sell_product_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _isSending = false;
  /// Which message threads are expanded to show replies.
  Set<String> expandedMessageIds = {};
  /// When set, the next sent message will be a reply to this message ID.
  String? replyingToId;
  /// Sender name of the message we're replying to (for the indicator).
  String? replyingToName;

  /// Current product (updated after owner edits).
  late ProductModel _currentProduct;
  bool _isEditing = false;
  bool _hasMarkedMessagesRead = false;
  bool _didAddMessageFocusListener = false;
  final TextEditingController _editTitleController = TextEditingController();
  final TextEditingController _editPriceController = TextEditingController();
  final TextEditingController _editDescriptionController = TextEditingController();
  final TextEditingController _editLocationController = TextEditingController();
  final TextEditingController _editContactController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
    // Do NOT mark product messages as read here; mark only when user focuses message input or sends (see below).
    final uid = FirestoreService.auth.currentUser?.uid;
    if (uid != null && widget.product.sellerId == uid) {
      _didAddMessageFocusListener = true;
      _messageFocusNode.addListener(_onMessageFocusChanged);
    }
  }

  void _onMessageFocusChanged() {
    if (!_messageFocusNode.hasFocus) return;
    final uid = FirestoreService.auth.currentUser?.uid;
    if (uid != null && _currentProduct.sellerId == uid && !_hasMarkedMessagesRead) {
      _hasMarkedMessagesRead = true;
      ProductsService.markProductMessagesAsRead(_currentProduct.id, uid);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    if (_didAddMessageFocusListener) {
      _messageFocusNode.removeListener(_onMessageFocusChanged);
    }
    _messageFocusNode.dispose();
    _editTitleController.dispose();
    _editPriceController.dispose();
    _editDescriptionController.dispose();
    _editLocationController.dispose();
    _editContactController.dispose();
    super.dispose();
  }

  bool get _isOwner {
    final uid = FirestoreService.auth.currentUser?.uid;
    return uid != null && _currentProduct.sellerId == uid;
  }

  /// Price string without trailing slash when there is no unit (e.g. /kg for Food).
  String _priceDisplay(ProductModel product) {
    final hasUnit = product.category.toLowerCase().contains('food');
    if (hasUnit) {
      return '₱${product.price.toStringAsFixed(0)}/kg';
    }
    return '₱${product.price.toStringAsFixed(0)}';
  }

  void _startEditing() {
    _editTitleController.text = _currentProduct.title;
    _editPriceController.text = _currentProduct.price.toStringAsFixed(0);
    _editDescriptionController.text = _currentProduct.description;
    _editLocationController.text = _currentProduct.location;
    _editContactController.text = _currentProduct.contactNumber;
    setState(() => _isEditing = true);
  }

  Future<void> _openEditProductScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellProductScreen(
          existingProduct: _currentProduct,
          isEdit: true,
        ),
      ),
    );
  }

  void _cancelEditing() {
    setState(() => _isEditing = false);
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: const Text(
          'This will remove the product listing. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ProductsService.deleteProduct(_currentProduct.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _saveEditing() async {
    final title = _editTitleController.text.trim();
    final description = _editDescriptionController.text.trim();
    final location = _editLocationController.text.trim();
    final contact = _editContactController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }
    final price = double.tryParse(_editPriceController.text.trim());
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price')),
      );
      return;
    }

    try {
      await ProductsService.updateProduct(_currentProduct.id, {
        'title': title,
        'description': description,
        'price': price,
        'location': location.isEmpty ? 'Location not specified' : location,
        'contactNumber': contact,
      });
      setState(() {
        _currentProduct = ProductModel(
          id: _currentProduct.id,
          sellerId: _currentProduct.sellerId,
          sellerName: _currentProduct.sellerName,
          title: title,
          description: description,
          price: price,
          imageUrls: _currentProduct.imageUrls,
          category: _currentProduct.category,
          createdAt: _currentProduct.createdAt,
          updatedAt: DateTime.now(),
          isAvailable: _currentProduct.isAvailable,
          location: location.isEmpty ? 'Location not specified' : location,
          contactNumber: contact,
          messagesCount: _currentProduct.messagesCount,
          status: _currentProduct.status,
        );
        _isEditing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _currentProduct;
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroImage(product),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _isEditing
                                      ? TextField(
                                          controller: _editTitleController,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black,
                                          ),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          product.title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black,
                                          ),
                                        ),
                                ),
                                if (_isOwner && !_isEditing)
                                  PopupMenuButton<String>(
                                    color: Colors.white,
                                    padding: EdgeInsets.zero,
                                    icon: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: const Icon(Icons.more_vert, color: Color(0xFF4C4C4C), size: 20),
                                    ),
                                    tooltip: 'Options',
                                    onSelected: (value) {
                                      if (value == 'edit') _openEditProductScreen();
                                      if (value == 'delete') _confirmDelete();
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: ListTile(
                                          leading: Icon(Icons.edit_outlined, size: 22, color: Color(0xFF20BF6B)),
                                          title: Text('Edit'),
                                          contentPadding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: ListTile(
                                          leading: Icon(Icons.delete_outline, size: 22, color: Colors.red.shade700),
                                          title: Text('Delete', style: TextStyle(color: Colors.red.shade700)),
                                          contentPadding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ],
                                  )
                                else if (_isEditing) ...[
                                  TextButton(
                                    onPressed: _cancelEditing,
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.grey.shade700),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton(
                                    onPressed: _saveEditing,
                                    child: const Text(
                                      'Save',
                                      style: TextStyle(
                                        color: Color(0xFF20BF6B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            _isEditing
                                ? TextField(
                                    controller: _editPriceController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                    decoration: InputDecoration(
                                      prefixText: '₱ ',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  )
                                : Text(
                                    _priceDisplay(product),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                            const SizedBox(height: 16),
                            _buildSectionTitle('Description'),
                            _isEditing
                                ? TextField(
                                    controller: _editDescriptionController,
                                    maxLines: 4,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      height: 1.4,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.all(8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  )
                                : Text(
                                    product.description,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      height: 1.4,
                                    ),
                                  ),
                            const SizedBox(height: 16),
                            _buildSectionTitle('Location'),
                            _isEditing
                                ? TextField(
                                    controller: _editLocationController,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  )
                                : Text(
                                    product.location,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                            const SizedBox(height: 16),
                            _buildSectionTitle('Contact'),
                            _isEditing
                                ? TextField(
                                    controller: _editContactController,
                                    keyboardType: TextInputType.phone,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  )
                                : Text(
                                    product.contactNumber.isEmpty
                                        ? 'Not provided'
                                        : product.contactNumber,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.storefront_outlined,
                                    size: 18, color: Color(0xFF20BF6B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Seller: ${product.sellerName}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!_isEditing && replyingToId == null) ...[
                              const SizedBox(height: 16),
                              _buildMessageComposer(),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Messages',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 14),
                            StreamBuilder<List<MessageModel>>(
                              stream: ProductsService.getMessagesStream(widget.product.id),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}');
                                }

                                final messages = snapshot.data ?? [];
                                final topLevel = messages.where((m) => m.parentId == null).toList();
                                final repliesByParent = <String, List<MessageModel>>{};
                                for (final m in messages) {
                                  if (m.parentId != null) {
                                    repliesByParent.putIfAbsent(m.parentId!, () => []).add(m);
                                  }
                                }

                                if (topLevel.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Text(
                                      'No messages yet',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: topLevel.map((msg) {
                                    final replies = repliesByParent[msg.id] ?? [];
                                    final isExpanded = expandedMessageIds.contains(msg.id);
                                    final showInlineReply = replyingToId == msg.id;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _MessageBubble(
                                          sender: msg.senderName,
                                          message: msg.message,
                                          isSeller: msg.isSeller,
                                          isReply: false,
                                          onReply: () {
                                            setState(() {
                                              replyingToId = msg.id;
                                              replyingToName = msg.senderName;
                                              expandedMessageIds.add(msg.id);
                                            });
                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                              _messageFocusNode.requestFocus();
                                            });
                                          },
                                        ),
                                        if (showInlineReply)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                                            child: _buildInlineReplyComposer(
                                              replyingToName: replyingToName ?? '',
                                              onCancel: () {
                                                setState(() {
                                                  replyingToId = null;
                                                  replyingToName = null;
                                                });
                                              },
                                            ),
                                          ),
                                        if (!showInlineReply && replies.isNotEmpty)
                                          Transform.translate(
                                            offset: const Offset(0, -10),
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 14),
                                              child: TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  if (expandedMessageIds.contains(msg.id)) {
                                                    expandedMessageIds.remove(msg.id);
                                                  } else {
                                                    expandedMessageIds.add(msg.id);
                                                  }
                                                });
                                              },
                                              style: TextButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 0),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                alignment: Alignment.centerLeft,
                                              ),
                                              child: Text(
                                                isExpanded
                                                    ? 'Hide replies (${replies.length})'
                                                    : 'View replies (${replies.length})',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (isExpanded && replies.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 32.0),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  left: BorderSide(
                                                    color: Colors.grey.shade300,
                                                    width: 2,
                                                  ),
                                                ),
                                                color: Colors.grey.shade50,
                                                borderRadius: const BorderRadius.only(
                                                  bottomLeft: Radius.circular(8),
                                                  bottomRight: Radius.circular(8),
                                                ),
                                              ),
                                              padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: replies.map((r) => _MessageBubble(
                                                  sender: r.senderName,
                                                  message: r.message,
                                                  isSeller: r.isSeller,
                                                  isReply: true,
                                                )).toList(),
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                      ],
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage(ProductModel product) {
    final bool hasImage = product.imageUrls.isNotEmpty;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: hasImage
                ? Image.network(
                    product.imageUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: Colors.black87,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: Icon(
        Icons.image,
        size: 48,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Future<void> _handleSendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to send a message')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // Get user name
      final userDoc = await FirestoreService.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      final userName = userDoc.data()?['fullName'] as String? ?? 'User';
      final isSeller = currentUser.uid == widget.product.sellerId;

      await ProductsService.addMessage(
        widget.product.id,
        currentUser.uid,
        userName,
        _messageController.text.trim(),
        isSeller,
        parentId: replyingToId,
      );

      if (isSeller) {
        ProductsService.markProductMessagesAsRead(widget.product.id, currentUser.uid);
      }

      _messageController.clear();
      setState(() {
        _isSending = false;
        if (replyingToId != null) {
          expandedMessageIds.add(replyingToId!);
          replyingToId = null;
          replyingToName = null;
        }
      });
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildMessageComposer() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Drop a message',
                hintStyle: TextStyle(
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isSending ? null : _handleSendMessage,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF20BF6B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Send'),
        ),
      ],
    );
  }

  Widget _buildInlineReplyComposer({
    required String replyingToName,
    required VoidCallback onCancel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Replying to $replyingToName',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onCancel,
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Write a reply...',
                      hintStyle: TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 14,
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSending ? null : _handleSendMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20BF6B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Reply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String sender;
  final String message;
  final bool isSeller;
  final bool isReply;
  final VoidCallback? onReply;

  const _MessageBubble({
    required this.sender,
    required this.message,
    required this.isSeller,
    this.isReply = false,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(
        bottom: isReply ? 6 : 10,
        left: isSeller ? 12 : 0,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isReply ? 10 : 14,
        vertical: isReply ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: isReply ? Colors.grey.shade100 : const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(isReply ? 12 : 16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sender,
                  style: TextStyle(
                    fontSize: isReply ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: isSeller
                        ? const Color(0xFF20BF6B)
                        : Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: isReply ? 12 : 13,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          if (onReply != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 28,
              child: ElevatedButton(
                onPressed: onReply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20BF6B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text('Reply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}