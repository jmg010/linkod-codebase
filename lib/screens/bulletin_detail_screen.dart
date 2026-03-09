import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/bulletin_model.dart';

class BulletinDetailScreen extends StatelessWidget {
  final BulletinModel bulletin;

  const BulletinDetailScreen({
    super.key,
    required this.bulletin,
  });

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = bulletin.category;
    final backgroundColor = isDark 
        ? const Color(0xFF1E1E1E) 
        : (category?.backgroundColor ?? Colors.white);
    final iconColor = category?.iconColor ?? Colors.grey;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: CustomScrollView(
        slivers: [
          // App bar with image
          SliverAppBar(
            expandedHeight: bulletin.imageUrl != null ? 240 : 0,
            pinned: true,
            backgroundColor: backgroundColor,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, 
                  color: isDark ? Colors.white : Colors.black87),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Bulletin Board',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            centerTitle: true,
            flexibleSpace: bulletin.imageUrl != null
                ? FlexibleSpaceBar(
                    background: Image.network(
                      bulletin.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: backgroundColor,
                      ),
                    ),
                  )
                : null,
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  if (category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            category.icon,
                            size: 16,
                            color: iconColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category.title.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: iconColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Title
                  Text(
                    bulletin.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Full description
                  Text(
                    bulletin.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // File attachment section
                  if (_hasFileAttachment()) ...[
                    const SizedBox(height: 20),
                    _buildFileAttachmentSection(context),
                    const SizedBox(height: 24),
                  ],

                  // Divider
                  Divider(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),

                  const SizedBox(height: 16),

                  // Metadata row
                  Row(
                    children: [
                      // Date
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(bulletin.date),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  if (bulletin.location != null) ...[
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
                            bulletin.location!,
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

                  const SizedBox(height: 24),

                  // Posted by
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance,
                          size: 24,
                          color: const Color(0xFF00A651),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Posted by',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              'Barangay Office',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Check if bulletin has a file attachment
  bool _hasFileAttachment() {
    final pdfUrl = bulletin.pdfUrl;
    final pdfName = bulletin.pdfName;
    return (pdfUrl != null && pdfUrl.isNotEmpty) ||
           (pdfName != null && pdfName.isNotEmpty);
  }

  /// Build file attachment section for detail screen
  Widget _buildFileAttachmentSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fileUrl = bulletin.pdfUrl;
    final fileName = bulletin.pdfName ?? 'Attached File';
    final isPdf = fileName.toLowerCase().endsWith('.pdf') ||
                  (fileUrl != null && fileUrl.toLowerCase().contains('.pdf'));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attached File',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              if (fileUrl != null && fileUrl.isNotEmpty) {
                final uri = Uri.parse(fileUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPdf 
                          ? (isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50)
                          : (isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.attach_file,
                      color: isPdf 
                          ? (isDark ? Colors.red.shade300 : Colors.red.shade600)
                          : (isDark ? Colors.blue.shade300 : Colors.blue.shade600),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to view or download',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.open_in_new,
                    size: 20,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
