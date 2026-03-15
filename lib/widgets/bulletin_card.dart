import 'package:flutter/material.dart';
import '../models/bulletin_model.dart';
import 'bulletin_metadata_row.dart';
import '../screens/bulletin_detail_screen.dart';

/// Card widget for displaying bulletin items.
/// Compact version with consistent styling for grid/list displays.
class BulletinCard extends StatelessWidget {
  final BulletinModel bulletin;

  const BulletinCard({
    super.key,
    required this.bulletin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = bulletin.category;
    final allImageUrls = bulletin.allImageUrls;
    final hasImages = allImageUrls.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BulletinDetailScreen(bulletin: bulletin),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content padding
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category badge
                    if (category != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: category.iconColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              category.icon,
                              size: 12,
                              color: category.iconColor,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                category.title.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: category.iconColor,
                                  letterSpacing: 0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Title
                    Text(
                      bulletin.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Description preview
                    Text(
                      bulletin.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 12),

                    // Footer: Date and Location
                    BulletinMetadataRow(
                      date: bulletin.date,
                      location: bulletin.location,
                      iconSize: 12,
                      fontSize: 11,
                      iconColor: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                      textColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ],
                ),
              ),

              // Image banner (if exists) - Now below content
              if (hasImages)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      allImageUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade300,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
