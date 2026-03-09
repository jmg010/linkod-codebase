import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bulletin_category_model.dart';
import '../services/barangay_info_service.dart';
import '../widgets/barangay_info_category_card.dart';
import 'bulletin_category_screen.dart';

class BulletinBoardScreen extends StatefulWidget {
  const BulletinBoardScreen({super.key});

  @override
  State<BulletinBoardScreen> createState() => BulletinBoardScreenState();
}

class BulletinBoardScreenState extends State<BulletinBoardScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Container(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new,
                        color: isDark ? Colors.white : Colors.black87),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Baranggay Informations',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Categories list from Firestore
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: BarangayInfoService.getCategoriesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final categoriesData = snapshot.data ?? [];

                  if (categoriesData.isEmpty) {
                    return _buildEmptyState(isDark);
                  }

                  return SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section title
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Categories',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        // Category cards grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.0,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: categoriesData.length,
                          itemBuilder: (context, index) {
                            final categoryData = categoriesData[index];
                            final iconCodePoint =
                                categoryData['iconCodePoint'];
                            final iconFontFamily =
                                categoryData['iconFontFamily'] as String?;

                            // Try to get icon from Firestore, fallback to predefined
                            IconData? icon = BarangayInfoService.getIconFromCodePoint(
                              iconCodePoint,
                              iconFontFamily,
                            );

                            // Fallback to predefined categories if icon not found
                            final predefined =
                                BulletinCategoryModel.getById(categoryData['id']);
                            icon ??= predefined?.icon ?? Icons.info_outline;

                            return BarangayInfoCategoryCard(
                              icon: icon,
                              title: categoryData['title'] as String? ??
                                  'Untitled',
                              description: categoryData['description']
                                      as String? ??
                                  '',
                              onTap: () {
                                // Create category model from Firestore data
                                final category = BulletinCategoryModel(
                                  id: categoryData['id'] as String,
                                  title: categoryData['title'] as String? ??
                                      'Untitled',
                                  description: categoryData['description']
                                          as String? ??
                                      '',
                                  icon: icon ?? Icons.info_outline,
                                  backgroundColor: predefined
                                          ?.backgroundColor ??
                                      const Color(0xFFE8F4FD),
                                  iconColor: predefined?.iconColor ??
                                      const Color(0xFF2196F3),
                                );

                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BulletinCategoryScreen(
                                      category: category,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 80,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Categories Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Barangay information categories will appear here once they are added.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
