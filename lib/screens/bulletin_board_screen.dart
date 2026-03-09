import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bulletin_category_model.dart';
import '../services/barangay_info_service.dart';
import '../widgets/barangay_info_category_card.dart';
import 'bulletin_category_screen.dart';

class BulletinBoardScreen extends StatelessWidget {
  const BulletinBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF20BF6B);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with white background container (with back button)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF6E6E6E), size: 24),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Baranggay Informations',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
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
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No categories yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Categories will appear here when available',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Convert Firestore data to BulletinCategoryModel
                  final categories = categoriesData.map((data) {
                    final iconCodePoint = data['iconCodePoint'];
                    final iconFontFamily = data['iconFontFamily'] as String?;
                    final icon = BarangayInfoService.getIconFromCodePoint(
                          iconCodePoint,
                          iconFontFamily,
                        ) ??
                        Icons.info_outline;

                    return BulletinCategoryModel(
                      id: data['id'] as String,
                      title: data['title'] as String? ?? 'Untitled',
                      description: data['description'] as String? ?? '',
                      icon: icon,
                      backgroundColor: Colors.white,
                      iconColor: green,
                    );
                  }).toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: categories.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.12,
                          ),
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            return BarangayInfoCategoryCard(
                              icon: category.icon,
                              title: category.title,
                              description: category.description,
                              onTap: () {
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
}
