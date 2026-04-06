import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/announcement_detail_screen.dart';
import '../services/announcements_service.dart';
import 'optimized_image.dart';

class AnnouncementCard extends StatelessWidget {
  final String title;
  final String description;
  final String postedBy;
  final String? postedByPosition;
  final DateTime date;
  final String? category;
  final int? unreadCount;
  final bool isRead;
  final VoidCallback? onMarkAsReadPressed;
  final bool showTag;
  final String? announcementId;

  /// Optional image URLs to show below title and content (Facebook-style).
  final List<String>? imageUrls;

  const AnnouncementCard({
    super.key,
    required this.title,
    required this.description,
    required this.postedBy,
    this.postedByPosition,
    required this.date,
    this.category,
    this.unreadCount,
    this.isRead = false,
    this.onMarkAsReadPressed,
    this.showTag = false,
    this.announcementId,
    this.imageUrls,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1.5,
      shadowColor: Colors.black.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tag row (if showTag is true)
            if (showTag) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,

                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Announcement',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      Text(
                        _formatDate(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF6E6E6E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatDate(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF6E6E6E),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),

            Row(
              children: [
                Text(
                  postedByPosition != null && postedByPosition!.isNotEmpty
                      ? 'From: $postedBy ($postedByPosition)'
                      : 'From: $postedBy',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark ? Colors.grey.shade400 : const Color(0xFF6E6E6E),
                  ),
                ),
              ],
            ),

            if (category != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _getCategoryColor(category!),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  category!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.grey.shade300 : const Color(0xFF6A6A6A),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (imageUrls != null && imageUrls!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _AnnouncementCardMedia(imageUrls: imageUrls!),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: const Color(0xFF6E6E6E),
                ),
                const SizedBox(width: 6),
                if (announcementId != null && announcementId!.isNotEmpty)
                  InkWell(
                    onTap: () => _showViewersSheet(context),
                    child: Text(
                      '${unreadCount ?? 0} viewers',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.black87,
                      ),
                    ),
                  )
                else
                  Text(
                    '${unreadCount ?? 0} viewers',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _ReadButton(
                isRead: isRead,
                onPressed: () {
                  if (onMarkAsReadPressed != null) {
                    onMarkAsReadPressed!();
                  }
                  if (announcementId != null && announcementId!.isNotEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => AnnouncementDetailScreen(
                              announcementId: announcementId!,
                            ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'livelihood':
        return Colors.amber.shade600;
      case 'health':
        return Colors.green.shade600;
      case 'youth activity':
        return Colors.blue.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  void _showViewersSheet(BuildContext context) {
    if (announcementId == null || announcementId!.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _AnnouncementViewersSheet(
            announcementId: announcementId!,
            totalCount: unreadCount ?? 0,
          ),
    );
  }
}

class _AnnouncementViewersSheet extends StatefulWidget {
  const _AnnouncementViewersSheet({
    required this.announcementId,
    required this.totalCount,
  });

  final String announcementId;
  final int totalCount;

  @override
  State<_AnnouncementViewersSheet> createState() =>
      _AnnouncementViewersSheetState();
}

class _AnnouncementViewersSheetState extends State<_AnnouncementViewersSheet> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<AnnouncementViewer> _viewers = <AnnouncementViewer>[];

  QueryDocumentSnapshot<Map<String, dynamic>>? _lastVisible;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final page = await AnnouncementsService.getAnnouncementViewersPage(
        announcementId: widget.announcementId,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _viewers
          ..clear()
          ..addAll(page.viewers);
        _lastVisible = page.lastVisible;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to load viewers right now.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _lastVisible == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final page = await AnnouncementsService.getAnnouncementViewersPage(
        announcementId: widget.announcementId,
        limit: _pageSize,
        startAfter: _lastVisible,
      );
      if (!mounted) return;

      setState(() {
        _viewers.addAll(page.viewers);
        _lastVisible = page.lastVisible;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll < 320) {
      _loadMore();
    }
  }

  String _formatViewedAt(DateTime? viewedAt) {
    if (viewedAt == null) return 'Viewed recently';

    final now = DateTime.now();
    final diff = now.difference(viewedAt);
    if (diff.inMinutes < 1) return 'Viewed just now';
    if (diff.inMinutes < 60) return 'Viewed ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Viewed ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Viewed ${diff.inDays}d ago';

    final day = viewedAt.day.toString().padLeft(2, '0');
    final month = viewedAt.month.toString().padLeft(2, '0');
    final year = viewedAt.year.toString();
    return 'Viewed $day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final muted = isDark ? Colors.grey.shade400 : const Color(0xFF6E6E6E);
    final accent = const Color(0xFF20BF6B);

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.15),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.visibility_outlined,
                      color: Color(0xFF20BF6B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Announcement Viewers',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          '${widget.totalCount} total views',
                          style: TextStyle(fontSize: 12.5, color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.grey.shade300 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? Colors.grey.shade800 : const Color(0xFFEAEAEA),
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF20BF6B),
                        ),
                      )
                      : _error != null
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 40,
                                color: isDark ? Colors.red.shade300 : Colors.red,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: muted),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton(
                                onPressed: _loadInitial,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                      : _viewers.isEmpty
                      ? Center(
                        child: Text(
                          'No viewers yet',
                          style: TextStyle(color: muted),
                        ),
                      )
                      : ListView.builder(
                        controller: _scrollController,
                        itemCount: _viewers.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _viewers.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF20BF6B),
                                  ),
                                ),
                              ),
                            );
                          }

                          final viewer = _viewers[index];
                          final initials =
                              viewer.displayName.isNotEmpty
                                  ? viewer.displayName[0].toUpperCase()
                                  : 'R';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 2,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      isDark
                                          ? Colors.grey.shade700
                                          : const Color(0xFFDCE8DF),
                                  width: 1,
                                ),
                              ),
                              child: ClipOval(
                                child:
                                    viewer.avatarUrl != null &&
                                            viewer.avatarUrl!.isNotEmpty
                                        ? OptimizedNetworkImage(
                                          imageUrl: viewer.avatarUrl!,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                          cacheWidth: 88,
                                          cacheHeight: 88,
                                          errorWidget: _ViewerFallbackAvatar(
                                            initials: initials,
                                            isDark: isDark,
                                          ),
                                        )
                                        : _ViewerFallbackAvatar(
                                          initials: initials,
                                          isDark: isDark,
                                        ),
                              ),
                            ),
                            title: Text(
                              viewer.displayName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              viewer.purok != null && viewer.purok!.isNotEmpty
                                  ? 'Purok ${viewer.purok} • ${_formatViewedAt(viewer.viewedAt)}'
                                  : _formatViewedAt(viewer.viewedAt),
                              style: TextStyle(fontSize: 12.2, color: muted),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerFallbackAvatar extends StatelessWidget {
  const _ViewerFallbackAvatar({
    required this.initials,
    required this.isDark,
  });

  final String initials;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFEFF6F1),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF20BF6B),
        ),
      ),
    );
  }
}

/// Facebook-style media block: one image or grid for multiple; tap opens full screen.
class _AnnouncementCardMedia extends StatelessWidget {
  const _AnnouncementCardMedia({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: OptimizedNetworkImage(
            imageUrl: imageUrls.first,
            fit: BoxFit.cover,
            cacheWidth: 800,
            cacheHeight: 450,
            borderRadius: BorderRadius.circular(12),
            errorWidget: Container(
              color: Colors.grey.shade300,
              child: const Icon(Icons.image_not_supported),
            ),
            onTap: () => openFullScreenImage(context, imageUrls.first),
          ),
        ),
      );
    }

    final displayed = imageUrls.take(6).toList();
    return SizedBox(
      height: 200,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
          childAspectRatio: 1,
        ),
        itemCount: displayed.length,
        itemBuilder: (context, index) {
          final url = displayed[index];
          final isLast =
              index == displayed.length - 1 &&
              imageUrls.length > displayed.length;
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: OptimizedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  cacheHeight: 400,
                  errorWidget: Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image_not_supported),
                  ),
                  onTap:
                      () => openFullScreenImages(
                        context,
                        imageUrls,
                        initialIndex: index,
                      ),
                ),
              ),
              if (isLast)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black38,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+${imageUrls.length - displayed.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReadButton extends StatelessWidget {
  const _ReadButton({required this.isRead, this.onPressed});

  final bool isRead;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color borderColor =
        isRead
            ? const Color(0xFF4CAF50)
            : (isDark ? Colors.grey.shade700 : const Color(0xFFDADADA));
    final Color textColor =
        isRead
            ? const Color(0xFF4CAF50)
            : (isDark ? Colors.grey.shade300 : const Color(0xFF5F5F5F));
    final IconData icon = isRead ? Icons.check : Icons.visibility_outlined;

    return OutlinedButton.icon(
      onPressed: onPressed ?? () {},
      icon: Icon(icon, size: 18, color: textColor),
      label: Text(
        isRead ? 'Viewed' : 'View',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        side: BorderSide(color: borderColor, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
      ),
    );
  }
}
