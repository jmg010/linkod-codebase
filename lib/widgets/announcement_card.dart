import 'package:flutter/material.dart';
import '../screens/announcement_detail_screen.dart';
import 'optimized_image.dart';

class AnnouncementCard extends StatelessWidget {
  final String title;
  final String description;
  final String postedBy;
  final String? postedByPosition;
  final DateTime date;
  final String? category;
  final int? unreadCount;
  final bool isRead;
  final VoidCallback? onMarkAsReadPressed;
  final bool showTag;
  final String? announcementId;
  /// Optional image URLs to show below title and content (Facebook-style).
  final List<String>? imageUrls;

  const AnnouncementCard({
    super.key,
    required this.title,
    required this.description,
    required this.postedBy,
    this.postedByPosition,
    required this.date,
    this.category,
    this.unreadCount,
    this.isRead = false,
    this.onMarkAsReadPressed,
    this.showTag = false,
    this.announcementId,
    this.imageUrls,
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
                  postedByPosition != null && postedByPosition!.isNotEmpty
                      ? 'From: $postedBy ($postedByPosition)'
                      : 'From: $postedBy',
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
            if (imageUrls != null && imageUrls!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _AnnouncementCardMedia(imageUrls: imageUrls!),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.visibility_outlined, size: 16, color: const Color(0xFF6E6E6E)),
                const SizedBox(width: 6),
                Text(
                  '${unreadCount ?? 0} views',
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
                onPressed: () {
                  if (onMarkAsReadPressed != null) {
                    onMarkAsReadPressed!();
                  }
                  if (announcementId != null && announcementId!.isNotEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AnnouncementDetailScreen(announcementId: announcementId!),
                      ),
                    );
                  }
                },
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

/// Facebook-style media block: one image or grid for multiple; tap opens full screen.
class _AnnouncementCardMedia extends StatelessWidget {
  const _AnnouncementCardMedia({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: OptimizedNetworkImage(
            imageUrl: imageUrls.first,
            fit: BoxFit.cover,
            cacheWidth: 800,
            cacheHeight: 450,
            borderRadius: BorderRadius.circular(12),
            errorWidget: Container(
              color: Colors.grey.shade300,
              child: const Icon(Icons.image_not_supported),
            ),
            onTap: () => openFullScreenImage(context, imageUrls.first),
          ),
        ),
      );
    }

    final displayed = imageUrls.take(6).toList();
    return SizedBox(
      height: 200,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
          childAspectRatio: 1,
        ),
        itemCount: displayed.length,
        itemBuilder: (context, index) {
          final url = displayed[index];
          final isLast = index == displayed.length - 1 && imageUrls.length > displayed.length;
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: OptimizedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  cacheHeight: 400,
                  errorWidget: Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image_not_supported),
                  ),
                  onTap: () => openFullScreenImages(context, imageUrls, initialIndex: index),
                ),
              ),
              if (isLast)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black38,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+${imageUrls.length - displayed.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
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
        isRead ? 'Viewed' : 'View',
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

