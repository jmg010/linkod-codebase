import 'package:flutter/material.dart';

/// Reusable metadata row showing date and optional location.
/// Used in both card previews and detail screens.
class BulletinMetadataRow extends StatelessWidget {
  final DateTime date;
  final String? location;
  final bool showFullDate;
  final bool iconOnly;
  final Color? iconColor;
  final Color? textColor;
  final double iconSize;
  final double fontSize;

  const BulletinMetadataRow({
    super.key,
    required this.date,
    this.location,
    this.showFullDate = false,
    this.iconOnly = false,
    this.iconColor,
    this.textColor,
    this.iconSize = 14,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor = iconColor ??
        (isDark ? Colors.grey.shade500 : Colors.grey.shade600);
    final effectiveTextColor = textColor ??
        (isDark ? Colors.grey.shade400 : Colors.grey.shade700);

    return Row(
      children: [
        // Date
        Icon(
          Icons.calendar_today_outlined,
          size: iconSize,
          color: effectiveIconColor,
        ),
        SizedBox(width: iconOnly ? 4 : 6),
        if (!iconOnly)
          Text(
            _formatDate(date),
            style: TextStyle(
              fontSize: fontSize,
              color: effectiveTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),

        // Location (if provided)
        if (location != null && location!.isNotEmpty) ...[
          if (!iconOnly) const SizedBox(width: 12),
          Icon(
            Icons.location_on_outlined,
            size: iconSize,
            color: effectiveIconColor,
          ),
          SizedBox(width: iconOnly ? 4 : 6),
          if (!iconOnly)
            Expanded(
              child: Text(
                location!,
                style: TextStyle(
                  fontSize: fontSize,
                  color: effectiveTextColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = showFullDate
        ? [
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
          ]
        : [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
          ];

    if (showFullDate) {
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// Extended metadata row for detail screens with larger text and icons
class BulletinMetadataRowExtended extends StatelessWidget {
  final DateTime date;
  final String? location;

  const BulletinMetadataRowExtended({
    super.key,
    required this.date,
    this.location,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date
        Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              _formatFullDate(date),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        // Location
        if (location != null && location!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 18,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  location!,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
