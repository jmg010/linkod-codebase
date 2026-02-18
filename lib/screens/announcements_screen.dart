import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../widgets/announcement_card.dart';
import '../services/announcements_service.dart';
import '../services/firestore_service.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => AnnouncementsScreenState();
}

class AnnouncementsScreenState extends State<AnnouncementsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  Set<String> _readAnnouncementIds = {};
  List<String> _userCategories = [];

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
    _loadUserCategories();
    _loadReadAnnouncements();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserCategories() async {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Per schema: users collection uses Firebase Auth UID as document ID
      final userDoc = await FirestoreService.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data();
        final categoryString = data?['category'] as String? ?? '';
        setState(() {
          _userCategories = categoryString
              .split(',')
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading user categories: $e');
    }
  }

  Future<void> _loadReadAnnouncements() async {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) return;

    try {
      final readIds = await AnnouncementsService.getReadAnnouncementIds(currentUser.uid);
      setState(() {
        _readAnnouncementIds = readIds;
      });
    } catch (e) {
      debugPrint('Error loading read announcements: $e');
    }
  }

  Future<void> _markAsRead(String announcementId) async {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) return;

    try {
      await AnnouncementsService.markAsRead(announcementId, currentUser.uid);
      setState(() {
        _readAnnouncementIds.add(announcementId);
      });
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  /// Add a post to announcements (called from home screen)
  /// Note: Since announcements are loaded via stream, this is mainly for compatibility
  void addPost(PostModel post) {
    // The stream will automatically update when a new announcement is added to Firestore
    // This method exists for compatibility with home_screen.dart
    // If needed, you could trigger a refresh here
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
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _selectedTabIndex == 0
                    ? AnnouncementsService.getAnnouncementsStream()
                    : AnnouncementsService.getAnnouncementsForUserStream(_userCategories),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading announcements',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  final announcements = snapshot.data ?? [];

                  if (announcements.isEmpty) {
                    return Center(
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
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    physics: const ClampingScrollPhysics(),
                    itemCount: announcements.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final announcement = announcements[index];
                      final announcementId = announcement['id'] as String;
                      final isRead = _readAnnouncementIds.contains(announcementId);
                      final viewCount = announcement['viewCount'] as int? ?? 0;
                      
                      return AnnouncementCard(
                        title: announcement['title'] as String? ?? '',
                        description: announcement['content'] as String? ?? announcement['description'] as String? ?? '',
                        postedBy: announcement['postedBy'] as String? ?? 'Barangay Official',
                        postedByPosition: announcement['postedByPosition'] as String?,
                        date: announcement['date'] as DateTime? ?? announcement['createdAt'] as DateTime,
                        category: announcement['category'] as String?,
                        unreadCount: viewCount,
                        isRead: isRead,
                        announcementId: announcementId,
                        onMarkAsReadPressed: () {
                          _markAsRead(announcementId);
                        },
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
