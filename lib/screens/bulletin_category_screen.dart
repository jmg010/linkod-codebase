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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            _buildHeader(context, isDark),

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
                    return _buildEmptyState(isDark);
                  }

                  // Convert Firestore data to BulletinModel
                  final bulletins = _convertToBulletins(postingsData);

                  // Separate pinned and regular bulletins
                  final pinnedBulletins = bulletins.where((b) => b.isPinned).toList();
                  final regularBulletins = bulletins.where((b) => !b.isPinned).toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category description card
                        _buildCategoryDescription(context, isDark),

                        const SizedBox(height: 24),

                        // Pinned Section
                        if (pinnedBulletins.isNotEmpty) ...[
                          _buildSectionHeader(
                            icon: Icons.push_pin,
                            title: 'Pinned Items',
                            iconColor: const Color(0xFF20BF6B),
                          ),
                          const SizedBox(height: 12),
                          for (final bulletin in pinnedBulletins)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: BarangayInfoPostingCard(bulletin: bulletin),
                            ),
                          const SizedBox(height: 16),
                        ],

                        // All Posts Section
                        if (regularBulletins.isNotEmpty) ...[
                          _buildSectionHeader(
                            icon: Icons.article_outlined,
                            title: 'All Items',
                            iconColor: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                          ),
                          const SizedBox(height: 12),
                          for (final bulletin in regularBulletins)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: BarangayInfoPostingCard(bulletin: bulletin),
                            ),
                        ],

                        const SizedBox(height: 24),
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

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: isDark ? Colors.white : Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Barangay Information',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDescription(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF20BF6B).withOpacity(0.1),
            const Color(0xFF20BF6B).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF20BF6B).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF20BF6B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              category.icon,
              color: const Color(0xFF20BF6B),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About this category',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: iconColor,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  List<BulletinModel> _convertToBulletins(List<Map<String, dynamic>> postingsData) {
    return postingsData.map((data) {
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
        location: data['location'] as String?,
        createdAt: createdAt,
        isPinned: data['isPinned'] as bool? ?? false,
        pdfUrl: data['pdfUrl'] as String?,
        pdfName: data['pdfName'] as String?,
      );
    }).toList();
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            category.icon,
            size: 80,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No bulletins yet',
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
              'Bulletins in this category will appear here.',
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
