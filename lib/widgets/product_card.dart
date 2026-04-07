import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'optimized_image.dart';
import '../models/product_model.dart';
import '../services/name_formatter.dart';
import '../services/products_service.dart';
import 'resident_profile_dialog.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onInteract;
  final bool showTag;

  const ProductCard({
    super.key,
    required this.product,
    this.onInteract,
    this.showTag = false,
  });

  @override
  Widget build(BuildContext context) {
    final sellerDisplayName = NameFormatter.fromAnyDisplay(
      fullName: product.sellerName,
      fallback: 'User',
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String dateText = _formatDate(product.createdAt);
    final bool hasImages = product.imageUrls.isNotEmpty;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1.5,
      shadowColor:
          isDark
              ? Colors.black.withOpacity(0.3)
              : Colors.black.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tag and date row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showTag)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade400,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'For Sale',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Text(
                  dateText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
              ],
            ),
            if (hasImages) ...[
              const SizedBox(height: 8),
              _ProductCardImage(product: product),
              const SizedBox(height: 12),
            ] else ...[
              const SizedBox(height: 4),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  product.priceUnit != null && product.priceUnit!.isNotEmpty
                      ? '₱${product.price.toStringAsFixed(0)}/${product.priceUnit}'
                      : '₱${product.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF00A651) : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Posted by: $sellerDisplayName',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                if (product.id.isNotEmpty)
                  InkWell(
                    onTap: () => _showProductViewersSheet(context),
                    child: Text(
                      '${product.viewCount} views',
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
                    '${product.viewCount} views',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed:
                    onInteract ??
                    () {
                      debugPrint('View and interact: ${product.title}');
                    },
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  side: BorderSide(
                    color:
                        isDark ? Colors.grey.shade700 : const Color(0xFFD9D9D9),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('View and interact'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.primary;
    return Container(
      color: color.withOpacity(0.08),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 40,
        color: color.withOpacity(0.7),
      ),
    );
  }

  String _formatDate(DateTime date) {
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
    final String monthName = months[date.month - 1];
    final int hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final String minutes = date.minute.toString().padLeft(2, '0');
    final String period = date.hour >= 12 ? 'PM' : 'AM';
    return '$monthName ${date.day} at $hour:$minutes $period';
  }

  void _showProductViewersSheet(BuildContext context) {
    if (product.id.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) =>
              _ProductViewersSheet(productId: product.id, totalCount: product.viewCount),
    );
  }
}

class _ProductViewersSheet extends StatefulWidget {
  const _ProductViewersSheet({required this.productId, required this.totalCount});

  final String productId;
  final int totalCount;

  @override
  State<_ProductViewersSheet> createState() => _ProductViewersSheetState();
}

class _ProductViewersSheetState extends State<_ProductViewersSheet> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<ProductViewer> _viewers = <ProductViewer>[];

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
      final page = await ProductsService.getProductViewersPage(
        productId: widget.productId,
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
      final page = await ProductsService.getProductViewersPage(
        productId: widget.productId,
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

  Future<void> _showViewerProfileDialog(ProductViewer viewer) async {
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
                          'Product Views',
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
                                          errorWidget: _FallbackAvatar(
                                            initials: initials,
                                          ),
                                        ),
                                      )
                                      : _FallbackAvatar(initials: initials),
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

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.initials});

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

/// Image area with auto-swipe when product has multiple images.
class _ProductCardImage extends StatefulWidget {
  const _ProductCardImage({required this.product});

  final ProductModel product;

  @override
  State<_ProductCardImage> createState() => _ProductCardImageState();
}

class _ProductCardImageState extends State<_ProductCardImage> {
  late PageController _pageController;
  Timer? _timer;
  static const Duration _autoSwipeInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.product.imageUrls.length > 1) {
      _timer = Timer.periodic(_autoSwipeInterval, (_) => _advancePage());
    }
  }

  void _advancePage() {
    if (!mounted || !_pageController.hasClients) return;
    final count = widget.product.imageUrls.length;
    if (count <= 1) return;
    final current = _pageController.page?.round() ?? 0;
    final next = (current + 1) % count;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final hasImages = product.imageUrls.isNotEmpty;
    if (!hasImages) {
      return const SizedBox.shrink();
    }
    if (product.imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            width: double.infinity,
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2C2C2C)
                    : Colors.grey.shade100,
            child: OptimizedNetworkImage(
              imageUrl: product.imageUrls.first,
              fit: BoxFit.cover,
              cacheWidth: 800,
              cacheHeight: 450,
              borderRadius: BorderRadius.circular(14),
              errorWidget: _errorPlaceholder(
                Theme.of(context).brightness == Brightness.dark,
              ),
              onTap:
                  () => openFullScreenImages(
                    context,
                    product.imageUrls,
                    initialIndex: 0,
                  ),
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          width: double.infinity,
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2C2C2C)
                  : Colors.grey.shade100,
          child: PageView.builder(
            controller: _pageController,
            itemCount: product.imageUrls.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap:
                    () => openFullScreenImages(
                      context,
                      product.imageUrls,
                      initialIndex: index,
                    ),
                child: OptimizedNetworkImage(
                  imageUrl: product.imageUrls[index],
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
      ),
    );
  }

  Widget _errorPlaceholder([bool isDark = false]) {
    return Container(
      color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 40,
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
      ),
    );
  }
}
