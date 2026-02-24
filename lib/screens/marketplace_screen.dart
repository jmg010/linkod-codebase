import 'package:flutter/material.dart';
import '../constants/marketplace_categories.dart';
import '../models/product_model.dart';
import '../widgets/product_card.dart';
import '../services/products_service.dart';
import '../services/firestore_service.dart';
import 'product_detail_screen.dart';
import 'sell_product_screen.dart';
import 'my_products_screen.dart';
import 'search_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => MarketplaceScreenState();
}

class MarketplaceScreenState extends State<MarketplaceScreen> {
  static const String _filterAll = 'All';
  List<String> get _categoryFilters => [_filterAll, ...MarketplaceCategories.ids];
  String _selectedCategory = 'All';

  static const int _initialPageSize = 15;
  static const int _loadMorePageSize = 15;
  int _displayCount = _initialPageSize;
  int _totalProductCount = 0;
  final ScrollController _scrollController = ScrollController();

  void addProduct(ProductModel product) {
    // Product will be added to Firestore and stream will update automatically
  }

  List<ProductModel> _filterByCategory(List<ProductModel> products) {
    if (_selectedCategory == _filterAll) return products;
    return products.where((p) => p.category == _selectedCategory).toList();
  }

  static bool _isFromToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll < 200) _loadMoreIfNeeded();
  }

  void _loadMoreIfNeeded() {
    if (_displayCount >= _totalProductCount) return;
    setState(() {
      _displayCount = (_displayCount + _loadMorePageSize).clamp(0, _totalProductCount);
    });
  }

  String get _categoryButtonLabel {
    if (_selectedCategory == _filterAll) return 'Categories';
    final full = MarketplaceCategories.label(_selectedCategory);
    if (full.length <= 22) return full;
    return '${full.substring(0, 19)}...';
  }

  Future<void> _showCategoryPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final items = _categoryFilters;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.category_outlined, size: 20, color: Color(0xFF30383F)),
                    const SizedBox(width: 8),
                    const Text(
                      'Change Category',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: 380,
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final cat = items[index];
                    final isSelected = cat == _selectedCategory;
                    final label = cat == _filterAll
                        ? 'All categories'
                        : MarketplaceCategories.label(cat);
                    return ListTile(
                      title: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? const Color(0xFF20BF6B) : Colors.black87,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(cat),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != _selectedCategory) {
      setState(() {
        _selectedCategory = selected;
        _displayCount = _initialPageSize;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SearchScreen(mode: SearchMode.products),
                            ),
                          );
                        },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
                  const SizedBox(width: 12),
                  Flexible(
                    child: _SecondaryPillButton(
                      label: _categoryButtonLabel,
                      icon: Icons.category_outlined,
                      onPressed: _showCategoryPicker,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ProductModel>>(
                stream: ProductsService.getProductsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading products',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  final allProducts = snapshot.data ?? [];
                  final currentUserId = FirestoreService.currentUserId;
                  final feedProducts = currentUserId != null
                      ? allProducts.where((p) => p.sellerId != currentUserId).toList()
                      : allProducts;
                  final filtered = _filterByCategory(feedProducts);
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final todayProducts = filtered.where((p) {
                    final d = p.createdAt;
                    return d.year == today.year && d.month == today.month && d.day == today.day;
                  }).toList();
                  final restProducts = filtered.where((p) => !_isFromToday(p.createdAt)).toList();
                  final orderedProducts = [...todayProducts, ...restProducts];
                  _totalProductCount = orderedProducts.length;

                  if (orderedProducts.isEmpty) {
                    return Center(
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
                    );
                  }

                  final visibleCount = _displayCount.clamp(0, orderedProducts.length);
                  final showLoadMore = visibleCount < orderedProducts.length;
                  final hasTodaysPicks = todayProducts.isNotEmpty;
                  final visibleRestCount = (visibleCount - todayProducts.length).clamp(0, restProducts.length);

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    physics: const ClampingScrollPhysics(),
                    itemCount: 2 + visibleRestCount + (showLoadMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF00A651).withOpacity(0.4), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                                child: Text(
                                  "Today's Picks",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF00A651),
                                  ),
                                ),
                              ),
                              if (todayProducts.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: Text('No new postings today.', style: TextStyle(fontSize: 14, color: Colors.black54)),
                                )
                              else
                                ...todayProducts.map((product) => Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  child: ProductCard(
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
                                  ),
                                )),
                            ],
                          ),
                        );
                      }
                      if (index == 1) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                          child: Text(
                            'Older',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        );
                      }
                      if (showLoadMore && index == 2 + visibleRestCount) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: GestureDetector(
                              onTap: _loadMoreIfNeeded,
                              child: Text(
                                'Load more',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF00A651),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      final product = restProducts[index - 2];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index - 2 < visibleRestCount - 1 ? 16 : 0,
                        ),
                        child: ProductCard(
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
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF20BF6B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(0, 36),
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
      icon: Icon(icon, size: 16, color: const Color(0xFF30383F)),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF30383F),
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}
