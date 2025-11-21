import 'package:flutter/material.dart';

class AnnouncementCard extends StatelessWidget {
  final String title;
  final String description;
  final String postedBy;
  final DateTime date;
  final String? category;
  final int? unreadCount;
  final bool isRead;
  final VoidCallback? onMarkAsReadPressed;

  const AnnouncementCard({
    super.key,
    required this.title,
    required this.description,
    required this.postedBy,
    required this.date,
    this.category,
    this.unreadCount,
    this.isRead = false,
    this.onMarkAsReadPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: "From:" on left, Date on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "From: Barangay Official" on left
                Text(
                  'From: $postedBy',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                // Date on right
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            
            // Category tag (below "From")
            if (category != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getCategoryColor(category!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  category!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            
            // Description
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            
            // Divider or spacing
            const SizedBox(height: 4),
            
            // Bottom row: Eye icon + count (left) and Mark as Read button (right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Eye icon + unread count (left side)
                Row(
                  children: [
                    Icon(Icons.visibility, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${unreadCount ?? 0}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                // Mark as Read / Read button (white background, gray border, rounded pill)
                OutlinedButton.icon(
                  onPressed: onMarkAsReadPressed ?? () {},
                  icon: Icon(
                    isRead ? Icons.check : Icons.visibility,
                    size: 16,
                    color: isRead ? const Color(0xFF20BF6B) : Colors.grey.shade800,
                  ),
                  label: Text(isRead ? 'Read' : 'Mark as Read'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: isRead ? const Color(0xFF20BF6B) : Colors.grey.shade800,
                    side: BorderSide(
                      color: isRead ? const Color(0xFF20BF6B) : Colors.grey.shade300,
                      width: 1,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

