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
  String? barangayCoverImageUrl;
  String? barangayLogoUrl;
  String? barangayDisplayName;

  @override
  void initState() {
    super.initState();
    _loadBranding();
  }

  Future<void> _loadBranding() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('barangaySettings')
          .doc('branding')
          .get();
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          barangayCoverImageUrl = data?['barangayCoverImageUrl'] as String?;
          barangayLogoUrl = data?['barangayLogoUrl'] as String?;
          barangayDisplayName = data?['barangayDisplayName'] as String?;
        });
      }
    } catch (e) {
      // Silently fail - will show placeholders
    }
  }

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
    final backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F4F4);
    final green = const Color(0xFF20BF6B);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: BarangayInfoService.getCategoriesStream(),
          builder: (context, snapshot) {
            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Hero Header Section
                SliverToBoxAdapter(
                  child: _buildHeroHeader(context, isDark, green),
                ),

                // Categories Grid or Loading/Error States
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    child: Center(child: Text('Error: ${snapshot.error}')),
                  )
                else
                  _buildCategoriesGrid(snapshot.data ?? [], isDark),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context, bool isDark, Color green) {
    final bool hasCoverImage = barangayCoverImageUrl != null && barangayCoverImageUrl!.isNotEmpty;
    final bool hasLogo = barangayLogoUrl != null && barangayLogoUrl!.isNotEmpty;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Cover Image Container
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : green.withOpacity(0.15),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                child: hasCoverImage
                    ? Image.network(
                        barangayCoverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildCoverPlaceholder(green);
                        },
                      )
                    : Image.asset(
                        'assets/images/barangay_cover.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildCoverPlaceholder(green);
                        },
                      ),
              ),
            ),

            // Back Button
            Positioned(
              top: 12,
              left: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),

            // Circular Barangay Logo (overlapping bottom of cover)
            Positioned(
              top: 132, // Adjusted for larger size (was 140, now 132 to maintain similar overlap)
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    border: Border.all(
                      color: const Color(0xFFE6E6E6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Center(
                      child: hasLogo
                          ? Image.network(
                              barangayLogoUrl!,
                              width: 96,
                              height: 96,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildLogoPlaceholder(green);
                              },
                            )
                          : Image.asset(
                              'assets/linkod_logo.png',
                              width: 96,
                              height: 96,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildLogoPlaceholder(green);
                              },
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Spacer for logo overlap + text section
        const SizedBox(height: 60),

        // Barangay Name - centered
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            barangayDisplayName?.isNotEmpty == true
                ? barangayDisplayName!
                : 'Barangay Information',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.3,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Public Informations Label - left aligned, bold
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Public Information',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverPlaceholder(Color green) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            green.withOpacity(0.3),
            green.withOpacity(0.1),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.location_city_outlined,
          size: 64,
          color: green.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildLogoPlaceholder(Color green) {
    return Container(
      color: green.withOpacity(0.1),
      child: Icon(
        Icons.account_balance,
        size: 44,
        color: green,
      ),
    );
  }

  Widget _buildCategoriesGrid(List<Map<String, dynamic>> categoriesData, bool isDark) {
    if (categoriesData.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(isDark),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.0,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final categoryData = categoriesData[index];
            final iconCodePoint = categoryData['iconCodePoint'];
            final iconFontFamily = categoryData['iconFontFamily'] as String?;
            final title = categoryData['title'] as String? ?? 'Untitled';

            final predefined =
                BulletinCategoryModel.getById(categoryData['id'] as String) ??
                BulletinCategoryModel.getByTitle(title);

            final icon =
                BarangayInfoService.getIconFromCodePoint(
                  iconCodePoint,
                  iconFontFamily,
                ) ??
                predefined?.icon ??
                Icons.info_outline;

            return BarangayInfoCategoryCard(
              icon: icon,
              title: title,
              description: categoryData['description'] as String? ?? '',
              onTap: () {
                final category = BulletinCategoryModel(
                  id: categoryData['id'] as String,
                  title: title,
                  description: categoryData['description'] as String? ?? '',
                  icon: icon,
                  backgroundColor: predefined?.backgroundColor ?? const Color(0xFFE8F4FD),
                  iconColor: predefined?.iconColor ?? const Color(0xFF2196F3),
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
          childCount: categoriesData.length,
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
