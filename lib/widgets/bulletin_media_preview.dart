import 'package:flutter/material.dart';
import '../models/bulletin_model.dart';
import 'optimized_image.dart';
import 'fullscreen_image_viewer.dart';

/// Reusable media preview widget for bulletin cards.
/// Shows image preview, document placeholder, or nothing based on content.
class BulletinMediaPreview extends StatelessWidget {
  final BulletinModel bulletin;
  final double height;
  final double borderRadius;
  final VoidCallback? onTap;

  const BulletinMediaPreview({
    super.key,
    required this.bulletin,
    this.height = 180,
    this.borderRadius = 12,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final allImageUrls = bulletin.allImageUrls;
    final hasPdf = bulletin.hasPdf;

    // Priority: images first, then PDF, then placeholder
    if (allImageUrls.isNotEmpty) {
      return _buildImagePreview(context, allImageUrls);
    } else if (hasPdf) {
      return _buildPdfPreview(context);
    }

    return const SizedBox.shrink();
  }

  Widget _buildImagePreview(BuildContext context, List<String> imageUrls) {
    final bool isMultiple = imageUrls.length > 1;

    if (isMultiple) {
      return _buildMultiImagePreview(context, imageUrls);
    }

    // Single image
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: OptimizedNetworkImage(
          imageUrl: imageUrls.first,
          fit: BoxFit.cover,
          cacheWidth: 800,
          cacheHeight: 450,
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap ?? () => openFullscreenGallery(context, imageUrls),
          errorWidget: _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildMultiImagePreview(BuildContext context, List<String> imageUrls) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 8,
                  right: index == imageUrls.length - 1 ? 0 : 8,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: SizedBox(
                    width: 280,
                    child: OptimizedNetworkImage(
                      imageUrl: imageUrls[index],
                      fit: BoxFit.cover,
                      cacheWidth: 560,
                      cacheHeight: 360,
                      borderRadius: BorderRadius.circular(borderRadius),
                      onTap: onTap ??
                          () => openFullscreenGallery(
                                context,
                                imageUrls,
                                initialIndex: index,
                              ),
                      errorWidget: _buildPlaceholder(),
                    ),
                  ),
                ),
              );
            },
          ),
          // Image count badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.photo_library,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfPreview(BuildContext context) {
    final pdfName = bulletin.pdfName ?? 'Document';
    final isPdf = pdfName.toLowerCase().endsWith('.pdf');

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPdf
                  ? Colors.red.shade50
                  : Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
              size: 40,
              color: isPdf
                  ? Colors.red.shade600
                  : Colors.blue.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              pdfName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to view',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey.shade400,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              'No preview available',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Document-style placeholder when no media exists
class DocumentPlaceholder extends StatelessWidget {
  final double height;
  final double borderRadius;

  const DocumentPlaceholder({
    super.key,
    this.height = 180,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF20BF6B).withOpacity(0.1),
            const Color(0xFF20BF6B).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: const Color(0xFF20BF6B).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 48,
            color: const Color(0xFF20BF6B).withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Public Notice',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF20BF6B).withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
