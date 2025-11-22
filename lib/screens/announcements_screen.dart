import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/dummy_data_service.dart';
import '../widgets/announcement_card.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => AnnouncementsScreenState();
}

class AnnouncementsScreenState extends State<AnnouncementsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  final DummyDataService _dataService = DummyDataService();
  
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

  List<Map<String, dynamic>> get _announcements => _dataService.announcements;
  
  void _refreshAnnouncements() {
    setState(() {});
  }

  void addPost(PostModel post) {
    final announcement = {
      'id': 'announcement-${DateTime.now().millisecondsSinceEpoch}',
      'title': post.title,
      'description': post.content,
      'postedBy': post.userName,
      'date': post.createdAt,
      'category': post.category.displayName,
      'unreadCount': 0,
      'viewCount': 0,
      'isRead': false,
    };
    _dataService.addAnnouncement(announcement);
    _refreshAnnouncements();
  }

  List<Map<String, dynamic>> get _filteredAnnouncements {
    if (_selectedTabIndex == 0) {
      // "All" tab - show all announcements
      return _announcements;
    } else {
      // "For me" tab - filter by user's demographic categories
      final userDemographics = _dataService.getCurrentUserDemographics();
      return _announcements.where((announcement) {
        return _dataService.isAnnouncementRelevantForUser(announcement, userDemographics);
      }).toList();
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
                          viewCount: item['viewCount'] as int?,
                          isRead: item['isRead'] as bool? ?? false,
                          onMarkAsReadPressed: () {
                            final announcementId = item['id'] as String?;
                            if (announcementId != null) {
                              _dataService.markAnnouncementAsRead(announcementId);
                              _refreshAnnouncements();
                            }
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
