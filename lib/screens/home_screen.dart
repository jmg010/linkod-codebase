import 'package:flutter/material.dart';
import '../ui_constants.dart';
import '../models/user_role.dart';
import '../models/post_model.dart';
import '../models/product_model.dart';
import '../models/task_model.dart';
import '../widgets/linkod_navbar.dart';
import '../services/tasks_service.dart';
import '../services/task_chat_service.dart';
import '../services/posts_service.dart';
import '../services/products_service.dart';
import '../services/firestore_service.dart';
import 'home_feed_screen.dart';
import 'announcements_screen.dart';
import 'marketplace_screen.dart';
import 'tasks_screen.dart';
import 'menu_screen.dart';
import 'create_post_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserRole userRole;

  const HomeScreen({
    super.key,
    required this.userRole,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  NavDestination _currentNavDestination = NavDestination.home;
  late PageController _pageController;
  final GlobalKey<AnnouncementsScreenState> _announcementsKey =
      GlobalKey<AnnouncementsScreenState>();
  final GlobalKey<MarketplaceScreenState> _marketplaceKey =
      GlobalKey<MarketplaceScreenState>();
  final GlobalKey<TasksScreenState> _tasksKey = GlobalKey<TasksScreenState>();
  bool _hasUnreadAnnouncements = false;
  String? _cachedErrandUid;
  Stream<int>? _cachedErrandStream;
  String? _cachedTaskChatUid;
  Stream<int>? _cachedTaskChatStream;
  String? _cachedPostCommentsUid;
  Stream<int>? _cachedPostCommentsStream;
  String? _cachedMarketplaceUid;
  Stream<int>? _cachedMarketplaceStream;
  late final bool _isResident = widget.userRole == UserRole.resident;
  late final int _feedIndex = 0; // HomeFeedScreen (mixed feed)
  late final int _announcementsIndex = 1; // AnnouncementsScreen
  late final int _marketIndex = 2; // MarketplaceScreen
  late final int _tasksIndex = 3; // TasksScreen
  late final int _profileIndex = 4; // MenuScreen

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  late final List<Widget> _screens = [
    HomeFeedScreen(
      onUnreadAnnouncementsChanged: (hasUnread) {
        if (_hasUnreadAnnouncements != hasUnread) {
          setState(() {
            _hasUnreadAnnouncements = hasUnread;
          });
        }
      },
    ), // Index 0: Home (mixed feed: announcements, errands, products)
    AnnouncementsScreen(key: _announcementsKey), // Index 1: Announcements
    MarketplaceScreen(key: _marketplaceKey), // Index 2: Marketplace
    TasksScreen(key: _tasksKey), // Index 3: Errand/Job Post
    MenuScreen(userRole: widget.userRole), // Index 4: Menu/Profile
  ];

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
        // Update nav destination based on index
        if (index == _feedIndex) {
          _currentNavDestination = NavDestination.home;
        } else if (index == _announcementsIndex) {
          _currentNavDestination = NavDestination.announcements;
        } else if (index == _marketIndex) {
          _currentNavDestination = NavDestination.marketplace;
        } else if (index == _tasksIndex) {
          _currentNavDestination = NavDestination.errandJobPost;
        } else if (index == _profileIndex) {
          _currentNavDestination = NavDestination.menu;
        }
      });
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleNavDestinationChange(NavDestination destination) {
    int targetIndex;
    switch (destination) {
      case NavDestination.home:
        targetIndex = _feedIndex;
        break;
      case NavDestination.marketplace:
        targetIndex = _marketIndex;
        break;
      case NavDestination.errandJobPost:
        targetIndex = _tasksIndex;
        break;
      case NavDestination.announcements:
        targetIndex = _announcementsIndex;
        break;
        case NavDestination.menu:
          targetIndex = _profileIndex;
          break;
    }
    
    if (_currentIndex != targetIndex) {
      setState(() {
        _currentNavDestination = destination;
        _currentIndex = targetIndex;
      });
      _pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _openCreatePost() async {
    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CreatePostScreen(userRole: widget.userRole),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curvedAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
      ),
    );

    if (result != null) {
      // Handle result and navigate to appropriate feed
      if (result is PostModel) {
        // Add post to announcements and switch to Feed tab
        if (_announcementsKey.currentState != null) {
          _announcementsKey.currentState!.addPost(result);
        }
        setState(() {
          _currentIndex = _feedIndex;
          _currentNavDestination = NavDestination.home;
        });
        _pageController.animateToPage(
          _feedIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else if (result is ProductModel) {
        // Add product to marketplace and switch to Market tab
        if (_marketplaceKey.currentState != null) {
          _marketplaceKey.currentState!.addProduct(result);
        }
        setState(() {
          _currentIndex = _marketIndex;
          _currentNavDestination = NavDestination.marketplace;
        });
        _pageController.animateToPage(
          _marketIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else if (result is TaskModel) {
        // Add task to tasks screen and switch to Tasks tab
        if (_tasksKey.currentState != null) {
          _tasksKey.currentState!.addTask(result);
        }
        setState(() {
          _currentIndex = _tasksIndex;
          _currentNavDestination = NavDestination.errandJobPost;
        });
        _pageController.animateToPage(
          _tasksIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Stream<int> _getErrandNotificationCountStream() {
    final uid = FirestoreService.currentUserId;
    if (uid == null) return Stream<int>.value(0);
    return TasksService.getRequesterTasksStream(uid).asyncMap((tasks) async {
      try {
        int total = 0;
        for (final t in tasks) {
          final list = await TasksService.getVolunteersStream(t.id).first;
          total += list.where((v) => (v['status'] as String? ?? 'pending') == 'pending').length;
        }
        return total;
      } catch (_) {
        return 0;
      }
    });
  }

  Stream<int> _getPostCommentsNotificationCountStream() {
    final uid = FirestoreService.currentUserId;
    if (uid == null) return Stream<int>.value(0);
    return PostsService.getTotalUnreadCommentsOnMyPostsStream(uid);
  }

  Stream<int> _getMarketplaceNotificationCountStream() {
    final uid = FirestoreService.currentUserId;
    if (uid == null) return Stream<int>.value(0);
    return ProductsService.getTotalUnreadProductMessagesForSellerStream(uid);
  }

  Stream<int> _getTaskChatUnreadCountStream() {
    final uid = FirestoreService.currentUserId;
    if (uid == null) return Stream<int>.value(0);
    return TaskChatService.getTotalUnreadForUserStream(uid);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirestoreService.currentUserId;
    if (_cachedErrandUid != uid) {
      _cachedErrandUid = uid;
      _cachedErrandStream = _getErrandNotificationCountStream();
    }
    final errandStream = _cachedErrandStream ?? Stream<int>.value(0);

    if (_cachedTaskChatUid != uid) {
      _cachedTaskChatUid = uid;
      _cachedTaskChatStream = _getTaskChatUnreadCountStream();
    }
    final taskChatStream = _cachedTaskChatStream ?? Stream<int>.value(0);

    if (_cachedPostCommentsUid != uid) {
      _cachedPostCommentsUid = uid;
      _cachedPostCommentsStream = _getPostCommentsNotificationCountStream();
    }
    final postCommentsStream = _cachedPostCommentsStream ?? Stream<int>.value(0);

    if (_cachedMarketplaceUid != uid) {
      _cachedMarketplaceUid = uid;
      _cachedMarketplaceStream = _getMarketplaceNotificationCountStream();
    }
    final marketplaceStream = _cachedMarketplaceStream ?? Stream<int>.value(0);

    return Scaffold(
      body: Column(
        children: [
          StreamBuilder<int>(
            stream: errandStream,
            initialData: 0,
            builder: (context, errandSnap) {
              final errandCount = errandSnap.data ?? 0;
              return StreamBuilder<int>(
                stream: taskChatStream,
                initialData: 0,
                builder: (context, taskChatSnap) {
                  final taskChatCount = taskChatSnap.data ?? 0;
                  return StreamBuilder<int>(
                    stream: postCommentsStream,
                    initialData: 0,
                    builder: (context, postSnap) {
                      final postCommentsCount = postSnap.data ?? 0;
                      return StreamBuilder<int>(
                        stream: marketplaceStream,
                        initialData: 0,
                        builder: (context, marketplaceSnap) {
                          final marketplaceCount = marketplaceSnap.data ?? 0;
                          return LinkodNavbar(
                            currentDestination: _currentNavDestination,
                            onDestinationChanged: _handleNavDestinationChange,
                            hasUnreadAnnouncements: _hasUnreadAnnouncements,
                            errandNotificationCount: errandCount + taskChatCount,
                            postCommentsNotificationCount: postCommentsCount,
                            marketplaceNotificationCount: marketplaceCount,
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          // Content area with swipe support
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  // Update nav destination based on index
                  if (index == _feedIndex) {
                    _currentNavDestination = NavDestination.home;
                  } else if (index == _announcementsIndex) {
                    _currentNavDestination = NavDestination.announcements;
                  } else if (index == _marketIndex) {
                    _currentNavDestination = NavDestination.marketplace;
                  } else if (index == _tasksIndex) {
                    _currentNavDestination = NavDestination.errandJobPost;
                  } else if (index == _profileIndex) {
                    _currentNavDestination = NavDestination.menu;
                  }
                });
              },
              children: _screens,
            ),
          ),
        ],
      ),
      floatingActionButton: widget.userRole == UserRole.official
          ? FloatingActionButton(
              heroTag: 'create_fab',
              onPressed: _openCreatePost,
              backgroundColor: kFacebookBlue,
              foregroundColor: Colors.white,
              elevation: 4,
              tooltip: 'Create Announcement',
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
