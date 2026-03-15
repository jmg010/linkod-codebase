import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/message_composer.dart';
import '../widgets/message_item.dart';
import '../widgets/optimized_image.dart';
import '../models/message_model.dart';
import '../models/product_model.dart';
import '../services/notifications_service.dart';
import '../services/products_service.dart';
import '../services/firestore_service.dart';
import 'sell_product_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;
  final String? notificationId;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.notificationId,
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

  /// When replying to a sub-comment (reply), track which specific reply for UI display
  /// The actual parentId stays the same (the top-level message)
  String? replyingToSubCommentId;
  String? replyingToSubCommentName;

  /// Current product (updated after owner edits).
  late ProductModel _currentProduct;
  bool _isEditing = false;
  bool _hasMarkedMessagesRead = false;
  bool _didAddMessageFocusListener = false;
  final TextEditingController _editTitleController = TextEditingController();
  final TextEditingController _editPriceController = TextEditingController();
  final TextEditingController _editDescriptionController =
      TextEditingController();
  final TextEditingController _editLocationController = TextEditingController();
  final TextEditingController _editContactController = TextEditingController();

  /// Cache for user profile data (avatar, purok, phone) to avoid repeated fetches.
  final Map<String, Map<String, String?>> _userDataCache = {};

  /// Current user's cached profile data.
  String? _currentUserAvatarUrl;
  String? _currentUserPurok;
  String? _currentUserPhone;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;

    // Mark notification as read if opened from notification
    if (widget.notificationId != null) {
      NotificationsService.markAsRead(widget.notificationId!);
    }

    // Mark product messages as read when seller opens the screen so the red indicator clears.
    final uid = FirestoreService.auth.currentUser?.uid;
    if (uid != null && widget.product.sellerId == uid) {
      _hasMarkedMessagesRead = true;
      ProductsService.markProductMessagesAsRead(widget.product.id, uid);
      _didAddMessageFocusListener = true;
      _messageFocusNode.addListener(_onMessageFocusChanged);
    }

    // Load current user profile data for avatar and composer
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    final uid = FirestoreService.auth.currentUser?.uid;
    if (uid == null) return;

    final userData = await _fetchUserData(uid);
    if (mounted) {
      setState(() {
        _currentUserAvatarUrl = userData['avatarUrl'];
        _currentUserPurok = userData['purok'];
        _currentUserPhone = userData['phoneNumber'];
      });
    }
  }

  /// Fetches user profile data from Firestore and caches it.
  Future<Map<String, String?>> _fetchUserData(String uid) async {
    if (_userDataCache.containsKey(uid)) {
      return _userDataCache[uid]!;
    }

    try {
      final userDoc = await FirestoreService.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final userData = {
          'avatarUrl': data?['profileImageUrl'] as String?,
          'purok': data?['purok'] != null
              ? 'Purok ${data?['purok']}'
              : null,
          'phoneNumber': data?['phoneNumber'] as String?,
          'fullName': data?['fullName'] as String? ?? 'Unknown',
          'location': data?['location'] as String?,
        };
        _userDataCache[uid] = userData;
        return userData;
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }

    final emptyData = {
      'avatarUrl': null,
      'purok': null,
      'phoneNumber': null,
      'fullName': 'Unknown',
      'location': null,
    };
    _userDataCache[uid] = emptyData;
    return emptyData;
  }

  String _getCurrentUserName() {
    final uid = FirestoreService.auth.currentUser?.uid;
    if (uid == null) return 'User';
    return _userDataCache[uid]?['fullName'] ?? 'User';
  }

  /// Pre-fetches user data for all message senders that are not in cache.
  void _prefetchUserDataForMessages(List<MessageModel> messages) {
    final uniqueSenderIds = messages.map((m) => m.senderId).toSet();
    for (final senderId in uniqueSenderIds) {
      if (!_userDataCache.containsKey(senderId)) {
        _fetchUserData(senderId).then((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  void _onMessageFocusChanged() {
    if (!_messageFocusNode.hasFocus) return;
    final uid = FirestoreService.auth.currentUser?.uid;
    if (uid != null &&
        _currentProduct.sellerId == uid &&
        !_hasMarkedMessagesRead) {
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

  /// Price string with unit when set (e.g. /kg, /pcs). Legacy: infer /kg for Food category.
  String _priceDisplay(ProductModel product) {
    final unit = product.priceUnit;
    if (unit != null && unit.isNotEmpty) {
      return '₱${product.price.toStringAsFixed(0)}/$unit';
    }
    if (product.category.toLowerCase().contains('food')) {
      return '₱${product.price.toStringAsFixed(0)}/kg';
    }
    return '₱${product.price.toStringAsFixed(0)}';
  }

  void _startEditing() {
    _editTitleController.text = _currentProduct.title;
    _editPriceController.text = _currentProduct.price.toStringAsFixed(0);
    _editDescriptionController.text = _currentProduct.description;
    // Pre-fill with user account location if product location is default
    final uid = FirestoreService.auth.currentUser?.uid;
    final String? userLocation = uid != null ? (_userDataCache[uid]?['location'] as String?) : null;
    final productLocation = _currentProduct.location;
    if (productLocation == 'Location not specified' && userLocation != null && userLocation.isNotEmpty) {
      _editLocationController.text = userLocation;
    } else {
      _editLocationController.text = productLocation;
    }
    _editContactController.text = _currentProduct.contactNumber;
    setState(() => _isEditing = true);
  }

  Future<void> _openEditProductScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => SellProductScreen(
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
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete product?'),
            content: const Text(
              'This will remove the product listing. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ProductsService.deleteProduct(_currentProduct.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Product deleted')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await ProductsService.deleteMessage(_currentProduct.id, messageId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  Future<void> _saveEditing() async {
    final title = _editTitleController.text.trim();
    final description = _editDescriptionController.text.trim();
    final location = _editLocationController.text.trim();
    final contact = _editContactController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    final price = double.tryParse(_editPriceController.text.trim());
    if (price == null || price < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid price')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Product updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _currentProduct;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
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
                          color:
                              isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  isDark
                                      ? Colors.black.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.05),
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
                                  child:
                                      _isEditing
                                          ? TextField(
                                            controller: _editTitleController,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black,
                                            ),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 12,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          )
                                          : Text(
                                            product.title,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : Colors.black,
                                            ),
                                          ),
                                ),
                                if (_isOwner && !_isEditing)
                                  PopupMenuButton<String>(
                                    color:
                                        isDark
                                            ? const Color(0xFF2C2C2C)
                                            : Colors.white,
                                    padding: EdgeInsets.zero,
                                    icon: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color:
                                            isDark
                                                ? const Color(0xFF1E1E1E)
                                                : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color:
                                              isDark
                                                  ? Colors.grey.shade700
                                                  : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.more_vert,
                                        color:
                                            isDark
                                                ? Colors.white
                                                : const Color(0xFF4C4C4C),
                                        size: 20,
                                      ),
                                    ),
                                    tooltip: 'Options',
                                    onSelected: (value) {
                                      if (value == 'edit')
                                        _openEditProductScreen();
                                      if (value == 'delete') _confirmDelete();
                                    },
                                    itemBuilder:
                                        (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: ListTile(
                                              leading: Icon(
                                                Icons.edit_outlined,
                                                size: 22,
                                                color: Color(0xFF20BF6B),
                                              ),
                                              title: Text('Edit'),
                                              contentPadding: EdgeInsets.zero,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: ListTile(
                                              leading: Icon(
                                                Icons.delete_outline,
                                                size: 22,
                                                color: Colors.red.shade700,
                                              ),
                                              title: Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: Colors.red.shade700,
                                                ),
                                              ),
                                              contentPadding: EdgeInsets.zero,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ),
                                        ],
                                  )
                                else if (_isEditing) ...[
                                  TextButton(
                                    onPressed: _cancelEditing,
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
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
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                  decoration: InputDecoration(
                                    prefixText: '₱ ',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                )
                                : Text(
                                  _priceDisplay(product),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black,
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
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
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
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
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
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
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
                                const Icon(
                                  Icons.storefront_outlined,
                                  size: 18,
                                  color: Color(0xFF20BF6B),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Seller: ${product.sellerName}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          isDark ? Colors.white : Colors.black,
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
                          color:
                              isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  isDark
                                      ? Colors.black.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Messages',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 14),
                            StreamBuilder<List<MessageModel>>(
                              stream: ProductsService.getMessagesStream(
                                widget.product.id,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}');
                                }

                                final messages = snapshot.data ?? [];

                                // Pre-fetch user data for all message senders
                                _prefetchUserDataForMessages(messages);

                                final topLevel =
                                    messages
                                        .where((m) => m.parentId == null)
                                        .toList();
                                final repliesByParent =
                                    <String, List<MessageModel>>{};
                                for (final m in messages) {
                                  if (m.parentId != null) {
                                    repliesByParent
                                        .putIfAbsent(m.parentId!, () => [])
                                        .add(m);
                                  }
                                }

                                if (topLevel.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
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
                                  children:
                                      topLevel.map((msg) {
                                        final replies =
                                            repliesByParent[msg.id] ?? [];
                                        final isExpanded = expandedMessageIds
                                            .contains(msg.id);
                                        final showInlineReply =
                                            replyingToId == msg.id;

                                        // Fetch user data for message sender
                                        final senderUserData = _userDataCache[msg.senderId];

                                        // Build replies user data cache
                                        final Map<String, Map<String, String?>> repliesUserData = {};
                                        for (final reply in replies) {
                                          final userData = _userDataCache[reply.senderId];
                                          if (userData != null) {
                                            repliesUserData[reply.senderId] = userData;
                                          }
                                        }

                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            MessageItem(
                                              message: msg,
                                              replies: replies,
                                              isExpanded: isExpanded,
                                              onReply: () {
                                                setState(() {
                                                  replyingToId = msg.id;
                                                  replyingToName =
                                                      msg.senderName;
                                                  replyingToSubCommentId = null;
                                                  replyingToSubCommentName = null;
                                                  expandedMessageIds.add(
                                                    msg.id,
                                                  );
                                                });
                                                WidgetsBinding.instance
                                                    .addPostFrameCallback((_) {
                                                  _messageFocusNode
                                                      .requestFocus();
                                                });
                                              },
                                              onToggleReplies: () {
                                                setState(() {
                                                  if (expandedMessageIds
                                                      .contains(msg.id)) {
                                                    expandedMessageIds
                                                        .remove(msg.id);
                                                  } else {
                                                    expandedMessageIds
                                                        .add(msg.id);
                                                  }
                                                });
                                              },
                                              onDelete: () => _deleteMessage(msg.id),
                                              canDelete: msg.senderId == FirestoreService.auth.currentUser?.uid,
                                              onDeleteReply: (replyId) => _deleteMessage(replyId),
                                              onReplyToReply: (replyId, replySenderName) {
                                                setState(() {
                                                  replyingToId = msg.id;
                                                  replyingToName = msg.senderName;
                                                  replyingToSubCommentId = replyId;
                                                  replyingToSubCommentName = replySenderName;
                                                  expandedMessageIds.add(msg.id);
                                                });
                                                WidgetsBinding.instance
                                                    .addPostFrameCallback((_) {
                                                  _messageFocusNode
                                                      .requestFocus();
                                                });
                                              },
                                              currentUserId: FirestoreService.auth.currentUser?.uid,
                                              avatarUrl: senderUserData?['avatarUrl'],
                                              purok: senderUserData?['purok'],
                                              phoneNumber: senderUserData?['phoneNumber'],
                                              repliesUserDataCache: repliesUserData,
                                            ),
                                            if (showInlineReply)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                  left: 42,
                                                  bottom: 12,
                                                ),
                                                child:
                                                    _buildInlineReplyComposer(
                                                  replyingToName:
                                                      replyingToName ?? '',
                                                  replyingToSubCommentName: replyingToSubCommentName,
                                                  onCancel: () {
                                                    setState(() {
                                                      replyingToId = null;
                                                      replyingToName = null;
                                                      replyingToSubCommentId = null;
                                                      replyingToSubCommentName = null;
                                                    });
                                                  },
                                                ),
                                              ),
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
    final urls = product.imageUrls;
    if (!hasImage) {
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
              child: _imagePlaceholder(),
            ),
          ),
          _buildBackButton(),
        ],
      );
    }
    return _ProductImageCarousel(
      imageUrls: urls,
      onTap: openFullScreenImages,
      imagePlaceholder: _imagePlaceholder(),
      backButton: _buildBackButton(),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: 12,
      left: 12,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.7)
                    : Colors.white.withOpacity(0.85),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withOpacity(0.5)
                        : Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: Icon(Icons.image, size: 48, color: Colors.grey.shade500),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color:
            Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
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
      final userDoc =
          await FirestoreService.instance
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
        ProductsService.markProductMessagesAsRead(
          widget.product.id,
          currentUser.uid,
        );
      }

      _messageController.clear();
      setState(() {
        _isSending = false;
        if (replyingToId != null) {
          expandedMessageIds.add(replyingToId!);
          replyingToId = null;
          replyingToName = null;
          replyingToSubCommentId = null;
          replyingToSubCommentName = null;
        }
      });
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Widget _buildMessageComposer() {
    return MessageComposer(
      controller: _messageController,
      focusNode: _messageFocusNode,
      onSend: _handleSendMessage,
      isSending: _isSending,
      currentUserAvatarUrl: _currentUserAvatarUrl,
      currentUserName: _getCurrentUserName(),
    );
  }

  Widget _buildInlineReplyComposer({
    required String replyingToName,
    String? replyingToSubCommentName,
    required VoidCallback onCancel,
  }) {
    return InlineReplyComposer(
      controller: _messageController,
      focusNode: _messageFocusNode,
      replyingToName: replyingToSubCommentName ?? replyingToName,
      onCancel: onCancel,
      onReply: _handleSendMessage,
      isSending: _isSending,
      currentUserAvatarUrl: _currentUserAvatarUrl,
      currentUserName: _getCurrentUserName(),
    );
  }
}

/// Swipeable image carousel for product detail. Single image still uses PageView (one page).
class _ProductImageCarousel extends StatefulWidget {
  const _ProductImageCarousel({
    required this.imageUrls,
    required this.onTap,
    required this.imagePlaceholder,
    required this.backButton,
  });

  final List<String> imageUrls;
  final void Function(
    BuildContext context,
    List<String> urls, {
    int initialIndex,
  })
  onTap;
  final Widget imagePlaceholder;
  final Widget backButton;

  @override
  State<_ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<_ProductImageCarousel> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
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
            child: PageView.builder(
              controller: _pageController,
              itemCount: urls.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap:
                      () => widget.onTap(
                        context,
                        urls,
                        initialIndex: _currentIndex,
                      ),
                  child: OptimizedNetworkImage(
                    imageUrl: urls[index],
                    height: 180,
                    fit: BoxFit.cover,
                    cacheWidth: 800,
                    cacheHeight: 800,
                    errorWidget: widget.imagePlaceholder,
                  ),
                );
              },
            ),
          ),
        ),
        widget.backButton,
        if (urls.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                urls.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _currentIndex == i
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
