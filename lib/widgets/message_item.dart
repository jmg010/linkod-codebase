import 'package:flutter/material.dart';
import '../models/message_model.dart';
import 'message_bubble.dart';
import 'reply_item.dart';

/// Parent message item with reply button and expandable replies.
/// Shows the main message with avatar, sender name, message bubble,
/// and a reply button below. Replies are shown indented with thread lines.
class MessageItem extends StatelessWidget {
  final MessageModel message;
  final List<MessageModel> replies;
  final bool isExpanded;
  final VoidCallback onReply;
  final VoidCallback onToggleReplies;
  final VoidCallback? onDelete;
  final bool canDelete;
  final Function(String)? onDeleteReply;
  final String? currentUserId;
  final String? avatarUrl;
  final String? purok;
  final String? phoneNumber;
  final Map<String, Map<String, String?>>? repliesUserDataCache;

  const MessageItem({
    super.key,
    required this.message,
    this.replies = const [],
    this.isExpanded = false,
    required this.onReply,
    required this.onToggleReplies,
    this.onDelete,
    this.canDelete = false,
    this.onDeleteReply,
    this.currentUserId,
    this.avatarUrl,
    this.purok,
    this.phoneNumber,
    this.repliesUserDataCache,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasReplies = replies.isNotEmpty;
    final secondaryColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Parent message bubble
        MessageBubble(
          sender: message.senderName,
          message: message.message,
          isSeller: message.isSeller,
          isReply: false,
          avatarUrl: avatarUrl,
          purok: purok,
          phoneNumber: phoneNumber,
        ),
        // Reply button row
        Padding(
          padding: const EdgeInsets.only(left: 42, top: 6),
          child: Row(
            children: [
              // Reply button
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
                const SizedBox(width: 12),
                // Delete button
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
              if (hasReplies) ...[
                const SizedBox(width: 12),
                // View/hide replies button
                TextButton(
                  onPressed: onToggleReplies,
                  style: TextButton.styleFrom(
                    foregroundColor: secondaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isExpanded
                        ? 'Hide replies (${replies.length})'
                        : 'View replies (${replies.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Replies section
        if (isExpanded && hasReplies) ...[
          const SizedBox(height: 8),
          ReplyThread(
            replies: replies,
            userDataCache: repliesUserDataCache ?? {},
            onDeleteReply: onDeleteReply,
            currentUserId: currentUserId,
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  void _confirmDelete(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        title: Text(
          'Delete message?',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will remove your message. This action cannot be undone.',
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
