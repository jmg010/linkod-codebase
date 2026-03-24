import 'package:flutter/material.dart';
import '../widgets/optimized_image.dart';
import '../widgets/product_card.dart';

import '../models/product_model.dart';
import '../services/products_service.dart';
import '../services/firestore_service.dart';
import '../services/name_formatter.dart';
import 'product_detail_screen.dart';
import 'search_screen.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirestoreService.currentUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentUserId == null) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF4F4F4),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Please log in to view your products',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey.shade400 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button, title, and search icon
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      size: 20,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    splashRadius: 22,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Product Activity',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.search,
                      color:
                          isDark
                              ? Colors.grey.shade400
                              : const Color(0xFF5F5F5F),
                    ),
                    splashRadius: 22,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => const SearchScreen(
                                mode: SearchMode.myProducts,
                              ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Tab Bar with badge support
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _TabBarWithBadge(
                tabController: _tabController,
                userId: currentUserId,
              ),
            ),
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: MY PRODUCTS
                  _MyProductsTab(userId: currentUserId),
                  // Tab 2: INTERACTED POSTS (Activity Log)
                  _InteractedPostsTab(userId: currentUserId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBarWithBadge extends StatelessWidget {
  final TabController tabController;
  final String userId;

  const _TabBarWithBadge({required this.tabController, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: ProductsService.getTotalUnreadProductMessagesForSellerStream(
        userId,
      ),
      initialData: 0,
      builder: (context, sellerSnapshot) {
        return StreamBuilder<int>(
          stream: ProductsService.getTotalUnreadRepliesForUserStream(userId),
          initialData: 0,
          builder: (context, interactedSnapshot) {
            final myProductsUnread = sellerSnapshot.data ?? 0;
            final interactedUnread = interactedSnapshot.data ?? 0;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(24),
              ),
              child: AnimatedBuilder(
                animation: tabController,
                builder: (context, child) {
                  return Row(
                    children: [
                      // MY PRODUCTS Tab with badge
                      Expanded(
                        child: _TabButton(
                          label: 'MY PRODUCTS',
                          isSelected: tabController.index == 0,
                          badgeCount:
                              myProductsUnread > 0 ? myProductsUnread : null,
                          onTap: () => tabController.animateTo(0),
                        ),
                      ),
                      // INTERACTED POSTS Tab with badge
                      Expanded(
                        child: _TabButton(
                          label: 'INTERACTED POSTS',
                          isSelected: tabController.index == 1,
                          badgeCount:
                              interactedUnread > 0 ? interactedUnread : null,
                          onTap: () => tabController.animateTo(1),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// Individual tab button with optional badge
class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final int? badgeCount;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? (isDark ? const Color(0xFF2C2C2C) : Colors.white)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color:
                    isSelected
                        ? const Color(0xFF20BF6B)
                        : (isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600),
              ),
            ),
            if (badgeCount != null && badgeCount! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Center(
                  child: Text(
                    badgeCount! > 99 ? '99+' : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tab 1: MY PRODUCTS (existing functionality)
class _MyProductsTab extends StatelessWidget {
  final String userId;

  const _MyProductsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<MapEntry<ProductModel, int>>>(
      stream: ProductsService.getSellerProductsWithUnreadStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey.shade400 : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return _buildEmptyState(isDark);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final entry = list[index];
            final product = entry.key;
            final unreadCount = entry.value;
            return _MyProductCard(
              product: product,
              unreadCount: unreadCount,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: product),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No products posted yet',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab 2: INTERACTED POSTS (Activity Log)
class _InteractedPostsTab extends StatelessWidget {
  final String userId;

  const _InteractedPostsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<MapEntry<ProductModel, int>>>(
      stream: ProductsService.getUserInteractedProductsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey.shade400 : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return _buildEmptyState(isDark);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final entry = list[index];
            final product = entry.key;
            final unreadCount = entry.value;
            return _InteractedProductCard(
              product: product,
              unreadCount: unreadCount,
              onTap: () {
                // Mark messages as read when opening
                ProductsService.markProductMessagesAsRead(product.id, userId);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: product),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_outlined, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No interacted products yet',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Products you message will appear here',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final int unreadCount;

  const _MyProductCard({
    required this.product,
    required this.onTap,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _formatDate(product.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child:
                    product.imageUrls.isNotEmpty
                        ? OptimizedNetworkImage(
                          imageUrl: product.imageUrls.first,
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                          cacheHeight: 225,
                          errorWidget: _placeholder(),
                          onTap:
                              () => openFullScreenImages(
                                context,
                                product.imageUrls,
                                initialIndex: 0,
                              ),
                        )
                        : _placeholder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₱${product.price.toStringAsFixed(0)}/${product.priceUnit ?? _unit(product.category)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  side: BorderSide(
                    color:
                        isDark ? Colors.grey.shade700 : const Color(0xFFB5B5B5),
                    width: 1,
                  ),
                  backgroundColor:
                      isDark ? const Color(0xFF2C2C2C) : Colors.white,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Text(
                      'View and interact',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? Colors.white : const Color(0xFF3E3E3E),
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -10,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image, size: 32, color: Colors.grey),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final monthDay =
        '${_monthName(date.month)} ${date.day} at ${_formatTime(date)}';
    return monthDay;
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

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _unit(String category) {
    if (category.toLowerCase() == 'food') return 'kg';
    return 'pcs';
  }
}

/// Card for INTERACTED POSTS tab - custom card with badge inside button
class _InteractedProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final int unreadCount;

  const _InteractedProductCard({
    required this.product,
    required this.onTap,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date row (top right)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _formatDate(product.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color:
                      isDark ? Colors.grey.shade400 : const Color(0xFF8A8A8A),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child:
                    product.imageUrls.isNotEmpty
                        ? OptimizedNetworkImage(
                          imageUrl: product.imageUrls.first,
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                          cacheHeight: 225,
                          errorWidget: _placeholder(),
                          onTap:
                              () => openFullScreenImages(
                                context,
                                product.imageUrls,
                                initialIndex: 0,
                              ),
                        )
                        : _placeholder(),
              ),
            ),
            const SizedBox(height: 12),
            // Title and price row
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
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Posted by
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Posted by: ${NameFormatter.fromAnyDisplay(fullName: product.sellerName, fallback: 'User')}",
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
            const SizedBox(height: 14),
            // View and interact button with badge inside
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  side: BorderSide(
                    color:
                        isDark ? Colors.grey.shade700 : const Color(0xFFD9D9D9),
                  ),
                  backgroundColor:
                      isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Text(
                      'View and interact',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF3E3E3E),
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -14,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image, size: 32, color: Colors.grey),
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
}
