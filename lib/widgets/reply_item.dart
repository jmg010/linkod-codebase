import 'package:flutter/material.dart';
import '../models/message_model.dart';
import 'message_bubble.dart';

/// Reply item widget with thread line and indentation.
/// Displays a reply message nested under its parent with a vertical thread line.
class ReplyItem extends StatelessWidget {
  final MessageModel reply;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final bool canDelete;
  final String? avatarUrl;
  final String? purok;
  final String? phoneNumber;

  const ReplyItem({
    super.key,
    required this.reply,
    this.onDelete,
    this.onReply,
    this.canDelete = false,
    this.avatarUrl,
    this.purok,
    this.phoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thread line
          Container(
            width: 2,
            margin: const EdgeInsets.only(left: 40, right: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          // Reply content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MessageBubble(
                    sender: reply.senderName,
                    message: reply.message,
                    isSeller: reply.isSeller,
                    isReply: true,
                    avatarUrl: avatarUrl,
                    purok: purok,
                    phoneNumber: phoneNumber,
                  ),
                  // Reply and Delete buttons row
                  if (onReply != null || (canDelete && onDelete != null))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (onReply != null)
                            TextButton(
                              onPressed: onReply,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF20BF6B),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Reply',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (canDelete && onDelete != null) ...[
                            if (onReply != null) const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _confirmDelete(context),
                              style: TextButton.styleFrom(
                                foregroundColor: secondaryColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Delete',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        title: Text(
          'Delete reply?',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will remove your reply. This action cannot be undone.',
          style: TextStyle(
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFF20BF6B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      onDelete?.call();
    }
  }
}

/// A list of replies with thread line visualization.
class ReplyThread extends StatelessWidget {
  final List<MessageModel> replies;
  final Map<String, Map<String, String?>> userDataCache;
  final Function(String)? onDeleteReply;
  final Function(String, String)? onReply;
  final String? currentUserId;

  const ReplyThread({
    super.key,
    required this.replies,
    this.userDataCache = const {},
    this.onDeleteReply,
    this.onReply,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: replies.map((reply) {
        final userData = userDataCache[reply.senderId];
        return ReplyItem(
          reply: reply,
          onDelete: onDeleteReply != null ? () => onDeleteReply!(reply.id) : null,
          onReply: onReply != null ? () => onReply!(reply.id, reply.senderName) : null,
          canDelete: reply.senderId == currentUserId,
          avatarUrl: userData?['avatarUrl'],
          purok: userData?['purok'],
          phoneNumber: userData?['phoneNumber'],
        );
      }).toList(),
    );
  }
}
