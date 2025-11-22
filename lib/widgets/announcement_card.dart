import 'package:flutter/material.dart';

class AnnouncementCard extends StatelessWidget {
  final String title;
  final String description;
  final String postedBy;
  final DateTime date;
  final String? category;
  final int? unreadCount;
  final int? viewCount;
  final bool isRead;
  final VoidCallback? onMarkAsReadPressed;
  final bool showTag;

  const AnnouncementCard({
    super.key,
    required this.title,
    required this.description,
    required this.postedBy,
    required this.date,
    this.category,
    this.unreadCount,
    this.viewCount,
    this.isRead = false,
    this.onMarkAsReadPressed,
    this.showTag = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1.5,
      shadowColor: Colors.black.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tag row (if showTag is true)
            if (showTag) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Announcement',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'From: $postedBy',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF6E6E6E),
                  ),
                ),
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF6E6E6E),
                  ),
                ),
              ],
            ),
            if (category != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _getCategoryColor(category!),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  category!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF6A6A6A),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.visibility_outlined, size: 16, color: const Color(0xFF6E6E6E)),
                const SizedBox(width: 6),
                Text(
                  '${_getViewCount()} views',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6E6E6E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _ReadButton(
                isRead: isRead,
                onPressed: onMarkAsReadPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'livelihood':
        return Colors.amber.shade600;
      case 'health':
        return Colors.green.shade600;
      case 'youth activity':
        return Colors.blue.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  int _getViewCount() {
    // Use viewCount if available, otherwise fall back to unreadCount
    return viewCount ?? unreadCount ?? 0;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

class _ReadButton extends StatelessWidget {
  const _ReadButton({
    required this.isRead,
    this.onPressed,
  });

  final bool isRead;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color borderColor =
        isRead ? const Color(0xFF4CAF50) : const Color(0xFFDADADA);
    final Color textColor =
        isRead ? const Color(0xFF4CAF50) : const Color(0xFF5F5F5F);
    final IconData icon = isRead ? Icons.check : Icons.visibility_outlined;

    return OutlinedButton.icon(
      onPressed: onPressed ?? () {},
      icon: Icon(icon, size: 18, color: textColor),
      label: Text(
        isRead ? 'Read' : 'Mark as read',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: BorderSide(color: borderColor, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
      ),
    );
  }
}

