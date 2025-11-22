import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';
import 'sell_product_screen.dart';
import 'my_products_screen.dart';

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
      location: 'Purok 4 Kidid sa daycare center',
      contactNumber: '0978192739813',
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
    final bool isEmpty = _products.isEmpty;
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Search icon row with white background
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                      const Text(
                        'Marketplace',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search, color: Color(0xFF6E6E6E), size: 26),
                    onPressed: () {
                      debugPrint('Search marketplace');
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  _PrimaryPillButton(
                    label: 'Sell',
                    icon: Icons.edit_outlined,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SellProductScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  _SecondaryPillButton(
                    label: 'My product',
                    icon: Icons.inventory_2_outlined,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MyProductsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_basket_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No products available',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      physics: const ClampingScrollPhysics(),
                      itemCount: _products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return ProductCard(
                          product: product,
                          onInteract: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(
                                  product: product,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    }
}

class _PrimaryPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PrimaryPillButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF20BF6B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        elevation: 0,
      ),
    );
  }
}

class _SecondaryPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _SecondaryPillButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: const Color(0xFF30383F)),
      label: Text(
        label,
        style: const TextStyle(color: Color(0xFF30383F)),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}
