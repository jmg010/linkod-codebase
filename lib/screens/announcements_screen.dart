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
                              'Announcements',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.search, color: Color(0xFF6E6E6E), size: 26),
                    onPressed: () {
                      debugPrint('Search announcements');
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
              child: Row(
                children: [
                  _SegmentedToggle(
                    label: 'All',
                    isSelected: _selectedTabIndex == 0,
                    onTap: () {
                      setState(() {
                        _selectedTabIndex = 0;
                        _tabController.animateTo(0);
                      });
                    },
                  ),
                  const SizedBox(width: 24),
                  _SegmentedToggle(
                    label: 'For me',
                    isSelected: _selectedTabIndex == 1,
                    onTap: () {
                      setState(() {
                        _selectedTabIndex = 1;
                        _tabController.animateTo(1);
                      });
                    },
                  ),
                ],
              ),
            ),
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
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      physics: const ClampingScrollPhysics(),
                      itemCount: _filteredAnnouncements.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
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
          ],
        ),
      );
    }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color activeColor = Colors.black87;
    final Color inactiveColor = const Color(0xFF6E6E6E);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 3.2,
              width: double.infinity,
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFF20BF6B) : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
