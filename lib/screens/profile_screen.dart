import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../models/post_model.dart';
import '../models/product_model.dart';
import '../widgets/post_card.dart';
import '../widgets/product_card.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  final UserRole userRole;

  const ProfileScreen({
    super.key,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    // Dummy data based on role
    final userPosts = _getUserPosts(userRole);
    final userProducts = _getUserProducts(userRole);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Profile Header
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Profile Avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Text(
                      userRole.displayName[0],
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // User Name (based on role)
                  Text(
                    _getUserName(userRole),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      userRole.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Barangay Name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Brgy. Cagbaoto, Bayabas, SdS',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Edit Profile Button
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Edit Profile feature coming soon!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // User Content Section
          SliverToBoxAdapter(
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Posts Section (for Officials)
                  if (userRole == UserRole.official && userPosts.isNotEmpty) ...[
                    const Text(
                      'My Announcements',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...userPosts.map((post) => PostCard(post: post)),
                  ],
                  // Products Section (for Vendors)
                  if (userRole == UserRole.vendor && userProducts.isNotEmpty) ...[
                    const Text(
                      'My Products',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: userProducts.length,
                      itemBuilder: (context, index) {
                        return ProductCard(product: userProducts[index]);
                      },
                    ),
                  ],
                  // Empty State
                  if ((userRole == UserRole.official && userPosts.isEmpty) ||
                      (userRole == UserRole.vendor && userProducts.isEmpty) ||
                      userRole == UserRole.resident) ...[
                    const SizedBox(height: 32),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            userRole == UserRole.resident
                                ? 'No posts or listings yet'
                                : userRole == UserRole.official
                                    ? 'No announcements yet'
                                    : 'No products yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getUserName(UserRole role) {
    switch (role) {
      case UserRole.official:
        return 'Barangay Official';
      case UserRole.vendor:
        return 'Maria\'s Store';
      case UserRole.resident:
        return 'Juan Dela Cruz';
    }
  }

  List<PostModel> _getUserPosts(UserRole role) {
    if (role != UserRole.official) return [];

    return [
      PostModel(
        id: 'p1',
        userId: 'official1',
        userName: 'Barangay Official',
        title: 'Community Clean-up Drive',
        content:
            'Join us this Saturday for a community clean-up drive. We will meet at the barangay hall at 7 AM. All residents are welcome!',
        category: PostCategory.health,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        likesCount: 45,
        commentsCount: 12,
      ),
      PostModel(
        id: 'p2',
        userId: 'official1',
        userName: 'Barangay Official',
        title: 'Free Medical Check-up',
        content:
            'Free medical check-up for senior citizens will be held next week. Please register at the barangay office.',
        category: PostCategory.health,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        likesCount: 78,
        commentsCount: 23,
      ),
    ];
  }

  List<ProductModel> _getUserProducts(UserRole role) {
    if (role != UserRole.vendor) return [];

    return [
      ProductModel(
        id: 'pr1',
        sellerId: 'vendor1',
        sellerName: 'Maria\'s Store',
        title: 'Fresh Vegetables Bundle',
        description: 'Fresh vegetables from local farms.',
        price: 150.00,
        category: 'Food',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        isAvailable: true,
      ),
      ProductModel(
        id: 'pr2',
        sellerId: 'vendor1',
        sellerName: 'Maria\'s Store',
        title: 'Organic Rice (5kg)',
        description: 'Premium organic rice grown locally.',
        price: 280.00,
        category: 'Food',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        isAvailable: true,
      ),
    ];
  }
}
