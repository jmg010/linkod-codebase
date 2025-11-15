import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../widgets/product_card.dart';
import '../ui_constants.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => MarketplaceScreenState();
}

class MarketplaceScreenState extends State<MarketplaceScreen> {
  final List<ProductModel> _products = [
    ProductModel(
      id: '1',
      sellerId: 'vendor1',
      sellerName: 'Maria\'s Store',
      title: 'Fresh Vegetables Bundle',
      description:
          'Fresh vegetables from local farms. Includes tomatoes, onions, and leafy greens.',
      price: 150.00,
      category: 'Food',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      isAvailable: true,
      imageUrls: const [
        'https://images.unsplash.com/photo-1514996937319-344454492b37',
      ],
    ),
    ProductModel(
      id: '2',
      sellerId: 'vendor2',
      sellerName: 'Juan\'s Crafts',
      title: 'Handmade Woven Basket',
      description:
          'Beautiful handwoven basket perfect for storage or decoration. Made with natural materials.',
      price: 350.00,
      category: 'Handicrafts',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isAvailable: true,
      imageUrls: const [
        'https://images.unsplash.com/photo-1523419409543-0c1df022bdd1',
      ],
    ),
    ProductModel(
      id: '3',
      sellerId: 'vendor3',
      sellerName: 'Lola\'s Kitchen',
      title: 'Homemade Ube Jam',
      description:
          'Delicious homemade ube jam made with fresh ingredients. Perfect for breakfast or snacks.',
      price: 120.00,
      category: 'Food',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      isAvailable: true,
      imageUrls: const [
        'https://images.unsplash.com/photo-1509440159596-0249088772ff',
      ],
    ),
    ProductModel(
      id: '4',
      sellerId: 'vendor1',
      sellerName: 'Maria\'s Store',
      title: 'Organic Rice (5kg)',
      description: 'Premium organic rice grown locally. Healthy and nutritious.',
      price: 280.00,
      category: 'Food',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      isAvailable: true,
      imageUrls: const [
        'https://images.unsplash.com/photo-1509440159596-0249088772ff',
      ],
    ),
    ProductModel(
      id: '5',
      sellerId: 'vendor4',
      sellerName: 'Artisan Pottery',
      title: 'Ceramic Plant Pot',
      description: 'Beautiful ceramic pot for your plants. Handcrafted with care.',
      price: 450.00,
      category: 'Handicrafts',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      isAvailable: true,
      imageUrls: const [
        'https://images.unsplash.com/photo-1457574173809-67cf0d13aa74',
      ],
    ),
    ProductModel(
      id: '6',
      sellerId: 'vendor2',
      sellerName: 'Juan\'s Crafts',
      title: 'Bamboo Placemats Set',
      description: 'Set of 4 eco-friendly bamboo placemats. Perfect for dining.',
      price: 200.00,
      category: 'Home',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      isAvailable: true,
      imageUrls: const [
        'https://images.unsplash.com/photo-1616628182501-a3d1e70f3f65',
      ],
    ),
    ProductModel(
      id: '7',
      sellerId: 'vendor5',
      sellerName: 'Local Honey Farm',
      title: 'Pure Honey (500ml)',
      description: '100% pure local honey. Natural and unprocessed.',
      price: 380.00,
      category: 'Food',
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
      isAvailable: true,
      imageUrls: const [
        'https://images.unsplash.com/photo-1514996937319-344454492b37',
      ],
    ),
    ProductModel(
      id: '8',
      sellerId: 'vendor3',
      sellerName: 'Lola\'s Kitchen',
      title: 'Coconut Oil (1L)',
      description: 'Cold-pressed virgin coconut oil. Great for cooking and skincare.',
      price: 250.00,
      category: 'Food',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      isAvailable: false,
      imageUrls: const [
        'https://images.unsplash.com/photo-1483478550801-ceba5fe50e8e',
      ],
    ),
  ];

  void addProduct(ProductModel product) {
    setState(() {
      _products.insert(0, product);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marketplace',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _PillButton(
                        label: 'Sell',
                        icon: Icons.sell_outlined,
                        color: kFacebookBlue,
                        foreground: Colors.white,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sell your items soon!')),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      _PillButton(
                        label: 'Categories',
                        icon: Icons.grid_view_rounded,
                        color: Colors.grey.shade200,
                        foreground: Colors.black87,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Categories coming soon!')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Today's picks",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                  ),
                ],
              ),
            ),
          ),
          if (_products.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_basket_outlined,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No products available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.7,
                ),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  return ProductCard(product: _products[index]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color foreground;
  final VoidCallback onPressed;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
      ),
    );
  }
}
