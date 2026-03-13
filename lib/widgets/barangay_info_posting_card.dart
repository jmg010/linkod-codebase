import 'package:flutter/material.dart';
import '../models/bulletin_model.dart';
import 'bulletin_media_preview.dart';
import 'bulletin_metadata_row.dart';
import '../screens/bulletin_detail_screen.dart';

/// Card widget for displaying barangay information postings within categories.
/// Document/poster-focused layout: Image preview at top, title, date, description, CTA.
class BarangayInfoPostingCard extends StatelessWidget {
  final BulletinModel bulletin;
  final VoidCallback? onTap;

  const BarangayInfoPostingCard({
    super.key,
    required this.bulletin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMedia = bulletin.hasImages || bulletin.hasPdf;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1.5,
      shadowColor: Colors.black.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap ?? () => _navigateToDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media Preview Section (Image, PDF, or Document Placeholder)
              if (hasMedia) ...[
                BulletinMediaPreview(
                  bulletin: bulletin,
                  height: 180,
                  borderRadius: 12,
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Document-style placeholder when no media
                DocumentPlaceholder(
                  height: 160,
                  borderRadius: 12,
                ),
                const SizedBox(height: 16),
              ],

              // Title
              Text(
                bulletin.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 10),

              // Date with calendar icon
              BulletinMetadataRow(
                date: bulletin.date,
                iconColor: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                textColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),

              const SizedBox(height: 12),

              // Short description preview
              Text(
                bulletin.description,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 16),

              // CTA - View Details
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF20BF6B),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: const Color(0xFF20BF6B),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BulletinDetailScreen(bulletin: bulletin),
      ),
    );
  }
}
