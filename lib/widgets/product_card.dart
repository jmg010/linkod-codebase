import 'dart:async';

import 'package:flutter/material.dart';
import 'optimized_image.dart';
import '../models/product_model.dart';

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
    final String dateText = _formatDate(product.createdAt);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1.5,
      shadowColor: Colors.black.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            const SizedBox(height: 8),
            _ProductCardImage(product: product),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Posted by: ${product.sellerName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onInteract ??
                    () {
                      debugPrint('View and interact: ${product.title}');
                    },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Color(0xFFD9D9D9)),
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
      child: Icon(Icons.image_outlined, size: 40, color: color.withOpacity(0.7)),
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
      'December'
    ];
    final String monthName = months[date.month - 1];
    final int hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final String minutes = date.minute.toString().padLeft(2, '0');
    final String period = date.hour >= 12 ? 'PM' : 'AM';
    return '$monthName ${date.day} at $hour:$minutes $period';
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 160,
          width: double.infinity,
          color: Colors.grey.shade100,
          alignment: Alignment.center,
          child: Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade400),
        ),
      );
    }
    if (product.imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 160,
          width: double.infinity,
          color: Colors.grey.shade100,
          child: OptimizedNetworkImage(
            imageUrl: product.imageUrls.first,
            height: 160,
            fit: BoxFit.cover,
            cacheWidth: 400,
            cacheHeight: 400,
            borderRadius: BorderRadius.circular(14),
            errorWidget: _errorPlaceholder(),
            onTap: () => openFullScreenImages(context, product.imageUrls, initialIndex: 0),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 160,
        width: double.infinity,
        color: Colors.grey.shade100,
        child: PageView.builder(
          controller: _pageController,
          itemCount: product.imageUrls.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => openFullScreenImages(context, product.imageUrls, initialIndex: index),
              child: OptimizedNetworkImage(
                imageUrl: product.imageUrls[index],
                height: 160,
                fit: BoxFit.cover,
                cacheWidth: 400,
                cacheHeight: 400,
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
      child: Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey.shade500),
    );
  }
}
