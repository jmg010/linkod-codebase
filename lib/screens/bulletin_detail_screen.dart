import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/bulletin_model.dart';
import '../widgets/optimized_image.dart';
import '../widgets/bulletin_metadata_row.dart';
import '../widgets/bulletin_attachment_card.dart';
import '../widgets/fullscreen_image_viewer.dart';

class BulletinDetailScreen extends StatelessWidget {
  final BulletinModel bulletin;

  const BulletinDetailScreen({super.key, required this.bulletin});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = bulletin.category;
    final allImageUrls = bulletin.allImageUrls;
    final hasImages = allImageUrls.isNotEmpty;
    final hasPdf = bulletin.hasPdf;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF4F4F4),
      body: CustomScrollView(
        slivers: [
          // App bar with back button (overlaid on image if present)
          _buildAppBar(context, isDark, hasImages),

          // Media Header (Large image or gallery)
          if (hasImages)
            SliverToBoxAdapter(
              child: _buildMediaHeader(context, allImageUrls, isDark),
            ),

          // Content Section
          SliverToBoxAdapter(
            child: _buildContentSection(context, isDark, category, hasImages),
          ),

          // Attachments Section (if PDF exists)
          if (hasPdf)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: BulletinAttachmentCard(
                  fileUrl: bulletin.pdfUrl,
                  fileName: bulletin.pdfName,
                ),
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark, bool hasImages) {
    return SliverAppBar(
      expandedHeight: 0,
      pinned: true,
      elevation: hasImages ? 0 : 1,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: isDark ? Colors.white : Colors.black87,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'View Notice',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildMediaHeader(
    BuildContext context,
    List<String> imageUrls,
    bool isDark,
  ) {
    final isSingleImage = imageUrls.length == 1;

    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Column(
        children: [
          // Single Image
          if (isSingleImage)
            GestureDetector(
              onTap: () => openFullscreenGallery(context, imageUrls),
              child: SizedBox(
                width: double.infinity,
                height: 240,
                child: OptimizedNetworkImage(
                  imageUrl: imageUrls.first,
                  fit: BoxFit.cover,
                  cacheWidth: 800,
                  cacheHeight: 480,
                  errorWidget: Container(
                    color:
                        isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color:
                          isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      size: 48,
                    ),
                  ),
                ),
              ),
            )
          else
            // Multiple Images - Horizontal Gallery
            Container(
              height: 260,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: imageUrls.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == imageUrls.length - 1 ? 0 : 12,
                    ),
                    child: GestureDetector(
                      onTap:
                          () => openFullscreenGallery(
                            context,
                            imageUrls,
                            initialIndex: index,
                          ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 320,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              OptimizedNetworkImage(
                                imageUrl: imageUrls[index],
                                fit: BoxFit.cover,
                                cacheWidth: 640,
                                cacheHeight: 520,
                                borderRadius: BorderRadius.circular(12),
                                errorWidget: Container(
                                  color:
                                      isDark
                                          ? const Color(0xFF2A2A2A)
                                          : Colors.grey.shade200,
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color:
                                        isDark
                                            ? Colors.grey.shade600
                                            : Colors.grey.shade400,
                                    size: 40,
                                  ),
                                ),
                              ),
                              // Image counter overlay
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '${index + 1}/${imageUrls.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Tap to expand hint
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.zoom_in,
                  size: 16,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  isSingleImage
                      ? 'Tap image to expand'
                      : 'Tap image to view fullscreen',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),
        ],
      ),
    );
  }

  Widget _buildContentSection(
    BuildContext context,
    bool isDark,
    dynamic category,
    bool hasImages,
  ) {
    return Container(
      color: isDark ? const Color(0xFF121212) : const Color(0xFFF4F4F4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge
                if (category != null) _buildCategoryBadge(category, isDark),

                if (category != null) const SizedBox(height: 16),

                // Title
                Text(
                  bulletin.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.3,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 16),

                // Metadata (Date and Location)
                BulletinMetadataRowExtended(
                  date: bulletin.date,
                  location: bulletin.location,
                ),

                const SizedBox(height: 20),

                // Divider
                Divider(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  height: 1,
                ),

                const SizedBox(height: 20),

                // Description with improved readability
                _buildDescription(bulletin.description, isDark),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(dynamic category, bool isDark) {
    final iconColor = category.iconColor ?? const Color(0xFF20BF6B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            category.title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: iconColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(String description, bool isDark) {
    // Split description by double newlines to create paragraphs
    final paragraphs = description.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Text(
          'Details',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),

        // Paragraphs
        for (int i = 0; i < paragraphs.length; i++) ...[
          Text(
            paragraphs[i].trim(),
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
              height: 1.7,
            ),
          ),
          if (i < paragraphs.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }
}
