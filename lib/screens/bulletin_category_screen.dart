import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bulletin_category_model.dart';
import '../models/bulletin_model.dart';
import '../services/barangay_info_service.dart';
import '../widgets/barangay_info_posting_card.dart';

class BulletinCategoryScreen extends StatelessWidget {
  final BulletinCategoryModel category;

  const BulletinCategoryScreen({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.black87),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      category.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Bulletins list from Firestore
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: BarangayInfoService.getPostingsStream(category.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final postingsData = snapshot.data ?? [];

                  if (postingsData.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Convert Firestore data to BulletinModel
                  final bulletins = postingsData.map((data) {
                    final imageUrls = BarangayInfoService.getImageUrls(data);
                    final timestamp = data['date'] as Timestamp?;
                    final date = timestamp?.toDate() ?? DateTime.now();
                    final createdAt = data['createdAt'] is Timestamp
                        ? (data['createdAt'] as Timestamp).toDate()
                        : DateTime.now();

                    return BulletinModel(
                      id: data['id'] as String,
                      title: data['title'] as String? ?? 'Untitled',
                      description: data['description'] as String? ?? '',
                      imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
                      imageUrls: imageUrls,
                      categoryId: category.id,
                      date: date,
                      location: null,
                      createdAt: createdAt,
                      isPinned: false,
                      pdfUrl: data['pdfUrl'] as String?,
                      pdfName: data['pdfName'] as String?,
                    );
                  }).toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Category description
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: category.backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                category.icon,
                                color: category.iconColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  category.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Bulletin cards
                        for (final bulletin in bulletins)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: BarangayInfoPostingCard(
                              bulletin: bulletin,
                              pdfUrl: bulletin.pdfUrl,
                              pdfName: bulletin.pdfName,
                            ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            category.icon,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No bulletins yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Bulletins in this category will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
