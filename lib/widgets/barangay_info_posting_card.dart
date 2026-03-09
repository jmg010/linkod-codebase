import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/bulletin_model.dart';
import 'optimized_image.dart';
import '../screens/bulletin_detail_screen.dart';

/// Card widget for displaying barangay information postings within categories.
/// Layout: Title at top, date, center image/PDF, description below.
class BarangayInfoPostingCard extends StatelessWidget {
  final BulletinModel bulletin;
  /// Optional PDF/document URL. If provided and imageUrl is null, shows PDF preview.
  final String? pdfUrl;
  /// Optional PDF/document name for display.
  final String? pdfName;

  const BarangayInfoPostingCard({
    super.key,
    required this.bulletin,
    this.pdfUrl,
    this.pdfName,
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
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BulletinDetailScreen(bulletin: bulletin),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title at top
              Text(
                bulletin.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              
              // Date
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(bulletin.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Center: Image or PDF/Document preview
              if (bulletin.imageUrl != null || pdfUrl != null) ...[
                _buildMediaContent(context),
                const SizedBox(height: 12),
              ],
              
              // Description/Info below
              Text(
                bulletin.description,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaContent(BuildContext context) {
    final allImageUrls = bulletin.allImageUrls;
    final hasPdf = pdfUrl != null && pdfUrl!.isNotEmpty;
    
    // Priority: images first, then PDF
    if (allImageUrls.isNotEmpty) {
      if (allImageUrls.length == 1) {
        // Single image
        return _buildSingleImage(context, allImageUrls[0]);
      } else {
        // Multiple images - horizontal scroll
        return _buildMultiImageScroll(context, allImageUrls);
      }
    } else if (hasPdf) {
      return _buildPdfPreview(context);
    }
    return const SizedBox.shrink();
  }

  Widget _buildSingleImage(BuildContext context, String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: OptimizedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          cacheWidth: 800,
          cacheHeight: 450,
          borderRadius: BorderRadius.circular(12),
          onTap: () => openFullScreenImage(context, imageUrl),
          errorWidget: Container(
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey.shade400,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiImageScroll(BuildContext context, List<String> imageUrls) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 8,
              right: index == imageUrls.length - 1 ? 0 : 8,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 280,
                child: OptimizedNetworkImage(
                  imageUrl: imageUrls[index],
                  fit: BoxFit.cover,
                  cacheWidth: 560,
                  cacheHeight: 360,
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => openFullScreenImage(context, imageUrls[index]),
                  errorWidget: Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey.shade400,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPdfPreview(BuildContext context) {
    return InkWell(
      onTap: () async {
        if (pdfUrl != null) {
          final uri = Uri.parse(pdfUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf,
              size: 48,
              color: Colors.red.shade600,
            ),
            const SizedBox(height: 8),
            if (pdfName != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  pdfName!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              'Tap to view or download',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void openFullScreenImage(BuildContext context, String imageUrl) {
    // TODO: Implement full screen image viewer
  }
}
