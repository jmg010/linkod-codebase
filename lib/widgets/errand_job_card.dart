import 'package:flutter/material.dart';

enum ErrandJobStatus {
  open,
  ongoing,
  completed,
}

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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade400,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Request',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6E6E6E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            // Title and status tag in same row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      height: 1.25,
                    ),
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
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Color(0xFF6E6E6E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Posted by: $postedBy',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6E6E6E),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatDate(date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6E6E6E),
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
                  Text(
                    'Posted by: $postedBy',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6E6E6E),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            // Description
            Text(
              description,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF4C4C4C),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            // Action button or volunteer status
            if (volunteerName != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: Color(0xFF20BF6B),
                  ),
                  label: Text(
                    'Volunteered by: $volunteerName',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF20BF6B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    side: const BorderSide(color: Color(0xFFD0D0D0)),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF20BF6B),
                    disabledBackgroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xFF20BF6B),
                  ),
                ),
              )
            else if (onViewPressed != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onViewPressed,
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: Color(0xFF4C4C4C),
                  ),
                  label: const Text(
                    'View',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4C4C4C),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    side: const BorderSide(color: Color(0xFFD0D0D0)),
                    backgroundColor: Colors.white,
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
      'December'
    ];
    return months[month - 1];
  }
}

