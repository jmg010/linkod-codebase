import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/announcement_card.dart';
import '../widgets/errand_job_card.dart';
import '../widgets/product_card.dart';
import '../widgets/post_card.dart';
import '../models/product_model.dart';
import '../models/task_model.dart';
import '../models/post_model.dart';
import '../services/posts_service.dart';
import '../services/tasks_service.dart';
import '../services/products_service.dart';
import '../services/announcements_service.dart';
import '../services/firestore_service.dart';
import 'product_detail_screen.dart';
import 'task_detail_screen.dart';
import 'search_screen.dart';

class HomeFeedScreen extends StatefulWidget {
  final ValueChanged<bool>? onUnreadAnnouncementsChanged;

  const HomeFeedScreen({super.key, this.onUnreadAnnouncementsChanged});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  Set<String> _readAnnouncementIds = {};
  List<String> _userCategories = [];

  static const int _initialPageSize = 15;
  static const int _loadMorePageSize = 15;
  int _displayCount = _initialPageSize;
  final ScrollController _scrollController = ScrollController();

  StreamController<List<Map<String, dynamic>>>? _feedController;
  StreamSubscription<List<Map<String, dynamic>>>? _announcementsSubscription;
  StreamSubscription<List<PostModel>>? _postsSubscription;
  StreamSubscription<List<TaskModel>>? _tasksSubscription;
  StreamSubscription<List<ProductModel>>? _productsSubscription;
  int _totalFeedLength = 0;
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _loadUserCategories();
    _loadReadAnnouncements();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _announcementsSubscription?.cancel();
    _postsSubscription?.cancel();
    _tasksSubscription?.cancel();
    _productsSubscription?.cancel();
    _feedController?.close();
    super.dispose();
  }

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll < 200) {
      _loadMoreIfNeeded();
    }
    final shouldShow = currentScroll > 400;
    if (shouldShow != _showBackToTop) {
      setState(() {
        _showBackToTop = shouldShow;
      });
    }
  }

  void _loadMoreIfNeeded() {
    if (_displayCount >= _totalFeedLength) return;
    setState(() {
      _displayCount = (_displayCount + _loadMorePageSize).clamp(0, _totalFeedLength);
    });
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

  Future<void> _markAnnouncementAsRead(String announcementId) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
          children: [
            // Title and Search icon row with white background
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Home',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFF6E6E6E), size: 26),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SearchScreen(mode: SearchMode.home),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Mixed feed list - combining posts, tasks, products, and announcements
            Expanded(
              child: _buildFeedStream(),
            ),
          ],
        ),
      );
    }

  Stream<List<Map<String, dynamic>>>? _feedStream;

  Stream<List<Map<String, dynamic>>> _getFeedStream() {
    _feedStream ??= _combineFeedStreams();
    return _feedStream!;
  }

  Widget _buildFeedStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getFeedStream(),
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
                  'Error loading feed',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final feedItems = snapshot.data ?? [];
        final withReadFlag = _tagReadStatus(feedItems);
        final sorted = _sortUnreadFirst(withReadFlag);
        final displayItems = sorted;

        final hasUnreadAnnouncements = sorted.any((item) {
          final type = item['type'] as String?;
          final isRead = item['isRead'] as bool? ?? false;
          return type == 'announcement' && !isRead;
        });
        if (widget.onUnreadAnnouncementsChanged != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onUnreadAnnouncementsChanged!(hasUnreadAnnouncements);
            }
          });
        }

        _totalFeedLength = displayItems.length;

        if (displayItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final todayItems = displayItems.where((item) => _isFromToday(item['timestamp'] as DateTime?, today)).toList();
        final olderItems = displayItems.where((item) => !_isFromToday(item['timestamp'] as DateTime?, today)).toList();

        final visibleCount = _displayCount.clamp(0, displayItems.length);
        final showLoadMore = visibleCount < displayItems.length;
        final visibleOlderCount = (visibleCount - todayItems.length).clamp(0, olderItems.length);

        return Stack(
          children: [
            Scrollbar(
              thumbVisibility: false,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                physics: const ClampingScrollPhysics(),
                itemCount: 2 + visibleOlderCount + (showLoadMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00A651).withOpacity(0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                            child: Text(
                              'New postings',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF00A651),
                              ),
                            ),
                          ),
                          if (todayItems.isEmpty)
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Text('No new postings today.', style: TextStyle(fontSize: 14, color: Colors.black54)),
                            )
                          else
                            ...todayItems.map((item) => Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: _buildFeedItem(item),
                            )),
                        ],
                      ),
                    );
                  }
                  if (index == 1) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                      child: Text(
                        'Older',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    );
                  }
                  if (showLoadMore && index == 2 + visibleOlderCount) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: GestureDetector(
                          onTap: _loadMoreIfNeeded,
                          child: Text(
                            'Load more',
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFF00A651),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  final olderIndex = index - 2;
                  final item = olderItems[olderIndex];
                  return Padding(
                    padding: EdgeInsets.only(bottom: olderIndex < visibleOlderCount - 1 ? 5 : 0),
                    child: _buildFeedItem(item),
                  );
                },
              ),
            ),
            if (_showBackToTop)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_upward,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _isFromToday(DateTime? t, DateTime today) {
    if (t == null) return false;
    final d = DateTime(t.year, t.month, t.day);
    return d == today;
  }

  Widget _buildFeedItem(Map<String, dynamic> item) {
              final type = item['type'] as String;

              if (type == 'announcement') {
                final announcementId = item['id'] as String;
                final isRead = _readAnnouncementIds.contains(announcementId);
                final viewCount = item['viewCount'] as int? ?? 0;
                return AnnouncementCard(
                  title: item['title'] as String? ?? '',
                  description: item['content'] as String? ?? item['description'] as String? ?? '',
                  postedBy: item['postedBy'] as String? ?? 'Barangay Official',
                  postedByPosition: item['postedByPosition'] as String?,
                  date: item['date'] as DateTime? ?? item['createdAt'] as DateTime,
                  category: item['category'] as String?,
                  unreadCount: viewCount,
                  isRead: isRead,
                  showTag: true,
                  announcementId: announcementId,
                  onMarkAsReadPressed: () {
                    _markAnnouncementAsRead(announcementId);
                  },
                );
              } else if (type == 'post') {
                final post = item['post'] as PostModel;
                return PostCard(post: post);
              } else if (type == 'task') {
                final task = item['task'] as TaskModel;
                final errandStatus = _mapTaskStatusToErrandStatus(task.status);
                return ErrandJobCard(
                  title: task.title,
                  description: task.description,
                  postedBy: task.requesterName,
                  date: task.createdAt,
                  status: errandStatus,
                  statusLabel: task.status.displayName,
                  volunteerName: task.assignedByName,
                  showTag: true,
                  onViewPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TaskDetailScreen(
                          task: task,
                          contactNumber: task.contactNumber,
                        ),
                      ),
                    );
                  },
                  onVolunteerPressed: task.status == TaskStatus.open && task.assignedByName == null
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TaskDetailScreen(
                                task: task,
                                contactNumber: task.contactNumber,
                              ),
                            ),
                          );
                        }
                      : null,
                );
              } else if (type == 'product') {
                final product = item['product'] as ProductModel;
                return ProductCard(
                  product: product,
                  showTag: true, // Show "For Sale" tag
                  onInteract: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(product: product),
                      ),
                    );
                  },
                );
              }
              return const SizedBox.shrink();
  }

  List<Map<String, dynamic>> _tagReadStatus(List<Map<String, dynamic>> items) {
    return items.map((item) {
      final type = item['type'] as String?;
      final isRead = type == 'announcement' && _readAnnouncementIds.contains(item['id'] as String?);
      return {...item, 'isRead': isRead};
    }).toList();
  }

  /// Announcements first (unread announcements then read), then other types by date descending
  List<Map<String, dynamic>> _sortUnreadFirst(List<Map<String, dynamic>> items) {
    final list = List<Map<String, dynamic>>.from(items);
    list.sort((a, b) {
      final aIsAnn = a['type'] == 'announcement';
      final bIsAnn = b['type'] == 'announcement';
      if (aIsAnn != bIsAnn) return aIsAnn ? -1 : 1;
      if (aIsAnn) {
        final aRead = a['isRead'] as bool? ?? false;
        final bRead = b['isRead'] as bool? ?? false;
        if (aRead != bRead) return aRead ? 1 : -1;
      }
      final aT = a['timestamp'] as DateTime? ?? DateTime(0);
      final bT = b['timestamp'] as DateTime? ?? DateTime(0);
      return bT.compareTo(aT);
    });
    return list;
  }

  Stream<List<Map<String, dynamic>>> _combineFeedStreams() {
    // Create controller only once
    _feedController ??= StreamController<List<Map<String, dynamic>>>.broadcast();
    
    List<Map<String, dynamic>>? lastAnnouncements;
    List<PostModel>? lastPosts;
    List<TaskModel>? lastTasks;
    List<ProductModel>? lastProducts;
    
    // Track which streams have emitted at least once
    bool announcementsReady = false;
    bool postsReady = false;
    bool tasksReady = false;
    bool productsReady = false;

    void emitCombined() {
      if (!mounted || _feedController == null || _feedController!.isClosed) {
        return;
      }

      final List<Map<String, dynamic>> feed = [];

      // Add announcements (use empty list if not ready yet); set timestamp so sort works
      if (announcementsReady && lastAnnouncements != null) {
        for (final announcement in lastAnnouncements!) {
          final createdAt = announcement['createdAt'] ?? announcement['date'];
          feed.add({
            'type': 'announcement',
            ...announcement,
            'timestamp': createdAt,
          });
        }
      }

      // Add posts (use empty list if not ready yet)
      if (postsReady && lastPosts != null) {
        for (final post in lastPosts!) {
          feed.add({
            'type': 'post',
            'post': post,
            'timestamp': post.createdAt,
          });
        }
      }

      // Add tasks (use empty list if not ready yet)
      if (tasksReady && lastTasks != null) {
        for (final task in lastTasks!) {
          if (task.status == TaskStatus.completed) continue;
          feed.add({
            'type': 'task',
            'task': task,
            'timestamp': task.createdAt,
          });
        }
      }

      // Add products (use empty list if not ready yet)
      if (productsReady && lastProducts != null) {
        for (final product in lastProducts!) {
          feed.add({
            'type': 'product',
            'product': product,
            'timestamp': product.createdAt,
          });
        }
      }

      // Sort by timestamp (order refined in _sortUnreadFirst after read status is applied)
      feed.sort((a, b) {
        final aTime = a['timestamp'] as DateTime? ?? DateTime(0);
        final bTime = b['timestamp'] as DateTime? ?? DateTime(0);
        return bTime.compareTo(aTime);
      });

      if (!_feedController!.isClosed) {
        _feedController!.add(feed);
      }
    }

    // Cancel existing subscriptions before creating new ones
    _announcementsSubscription?.cancel();
    _postsSubscription?.cancel();
    _tasksSubscription?.cancel();
    _productsSubscription?.cancel();

    // Listen to all streams with error handling
    _announcementsSubscription = AnnouncementsService.getAnnouncementsForUserStream(_userCategories)
        .listen(
      (announcements) {
        lastAnnouncements = announcements;
        announcementsReady = true;
        emitCombined();
      },
      onError: (error) {
        debugPrint('Error in announcements stream: $error');
        lastAnnouncements = [];
        announcementsReady = true;
        emitCombined();
      },
    );

    _postsSubscription = PostsService.getPostsStream().listen(
      (posts) {
        lastPosts = posts;
        postsReady = true;
        emitCombined();
      },
      onError: (error) {
        debugPrint('Error in posts stream: $error');
        lastPosts = [];
        postsReady = true;
        emitCombined();
      },
    );

    _tasksSubscription = TasksService.getTasksStream().listen(
      (tasks) {
        lastTasks = tasks;
        tasksReady = true;
        emitCombined();
      },
      onError: (error) {
        debugPrint('Error in tasks stream: $error');
        lastTasks = [];
        tasksReady = true;
        emitCombined();
      },
    );

    _productsSubscription = ProductsService.getProductsStream().listen(
      (products) {
        lastProducts = products;
        productsReady = true;
        emitCombined();
      },
      onError: (error) {
        debugPrint('Error in products stream: $error');
        lastProducts = [];
        productsReady = true;
        emitCombined();
      },
    );

    return _feedController!.stream;
  }

  ErrandJobStatus _mapTaskStatusToErrandStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return ErrandJobStatus.open;
      case TaskStatus.ongoing:
        return ErrandJobStatus.ongoing;
      case TaskStatus.completed:
        return ErrandJobStatus.completed;
    }
  }

  TaskStatus _mapErrandStatusToTaskStatus(ErrandJobStatus? errandStatus) {
    if (errandStatus == null) return TaskStatus.open;
    switch (errandStatus) {
      case ErrandJobStatus.open:
        return TaskStatus.open;
      case ErrandJobStatus.ongoing:
        return TaskStatus.ongoing;
      case ErrandJobStatus.completed:
        return TaskStatus.completed;
    }
  }
}


