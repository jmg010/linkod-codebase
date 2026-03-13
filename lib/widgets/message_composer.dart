import 'package:flutter/material.dart';
import 'message_bubble.dart';

/// Improved message composer with user avatar, text field, and icon-based send button.
/// Layout: [User Avatar] [TextField] [Send Icon]
class MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final bool isSending;
  final String? currentUserAvatarUrl;
  final String currentUserName;

  const MessageComposer({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSend,
    this.isSending = false,
    this.currentUserAvatarUrl,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // User avatar
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: MessageAvatar(
            avatarUrl: currentUserAvatarUrl,
            name: currentUserName,
            size: 32,
          ),
        ),
        const SizedBox(width: 10),
        // Text field
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Write a message...',
                hintStyle: TextStyle(
                  color: isDark
                      ? Colors.grey.shade500
                      : const Color(0xFF9E9E9E),
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Send icon button
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isSending
                ? Colors.grey.shade400
                : const Color(0xFF20BF6B),
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            onPressed: isSending ? null : onSend,
            icon: isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
          ),
        ),
      ],
    );
  }
}

/// Inline reply composer shown below a message when replying.
/// Includes a "Replying to [name]" indicator with cancel button.
class InlineReplyComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String replyingToName;
  final VoidCallback onCancel;
  final VoidCallback onReply;
  final bool isSending;
  final String? currentUserAvatarUrl;
  final String currentUserName;

  const InlineReplyComposer({
    super.key,
    required this.controller,
    this.focusNode,
    required this.replyingToName,
    required this.onCancel,
    required this.onReply,
    this.isSending = false,
    this.currentUserAvatarUrl,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Replying to indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF20BF6B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.reply,
                      size: 14,
                      color: const Color(0xFF20BF6B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Replying to $replyingToName',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF20BF6B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Cancel button
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey.shade700
                        : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: isDark ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Composer row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // User avatar
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: MessageAvatar(
                  avatarUrl: currentUserAvatarUrl,
                  name: currentUserName,
                  size: 28,
                ),
              ),
              const SizedBox(width: 8),
              // Text field
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    minLines: 1,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Write a reply...',
                      hintStyle: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : const Color(0xFF9E9E9E),
                        fontSize: 13,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send button
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSending
                      ? Colors.grey.shade400
                      : const Color(0xFF20BF6B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: isSending ? null : onReply,
                  padding: EdgeInsets.zero,
                  icon: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 18,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
