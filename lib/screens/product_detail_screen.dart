import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import '../models/product_model.dart';
import '../services/products_service.dart';
import '../services/firestore_service.dart';

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

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
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
                            Text(
                              product.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₱${product.price.toStringAsFixed(0)}/${product.category == 'Food' ? 'kg' : ''}'
                                  .trim(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildSectionTitle('Description'),
                            Text(
                              product.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildSectionTitle('Location'),
                            Text(
                              product.location,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildSectionTitle('Contact'),
                            Text(
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
                            const SizedBox(height: 16),
                            if (replyingToId == null) _buildMessageComposer(),
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