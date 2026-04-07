import 'package:flutter/material.dart';
import 'optimized_image.dart';
import '../services/name_formatter.dart';
import '../services/tasks_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'resident_profile_dialog.dart';

enum ErrandJobStatus { open, ongoing, completed }

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
  final String viewButtonLabel;
  final IconData viewButtonIcon;
  final String? taskId;
  final int viewCount;

  /// Optional image URLs for the errand (owner-attached). Shown like product card.
  final List<String> imageUrls;

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
    this.viewButtonLabel = 'View',
    this.viewButtonIcon = Icons.visibility_outlined,
    this.taskId,
    this.viewCount = 0,
    this.imageUrls = const [],
  });

  @override
  Widget build(BuildContext context) {
    final postedByDisplayName = NameFormatter.fromAnyDisplay(
      fullName: postedBy,
      fallback: 'User',
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.06),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade400,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Job/Errand',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      _formatDate(date),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark
                                ? Colors.grey.shade400
                                : const Color(0xFF6E6E6E),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            // Image section (when imageUrls provided)
            if (imageUrls.isNotEmpty) ...[
              _ErrandCardImage(imageUrls: imageUrls),
              const SizedBox(height: 12),
            ],
            // Title and status tag in same row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.25,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
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
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Color(0xFF6E6E6E),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Posted by: $postedByDisplayName',
                            style: TextStyle(
                              fontSize: 12.5,
                              color:
                                  isDark
                                      ? Colors.grey.shade400
                                      : const Color(0xFF6E6E6E),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _formatDate(date),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark
                                ? Colors.grey.shade400
                                : const Color(0xFF6E6E6E),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
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
                  Expanded(
                    child: Text(
                      'Posted by: $postedByDisplayName',
                      style: TextStyle(
                        fontSize: 12.5,
                        color:
                            isDark
                                ? Colors.grey.shade400
                                : const Color(0xFF6E6E6E),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            // Description
            Text(
              description,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.grey.shade300 : const Color(0xFF4C4C4C),
                height: 1.4,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                if (taskId != null && taskId!.isNotEmpty)
                  InkWell(
                    onTap: () => _showTaskViewersSheet(context),
                    child: Text(
                      '$viewCount views',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                        decoration: TextDecoration.underline,
                        decorationColor:
                            isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                      ),
                    ),
                  )
                else
                  Text(
                    '$viewCount views',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // Action button: View / Edit (or Volunteer when open and no assignee)
            if (volunteerName != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onViewPressed,
                  icon: Icon(
                    viewButtonIcon,
                    size: 16,
                    color: isDark ? Colors.white : const Color(0xFF4C4C4C),
                  ),
                  label: Text(
                    viewButtonLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF4C4C4C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    side: BorderSide(
                      color:
                          isDark
                              ? Colors.grey.shade700
                              : const Color(0xFFD0D0D0),
                    ),
                    backgroundColor:
                        isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  ),
                ),
              )
            else if (onViewPressed != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onViewPressed,
                  icon: Icon(
                    viewButtonIcon,
                    size: 16,
                    color: isDark ? Colors.white : const Color(0xFF4C4C4C),
                  ),
                  label: Text(
                    viewButtonLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF4C4C4C),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    side: BorderSide(
                      color:
                          isDark
                              ? Colors.grey.shade700
                              : const Color(0xFFD0D0D0),
                    ),
                    backgroundColor:
                        isDark ? const Color(0xFF2C2C2C) : Colors.white,
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
      'December',
    ];
    return months[month - 1];
  }

  void _showTaskViewersSheet(BuildContext context) {
    if (taskId == null || taskId!.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskViewersSheet(taskId: taskId!, totalCount: viewCount),
    );
  }
}

class _TaskViewersSheet extends StatefulWidget {
  const _TaskViewersSheet({required this.taskId, required this.totalCount});

  final String taskId;
  final int totalCount;

  @override
  State<_TaskViewersSheet> createState() => _TaskViewersSheetState();
}

class _TaskViewersSheetState extends State<_TaskViewersSheet> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<TaskViewer> _viewers = <TaskViewer>[];

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
      final page = await TasksService.getTaskViewersPage(
        taskId: widget.taskId,
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
      final page = await TasksService.getTaskViewersPage(
        taskId: widget.taskId,
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

  String? _formatDemographicCategories(dynamic categories) {
    if (categories is List) {
      final values =
          categories
              .map((e) => e?.toString().trim() ?? '')
              .where((e) => e.isNotEmpty)
              .toList();
      return values.isEmpty ? null : values.join(', ');
    }
    if (categories is String) {
      final value = categories.trim();
      return value.isEmpty ? null : value;
    }
    return null;
  }

  Future<void> _showViewerProfileDialog(TaskViewer viewer) async {
    String? avatarUrl = viewer.avatarUrl;
    String displayName = viewer.displayName;
    String? purok = viewer.purok;
    String? phoneNumber;
    String? demographicCategory;

    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(viewer.userId)
              .get();
      final data = userDoc.data();
      if (data != null) {
        final resolvedName = NameFormatter.fromUserDataFull(
          data,
          fallback: displayName,
        );
        if (resolvedName.isNotEmpty) {
          displayName = resolvedName;
        }
        final avatarValue =
            (data['avatarUrl'] as String?)?.trim() ??
            (data['profileImageUrl'] as String?)?.trim();
        if (avatarValue != null && avatarValue.isNotEmpty) {
          avatarUrl = avatarValue;
        }
        final purokValue = data['purok'];
        if (purokValue != null) {
          purok = purokValue.toString();
        }
        final phoneValue = (data['phoneNumber'] as String?)?.trim();
        if (phoneValue != null && phoneValue.isNotEmpty) {
          phoneNumber = phoneValue;
        }
        demographicCategory = _formatDemographicCategories(data['categories']);
      }
    } catch (_) {
      // Use viewer fallback data when profile fetch fails.
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder:
          (_) => ResidentProfileDialog(
            avatarUrl: avatarUrl,
            name: displayName,
            purok: purok,
            phoneNumber: phoneNumber,
            demographicCategory: demographicCategory,
            isSeller: false,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final muted = isDark ? Colors.grey.shade400 : const Color(0xFF6E6E6E);

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
                  Icon(
                    Icons.visibility_outlined,
                    color: isDark ? Colors.grey.shade300 : Colors.black87,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Errand Views',
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
                      ? const Center(child: CircularProgressIndicator())
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
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                      : _viewers.isEmpty
                      ? Center(
                        child: Text(
                          'No views yet',
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
                            onTap: () => _showViewerProfileDialog(viewer),
                            leading: CircleAvatar(
                              backgroundColor:
                                  isDark
                                      ? const Color(0xFF2E2E2E)
                                      : const Color(0xFFEFF6F1),
                              child:
                                  viewer.avatarUrl != null &&
                                          viewer.avatarUrl!.isNotEmpty
                                      ? ClipOval(
                                        child: OptimizedNetworkImage(
                                          imageUrl: viewer.avatarUrl!,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          cacheWidth: 80,
                                          cacheHeight: 80,
                                          errorWidget: _ErrandFallbackAvatar(
                                            initials: initials,
                                          ),
                                        ),
                                      )
                                      : _ErrandFallbackAvatar(initials: initials),
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

class _ErrandFallbackAvatar extends StatelessWidget {
  const _ErrandFallbackAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
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

/// Image area for errand card (single image or PageView; tap to fullscreen).
class _ErrandCardImage extends StatelessWidget {
  const _ErrandCardImage({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            width: double.infinity,
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            child: Icon(
              Icons.image_outlined,
              size: 40,
              color: Colors.grey.shade400,
            ),
          ),
        ),
      );
    }
    if (imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: OptimizedNetworkImage(
            imageUrl: imageUrls.first,
            fit: BoxFit.cover,
            cacheWidth: 800,
            cacheHeight: 450,
            borderRadius: BorderRadius.circular(14),
            errorWidget: _errorPlaceholder(),
            onTap:
                () => openFullScreenImages(context, imageUrls, initialIndex: 0),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: PageView.builder(
          itemCount: imageUrls.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap:
                  () => openFullScreenImages(
                    context,
                    imageUrls,
                    initialIndex: index,
                  ),
              child: OptimizedNetworkImage(
                imageUrl: imageUrls[index],
                fit: BoxFit.cover,
                cacheWidth: 800,
                cacheHeight: 450,
                borderRadius: BorderRadius.circular(14),
                errorWidget: _errorPlaceholder(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 40,
        color: Colors.grey.shade500,
      ),
    );
  }
}
