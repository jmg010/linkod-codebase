import 'package:flutter/material.dart';
import '../models/bulletin_category_model.dart';
import '../widgets/category_card.dart';
import 'bulletin_category_screen.dart';

class BulletinBoardScreen extends StatelessWidget {
  const BulletinBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with white background container
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bulletin Board',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search,
                        color: Color(0xFF6E6E6E), size: 26),
                    onPressed: () {
                      // Search functionality - can be added later
                    },
                  ),
                ],
              ),
            ),

            // Categories list
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Subtitle
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Select a category to view bulletins',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),

                    // Category cards
                    for (final category in BulletinCategoryModel.categories)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CategoryCard(
                          category: category,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BulletinCategoryScreen(
                                  category: category,
                                ),
                              ),
                            );
                          },
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
}
