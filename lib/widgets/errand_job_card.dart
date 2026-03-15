import 'package:flutter/material.dart';
import 'optimized_image.dart';

enum ErrandJobStatus { open, ongoing, completed }

class ErrandJobCard extends StatelessWidget {
  final String title;
  final String description;
  final String postedBy;
  final DateTime date;
  final ErrandJobStatus? status;
  final String? statusLabel;
  final String? volunteerName;
  final VoidCallback? onViewPressed;
  final VoidCallback? onVolunteerPressed;
  final bool showTag;
  final String viewButtonLabel;
  final IconData viewButtonIcon;

  /// Optional image URLs for the errand (owner-attached). Shown like product card.
  final List<String> imageUrls;

  const ErrandJobCard({
    super.key,
    required this.title,
    required this.description,
    required this.postedBy,
    required this.date,
    this.status,
    this.statusLabel,
    this.volunteerName,
    this.onViewPressed,
    this.onVolunteerPressed,
    this.showTag = false,
    this.viewButtonLabel = 'View',
    this.viewButtonIcon = Icons.visibility_outlined,
    this.imageUrls = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Request tag and date row (if showTag is true)
            if (showTag) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade400,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Job/Errand',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      _formatDate(date),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark
                                ? Colors.grey.shade400
                                : const Color(0xFF6E6E6E),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            // Image section (when imageUrls provided)
            if (imageUrls.isNotEmpty) ...[
              _ErrandCardImage(imageUrls: imageUrls),
              const SizedBox(height: 12),
            ],
            // Title and status tag in same row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.25,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(width: 8),
                  _buildStatusPill(status!, statusLabel),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Posted by and date in same row (only show date if showTag is false)
            if (!showTag)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Color(0xFF6E6E6E),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Posted by: $postedBy',
                            style: TextStyle(
                              fontSize: 12.5,
                              color:
                                  isDark
                                      ? Colors.grey.shade400
                                      : const Color(0xFF6E6E6E),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _formatDate(date),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark
                                ? Colors.grey.shade400
                                : const Color(0xFF6E6E6E),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 14,
                    color: Color(0xFF6E6E6E),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Posted by: $postedBy',
                      style: TextStyle(
                        fontSize: 12.5,
                        color:
                            isDark
                                ? Colors.grey.shade400
                                : const Color(0xFF6E6E6E),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            // Description
            Text(
              description,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.grey.shade300 : const Color(0xFF4C4C4C),
                height: 1.4,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 14),
            // Action button: View / Edit (or Volunteer when open and no assignee)
            if (volunteerName != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onViewPressed,
                  icon: Icon(
                    viewButtonIcon,
                    size: 16,
                    color: isDark ? Colors.white : const Color(0xFF4C4C4C),
                  ),
                  label: Text(
                    viewButtonLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF4C4C4C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    side: BorderSide(
                      color:
                          isDark
                              ? Colors.grey.shade700
                              : const Color(0xFFD0D0D0),
                    ),
                    backgroundColor:
                        isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  ),
                ),
              )
            else if (onViewPressed != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onViewPressed,
                  icon: Icon(
                    viewButtonIcon,
                    size: 16,
                    color: isDark ? Colors.white : const Color(0xFF4C4C4C),
                  ),
                  label: Text(
                    viewButtonLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF4C4C4C),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    side: BorderSide(
                      color:
                          isDark
                              ? Colors.grey.shade700
                              : const Color(0xFFD0D0D0),
                    ),
                    backgroundColor:
                        isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(ErrandJobStatus status, String? label) {
    late Color bgColor;
    late Color textColor;
    final raw = (label ?? status.name);
    final displayText =
        raw.isEmpty ? raw : '${raw[0].toUpperCase()}${raw.substring(1)}';

    switch (status) {
      case ErrandJobStatus.open:
        bgColor = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1976D2);
        break;
      case ErrandJobStatus.ongoing:
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFF57C00);
        break;
      case ErrandJobStatus.completed:
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF388E3C);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = _monthName(date.month);
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$month ${date.day} at $hour:$minute $period';
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

/// Image area for errand card (single image or PageView; tap to fullscreen).
class _ErrandCardImage extends StatelessWidget {
  const _ErrandCardImage({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            width: double.infinity,
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            child: Icon(
              Icons.image_outlined,
              size: 40,
              color: Colors.grey.shade400,
            ),
          ),
        ),
      );
    }
    if (imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: OptimizedNetworkImage(
            imageUrl: imageUrls.first,
            fit: BoxFit.cover,
            cacheWidth: 800,
            cacheHeight: 450,
            borderRadius: BorderRadius.circular(14),
            errorWidget: _errorPlaceholder(),
            onTap:
                () => openFullScreenImages(context, imageUrls, initialIndex: 0),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: PageView.builder(
          itemCount: imageUrls.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap:
                  () => openFullScreenImages(
                    context,
                    imageUrls,
                    initialIndex: index,
                  ),
              child: OptimizedNetworkImage(
                imageUrl: imageUrls[index],
                fit: BoxFit.cover,
                cacheWidth: 800,
                cacheHeight: 450,
                borderRadius: BorderRadius.circular(14),
                errorWidget: _errorPlaceholder(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 40,
        color: Colors.grey.shade500,
      ),
    );
  }
}
