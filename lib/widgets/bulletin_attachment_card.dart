import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reusable attachment card for PDFs and documents.
/// Shows document icon, name, and tap-to-open action.
class BulletinAttachmentCard extends StatelessWidget {
  final String? fileUrl;
  final String? fileName;
  final VoidCallback? onTap;

  const BulletinAttachmentCard({
    super.key,
    this.fileUrl,
    this.fileName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayName = fileName ?? 'Attached File';
    final hasUrl = fileUrl != null && fileUrl!.isNotEmpty;
    final isPdf = _isPdfFile(displayName, fileUrl);

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
            onTap: onTap ?? (hasUrl ? () => _openFile(context, fileUrl!) : null),
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
                  // File icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPdf
                          ? (isDark
                              ? Colors.red.shade900.withOpacity(0.3)
                              : Colors.red.shade50)
                          : (isDark
                              ? Colors.blue.shade900.withOpacity(0.3)
                              : Colors.blue.shade50),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.attach_file,
                      color: isPdf
                          ? (isDark ? Colors.red.shade300 : Colors.red.shade600)
                          : (isDark
                              ? Colors.blue.shade300
                              : Colors.blue.shade600),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // File info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.grey.shade200
                                : Colors.grey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasUrl ? 'Tap to view or download' : 'File unavailable',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action icon
                  Icon(
                    hasUrl ? Icons.open_in_new : Icons.lock_outline,
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

  bool _isPdfFile(String name, String? url) {
    final lowerName = name.toLowerCase();
    final lowerUrl = url?.toLowerCase() ?? '';
    return lowerName.endsWith('.pdf') ||
        lowerUrl.contains('.pdf') ||
        lowerUrl.contains('application/pdf');
  }

  Future<void> _openFile(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the file'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

/// Compact attachment button for inline display
class BulletinAttachmentChip extends StatelessWidget {
  final String? fileName;
  final VoidCallback? onTap;

  const BulletinAttachmentChip({
    super.key,
    this.fileName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayName = fileName ?? 'File attached';
    final isPdf = displayName.toLowerCase().endsWith('.pdf');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPdf
              ? (isDark
                  ? Colors.red.shade900.withOpacity(0.3)
                  : Colors.red.shade50)
              : (isDark
                  ? Colors.blue.shade900.withOpacity(0.3)
                  : Colors.blue.shade50),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPdf
                ? (isDark
                    ? Colors.red.shade700.withOpacity(0.5)
                    : Colors.red.shade200)
                : (isDark
                    ? Colors.blue.shade700.withOpacity(0.5)
                    : Colors.blue.shade200),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPdf ? Icons.picture_as_pdf : Icons.attach_file,
              size: 16,
              color: isPdf
                  ? (isDark ? Colors.red.shade300 : Colors.red.shade600)
                  : (isDark ? Colors.blue.shade300 : Colors.blue.shade600),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isPdf
                      ? (isDark ? Colors.red.shade300 : Colors.red.shade700)
                      : (isDark ? Colors.blue.shade300 : Colors.blue.shade700),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
