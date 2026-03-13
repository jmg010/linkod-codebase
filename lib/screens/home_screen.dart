import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  const HomeScreen({super.key, required this.userRole});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  NavDestination _currentNavDestination = NavDestination.home;
  late PageController _pageController;
  int? _ignoreOnPageChangedUntilIndex;
  final GlobalKey<AnnouncementsScreenState> _announcementsKey =
      GlobalKey<AnnouncementsScreenState>();
  final GlobalKey<MarketplaceScreenState> _marketplaceKey =
      GlobalKey<MarketplaceScreenState>();
  final GlobalKey<TasksScreenState> _tasksKey = GlobalKey<TasksScreenState>();
  final GlobalKey<HomeFeedScreenState> _homeFeedKey =
      GlobalKey<HomeFeedScreenState>();
  bool _hasUnreadAnnouncements = false;
  String? _cachedErrandUid;
  Stream<int>? _cachedErrandStream;
  String? _cachedTaskChatUid;
  Stream<int>? _cachedTaskChatStream;
  String? _cachedPostCommentsUid;
  Stream<int>? _cachedPostCommentsStream;
  String? _cachedMarketplaceUid;
  Stream<int>? _cachedMarketplaceStream;
  String? _barangayLogoUrl;
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
    _loadBranding();
  }

  Future<void> _loadBranding() async {
    // First, load from local cache for immediate display
    final prefs = await SharedPreferences.getInstance();
    final cachedLogoUrl = prefs.getString('barangayLogoUrl');
    
    if (cachedLogoUrl != null && cachedLogoUrl.isNotEmpty && mounted) {
      setState(() {
        _barangayLogoUrl = cachedLogoUrl;
      });
    }
    
    // Then fetch from Firestore in background to check for updates
    try {
      final doc = await FirebaseFirestore.instance
          .collection('barangaySettings')
          .doc('branding')
          .get();
      if (doc.exists && mounted) {
        final data = doc.data();
        final newLogoUrl = data?['barangayLogoUrl'] as String?;
        
        // Update cache and state if changed
        if (newLogoUrl != null && newLogoUrl != cachedLogoUrl) {
          await prefs.setString('barangayLogoUrl', newLogoUrl);
          setState(() {
            _barangayLogoUrl = newLogoUrl;
          });
        }
      }
    } catch (e) {
      // Silently fail - cached logo will be shown if available
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  late final List<Widget> _screens = [
    HomeFeedScreen(
      key: _homeFeedKey,
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
      _ignoreOnPageChangedUntilIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  NavDestination _destinationForIndex(int index) {
    if (index == _feedIndex) return NavDestination.home;
    if (index == _announcementsIndex) return NavDestination.announcements;
    if (index == _marketIndex) return NavDestination.marketplace;
    if (index == _tasksIndex) return NavDestination.errandJobPost;
    return NavDestination.menu;
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
      case NavDestination.bulletin:
        // Bulletin is accessed via the barangay logo button, not through main nav
        targetIndex = _feedIndex;
        break;
    }

    if (_currentIndex != targetIndex) {
      setState(() {
        _currentNavDestination = destination;
        _currentIndex = targetIndex;
      });
      _ignoreOnPageChangedUntilIndex = targetIndex;
      _pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // User tapped the already active tab -> Scroll to top / Refresh
      switch (destination) {
        case NavDestination.home:
          _homeFeedKey.currentState?.scrollToTop();
          break;
        case NavDestination.announcements:
          _announcementsKey.currentState?.scrollToTop();
          break;
        case NavDestination.marketplace:
          _marketplaceKey.currentState?.scrollToTop();
          break;
        case NavDestination.errandJobPost:
          _tasksKey.currentState?.scrollToTop();
          break;
        case NavDestination.menu:
          // Menu doesn't really have a scrollable timeline to top
          break;
        case NavDestination.bulletin:
          // Bulletin is not part of main nav tabs
          break;
      }
    }
  }

  Future<void> _openCreatePost() async {
    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                CreatePostScreen(userRole: widget.userRole),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
        _ignoreOnPageChangedUntilIndex = _feedIndex;
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
        _ignoreOnPageChangedUntilIndex = _marketIndex;
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
        _ignoreOnPageChangedUntilIndex = _tasksIndex;
        _pageController.animateToPage(
          _tasksIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Stream<int> _getErrandNotificationCountStream() {
    final uid = FirestoreService.currentUserId;
    if (uid == null) return Stream<int>.value(0);
    // Use combined stream for both requester tasks and interacted tasks
    return TasksService.getTotalPostActivityUnreadStream(uid);
  }

  Stream<int> _getPostCommentsNotificationCountStream() {
    final uid = FirestoreService.currentUserId;
    if (uid == null) return Stream<int>.value(0);
    return PostsService.getTotalUnreadCommentsOnMyPostsStream(uid);
  }

  Stream<int> _getMarketplaceNotificationCountStream() {
    final uid = FirestoreService.currentUserId;
    if (uid == null) return Stream<int>.value(0);
    // Use combined stream for both seller products and interacted posts
    return ProductsService.getTotalProductActivityUnreadStream(uid);
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
    final postCommentsStream =
        _cachedPostCommentsStream ?? Stream<int>.value(0);

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
                        errandNotificationCount: errandCount,
                        postCommentsNotificationCount: postCommentsCount,
                        marketplaceNotificationCount: marketplaceCount,
                        barangayLogoUrl: _barangayLogoUrl,
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
                // If the user tapped a destination far away (e.g. Menu -> Home),
                // PageView animates across intermediate pages and fires onPageChanged
                // for those pages. Ignore those intermediate indices so the navbar
                // doesn't appear to "force" Announcements as a stopover.
                final ignoreUntil = _ignoreOnPageChangedUntilIndex;
                if (ignoreUntil != null && index != ignoreUntil) {
                  return;
                }
                setState(() {
                  _currentIndex = index;
                  if (ignoreUntil != null && index == ignoreUntil) {
                    _ignoreOnPageChangedUntilIndex = null;
                  }
                  // Update nav destination based on index
                  _currentNavDestination = _destinationForIndex(index);
                });
              },
              children: _screens,
            ),
          ),
        ],
      ),
      floatingActionButton:
          widget.userRole == UserRole.official
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
