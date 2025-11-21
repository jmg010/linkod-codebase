import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../widgets/announcement_card.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => AnnouncementsScreenState();
}

class AnnouncementsScreenState extends State<AnnouncementsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Announcements only (for Announcements screen)
  final List<Map<String, dynamic>> _announcements = [
    {
      'title': 'Health Check-up Schedule',
      'description':
          'Free health check-up for all residents will be held on Saturday, 10 AM at the Barangay Hall. Please bring your health cards.',
      'postedBy': 'Barangay Official',
      'date': DateTime(2025, 11, 12),
      'category': 'Health',
      'unreadCount': 21,
      'isRead': false,
    },
    {
      'title': 'Livelihood Training Program',
      'description':
          'Free health check-up for all residents will be held on Saturday, 10 AM at the Barangay Hall. Please bring your health cards.',
      'postedBy': 'Barangay Official',
      'date': DateTime(2025, 11, 12),
      'category': 'Livelihood',
      'unreadCount': 21,
      'isRead': true,
    },
  ];

  void addPost(PostModel post) {
    setState(() {
      _announcements.insert(0, {
        'title': post.title,
        'description': post.content,
        'postedBy': post.userName,
        'date': post.createdAt,
        'category': post.category.displayName,
        'unreadCount': 0,
        'isRead': false,
      });
    });
  }

  List<Map<String, dynamic>> get _filteredAnnouncements {
    if (_selectedTabIndex == 0) {
      // "All" tab - show all announcements
      return _announcements;
    } else {
      // "For me" tab - filter logic can be added here
      return _announcements;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            // Title and Search icon row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Announcements',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.search, color: Colors.grey.shade800),
                    onPressed: () {
                      debugPrint('Search pressed');
                    },
                  ),
                ],
              ),
            ),
            
            // Tabs: "All" and "For me"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildTab('All', 0),
                  const SizedBox(width: 24),
                  _buildTab('For me', 1),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Announcements list
            Expanded(
              child: _filteredAnnouncements.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.campaign, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No announcements yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: false,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        physics: const ClampingScrollPhysics(),
                        itemCount: _filteredAnnouncements.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 0),
                        itemBuilder: (context, index) {
                          final item = _filteredAnnouncements[index];
                          return AnnouncementCard(
                            title: item['title'] as String,
                            description: item['description'] as String,
                            postedBy: item['postedBy'] as String,
                            date: item['date'] as DateTime,
                            category: item['category'] as String?,
                            unreadCount: item['unreadCount'] as int?,
                            isRead: item['isRead'] as bool? ?? false,
                            onMarkAsReadPressed: () {
                              setState(() {
                                item['isRead'] = true;
                              });
                              debugPrint('Mark as read pressed for: ${item['title']}');
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
          _tabController.animateTo(index);
        });
      },
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.black87 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            width: label.length * 10.0,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF20BF6B) : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

}
