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
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Tag and Date/Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Solid purple Request tag with white text
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Request',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Date and Status column (right-aligned)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 4),
                      _buildStatusPill(status!, statusLabel),
                    ],
                  ],
                ),
              ],
            ),
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
            
            // Posted by
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  postedBy,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
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
            const SizedBox(height: 16),
            
            // Volunteer button (centered, full width if available)
            if (volunteerName == null && onVolunteerPressed != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onVolunteerPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF20BF6B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Volunteer'),
                ),
              )
            else if (volunteerName != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF20BF6B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: const Color(0xFF20BF6B)),
                    const SizedBox(width: 6),
                    Text(
                      'Volunteered by: $volunteerName',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF20BF6B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            
            // View button (centered)
            if (onViewPressed != null) ...[
              if (volunteerName != null || onVolunteerPressed == null) const SizedBox(height: 12),
              Center(
                child: OutlinedButton.icon(
                  onPressed: onViewPressed,
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade800,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(ErrandJobStatus status, String? label) {
    Color bgColor;
    Color textColor;
    String text = label ?? status.name;

    switch (status) {
      case ErrandJobStatus.open:
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case ErrandJobStatus.ongoing:
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case ErrandJobStatus.completed:
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

