import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../ui_constants.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;

  const ProductCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(kPaddingSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(context),
            const SizedBox(height: kPaddingSmall),
            Text(
              product.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kBodyText.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              product.sellerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kBodyText.copyWith(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final hasImages = product.imageUrls.isNotEmpty;
    final placeholderColor = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: hasImages
                ? Image.network(
                    product.imageUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholder(placeholderColor),
                  )
                : _buildPlaceholder(placeholderColor),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '₱${product.price.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(Color color) {
    return Container(
      color: color.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, size: 38, color: color),
    );
  }
}
