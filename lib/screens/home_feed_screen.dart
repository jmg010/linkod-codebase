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

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  Set<String> _readAnnouncementIds = {};
  List<String> _userCategories = [];
  
  StreamController<List<Map<String, dynamic>>>? _feedController;
  StreamSubscription<List<Map<String, dynamic>>>? _announcementsSubscription;
  StreamSubscription<List<PostModel>>? _postsSubscription;
  StreamSubscription<List<TaskModel>>? _tasksSubscription;
  StreamSubscription<List<ProductModel>>? _productsSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserCategories();
    _loadReadAnnouncements();
  }

  @override
  void dispose() {
    _announcementsSubscription?.cancel();
    _postsSubscription?.cancel();
    _tasksSubscription?.cancel();
    _productsSubscription?.cancel();
    _feedController?.close();
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
                      debugPrint('Search pressed');
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

        if (feedItems.isEmpty) {
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

        return Scrollbar(
          thumbVisibility: false,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            physics: const ClampingScrollPhysics(),
            itemCount: feedItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 0),
            itemBuilder: (context, index) {
              final item = feedItems[index];
              final type = item['type'] as String;

              if (type == 'announcement') {
                final announcementId = item['id'] as String;
                final isRead = _readAnnouncementIds.contains(announcementId);
                return AnnouncementCard(
                  title: item['title'] as String? ?? '',
                  description: item['content'] as String? ?? item['description'] as String? ?? '',
                  postedBy: item['postedBy'] as String? ?? 'Barangay Official',
                  date: item['date'] as DateTime? ?? item['createdAt'] as DateTime,
                  category: item['category'] as String?,
                  unreadCount: null,
                  isRead: isRead,
                  showTag: true,
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
            },
          ),
        );
      },
    );
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

      // Add announcements (use empty list if not ready yet)
      if (announcementsReady && lastAnnouncements != null) {
        for (final announcement in lastAnnouncements!) {
          feed.add({
            'type': 'announcement',
            ...announcement,
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

      // Sort by timestamp (newest first)
      feed.sort((a, b) {
        final aTime = a['timestamp'] as DateTime? ?? DateTime.now();
        final bTime = b['timestamp'] as DateTime? ?? DateTime.now();
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


