import 'package:flutter/material.dart';
import '../ui_constants.dart';
import 'help_detail_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<HelpCategory> _allCategories = [];
  List<HelpCategory> _filteredCategories = [];

  @override
  void initState() {
    super.initState();
    _initializeCategories();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _initializeCategories() {
    _allCategories = [
      HelpCategory(
        icon: Icons.rocket_launch,
        title: 'Getting Started',
        description: 'Learn the basics of using LINKod',
        articles: [
          HelpArticle(
            title: 'What is LINKod?',
            content:
                'LINKod is a community platform where residents can view announcements, post errands, and buy or sell items in the marketplace.',
          ),
          HelpArticle(
            title: 'How to create an account',
            content:
                'To create an account, download the LINKod app and follow the registration process. You\'ll need to provide your phone number and basic information.',
          ),
          HelpArticle(
            title: 'How to login',
            content:
                'Open the app and enter your phone number and password. If you forgot your password, use the "Forgot Password" option to reset it.',
          ),
          HelpArticle(
            title: 'Basic navigation of the app',
            content:
                'The app has a main navigation bar at the bottom with Home, Marketplace, Tasks, Announcements, and Menu options.',
          ),
        ],
      ),
      HelpCategory(
        icon: Icons.person,
        title: 'Account & Profile',
        description: 'Manage your personal account settings',
        articles: [
          HelpArticle(
            title: 'Edit profile',
            content:
                'To edit your profile, go to Menu → Edit Profile → Update your details → Save.',
          ),
          HelpArticle(
            title: 'Change profile picture',
            content:
                'Go to Menu → Edit Profile → Tap on your profile picture → Choose from gallery or take a new photo → Save.',
          ),
          HelpArticle(
            title: 'Update phone number',
            content:
                'Navigate to Menu → Edit Profile → Phone Number → Enter new number → Verify OTP → Save.',
          ),
          HelpArticle(
            title: 'Account privacy',
            content:
                'You can control your privacy settings in Menu → Edit Profile → Privacy. Choose who can see your information and posts.',
          ),
        ],
      ),
      HelpCategory(
        icon: Icons.campaign,
        title: 'Announcements',
        description: 'Learn about community announcements',
        articles: [
          HelpArticle(
            title: 'Who can post announcements',
            content:
                'Announcements are posted by barangay administrators to inform residents about important updates.',
          ),
          HelpArticle(
            title: 'How residents view announcements',
            content:
                'Residents can view announcements in the Announcements section of the app. New announcements appear at the top.',
          ),
          HelpArticle(
            title: 'Types of announcements',
            content:
                'Announcements can include events, meetings, alerts, and important community updates.',
          ),
        ],
      ),
      HelpCategory(
        icon: Icons.store,
        title: 'Marketplace',
        description: 'Buy and sell items in the community',
        articles: [
          HelpArticle(
            title: 'How to post an item',
            content:
                'Go to Marketplace → Tap the "+" button → Add photos → Enter details → Set price → Post.',
          ),
          HelpArticle(
            title: 'How to contact a seller',
            content:
                'Tap on any item → View seller information → Use the in-app chat or call button to contact.',
          ),
          HelpArticle(
            title: 'Marketplace rules',
            content:
                'All items must be legal and appropriate. No illegal items, weapons, or prohibited goods are allowed.',
          ),
          HelpArticle(
            title: 'Removing a listing',
            content:
                'Go to My Posts → Select the item → Tap "Remove" → Confirm removal.',
          ),
        ],
      ),
      HelpCategory(
        icon: Icons.handshake,
        title: 'Errands',
        description: 'Request help from community members',
        articles: [
          HelpArticle(
            title: 'How to post an errand',
            content:
                'Go to Tasks → Tap "+" → Select "Errand" → Describe the task → Set reward → Post.',
          ),
          HelpArticle(
            title: 'Accepting errands',
            content:
                'Browse available errands → Tap on one you can help with → Contact the requester → Complete the task.',
          ),
          HelpArticle(
            title: 'Canceling errands',
            content:
                'Go to My Tasks → Select the errand → Tap "Cancel" → Provide reason → Confirm cancellation.',
          ),
        ],
      ),
      HelpCategory(
        icon: Icons.shield,
        title: 'Community Guidelines',
        description: 'Keep the platform safe and respectful',
        articles: [
          HelpArticle(
            title: 'Respectful communication',
            content:
                'Always be polite and respectful when interacting with other community members. No harassment or offensive language.',
          ),
          HelpArticle(
            title: 'Safe transactions',
            content:
                'Always meet in public places when buying or selling items. Verify items before payment and use secure payment methods.',
          ),
          HelpArticle(
            title: 'No scams or illegal items',
            content:
                'Scams, fraud, and illegal activities are strictly prohibited. Report suspicious behavior immediately.',
          ),
          HelpArticle(
            title: 'Reporting suspicious users',
            content:
                'If you encounter suspicious behavior, use the Report feature or contact support immediately.',
          ),
        ],
      ),
      HelpCategory(
        icon: Icons.support_agent,
        title: 'Contact Support',
        description: 'Get help from our support team',
        articles: [
          HelpArticle(
            title: 'Contact email',
            content:
                'For general inquiries, email us at linkoddeveloper@gmail.com. We typically respond within 24 hours.',
          ),
          HelpArticle(
            title: 'Report a Problem',
            content:
                'If you experience issues with the app, please submit a report through the Report a Problem section in the Menu.',
          ),
          HelpArticle(
            title: 'FAQ',
            content:
                'Check our Frequently Asked Questions section for quick answers to common issues.',
          ),
        ],
      ),
    ];
    _filteredCategories = List.from(_allCategories);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        _filteredCategories = List.from(_allCategories);
      } else {
        _filteredCategories =
            _allCategories.where((category) {
              // Check if category title or description matches
              if (category.title.toLowerCase().contains(query) ||
                  category.description.toLowerCase().contains(query)) {
                return true;
              }

              // Check if any article title or content matches
              return category.articles.any(
                (article) =>
                    article.title.toLowerCase().contains(query) ||
                    article.content.toLowerCase().contains(query),
              );
            }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          'Help Center',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            padding: const EdgeInsets.all(kPaddingMedium),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for help topics...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          ),

          // Help Categories List
          Expanded(
            child:
                _filteredCategories.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: kPaddingMedium),
                          Text(
                            'No results found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: kPaddingSmall),
                          Text(
                            'Try different keywords',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kPaddingSmall,
                      ),
                      itemCount: _filteredCategories.length,
                      itemBuilder: (context, index) {
                        final category = _filteredCategories[index];
                        return HelpCategoryCard(
                          category: category,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        HelpDetailScreen(category: category),
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

class HelpCategory {
  final IconData icon;
  final String title;
  final String description;
  final List<HelpArticle> articles;

  HelpCategory({
    required this.icon,
    required this.title,
    required this.description,
    required this.articles,
  });
}

class HelpArticle {
  final String title;
  final String content;

  HelpArticle({required this.title, required this.content});
}

class HelpCategoryCard extends StatelessWidget {
  final HelpCategory category;
  final VoidCallback onTap;

  const HelpCategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: kPaddingSmall / 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: Padding(
          padding: const EdgeInsets.all(kPaddingMedium),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category.icon,
                  color: const Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
              const SizedBox(width: kPaddingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: kHeadlineSmall.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.description,
                      style: kBodyText.copyWith(
                        color:
                            isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
