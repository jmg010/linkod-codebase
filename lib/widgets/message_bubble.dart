import 'package:flutter/material.dart';
import 'optimized_image.dart';
import 'resident_profile_dialog.dart';

/// Avatar widget that displays a user's profile image with fallback to initials.
/// Shows a profile dialog when tapped.
class MessageAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double size;
  final String? purok;
  final String? phoneNumber;
  final bool isSeller;

  const MessageAvatar({
    super.key,
    this.avatarUrl,
    required this.name,
    this.size = 32,
    this.purok,
    this.phoneNumber,
    this.isSeller = false,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => ResidentProfileDialog(
            avatarUrl: avatarUrl,
            name: name,
            purok: purok,
            phoneNumber: phoneNumber,
            isSeller: isSeller,
          ),
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSeller ? const Color(0xFF20BF6B) : Colors.grey.shade300,
            width: isSeller ? 2 : 1,
          ),
        ),
        child: ClipOval(
          child: avatarUrl != null && avatarUrl!.isNotEmpty
              ? OptimizedNetworkImage(
                  imageUrl: avatarUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  cacheWidth: (size * 2).toInt(),
                  cacheHeight: (size * 2).toInt(),
                  errorWidget: _buildFallback(initials),
                )
              : _buildFallback(initials),
        ),
      ),
    );
  }

  Widget _buildFallback(String initials) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFF20BF6B),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Message bubble with avatar and sender name.
/// Used for both parent and reply messages with configurable styling.
class MessageBubble extends StatelessWidget {
  final String sender;
  final String message;
  final bool isSeller;
  final bool isReply;
  final String? avatarUrl;
  final String? purok;
  final String? phoneNumber;

  const MessageBubble({
    super.key,
    required this.sender,
    required this.message,
    required this.isSeller,
    this.isReply = false,
    this.avatarUrl,
    this.purok,
    this.phoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarSize = isReply ? 28.0 : 32.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        MessageAvatar(
          avatarUrl: avatarUrl,
          name: sender,
          size: avatarSize,
          purok: purok,
          phoneNumber: phoneNumber,
          isSeller: isSeller,
        ),
        const SizedBox(width: 10),
        // Message content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sender name
              Text(
                sender,
                style: TextStyle(
                  fontSize: isReply ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: isSeller
                      ? const Color(0xFF20BF6B)
                      : (isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade800),
                ),
              ),
              const SizedBox(height: 4),
              // Message bubble
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isReply ? 10 : 12,
                  vertical: isReply ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: isReply
                      ? (isDark
                          ? const Color(0xFF2C2C2C)
                          : Colors.grey.shade100)
                      : (isDark
                          ? const Color(0xFF2A2A2A)
                          : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(isReply ? 12 : 14),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: isReply ? 12 : 13,
                    color: isDark
                        ? Colors.grey.shade300
                        : Colors.grey.shade800,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
