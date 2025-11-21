import 'package:flutter/material.dart';
import '../ui_constants.dart';
import '../models/user_role.dart';
import '../models/post_model.dart';
import '../models/product_model.dart';
import '../models/task_model.dart';
import '../widgets/linkod_navbar.dart';
import 'home_feed_screen.dart';
import 'announcements_screen.dart';
import 'marketplace_screen.dart';
import 'tasks_screen.dart';
import 'profile_screen.dart';
import 'create_post_screen.dart';
import 'chatbot_screen.dart';

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
  final GlobalKey<AnnouncementsScreenState> _announcementsKey =
      GlobalKey<AnnouncementsScreenState>();
  final GlobalKey<MarketplaceScreenState> _marketplaceKey =
      GlobalKey<MarketplaceScreenState>();
  final GlobalKey<TasksScreenState> _tasksKey = GlobalKey<TasksScreenState>();
  late final bool _isResident = widget.userRole == UserRole.resident;
  late final int _feedIndex = 0; // HomeFeedScreen (mixed feed)
  late final int _announcementsIndex = 1; // AnnouncementsScreen
  late final int _marketIndex = 2; // MarketplaceScreen
  late final int _tasksIndex = 3; // TasksScreen

  late final List<Widget> _screens = [
    const HomeFeedScreen(), // Mixed feed: announcements, errands, products
    AnnouncementsScreen(key: _announcementsKey),
    MarketplaceScreen(key: _marketplaceKey),
    TasksScreen(key: _tasksKey),
    if (_isResident) const ChatbotScreen(),
    ProfileScreen(userRole: widget.userRole),
  ];

  void _onTabTapped(int index) {
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
      } else if (index == (_isResident ? 5 : 4)) {
        _currentNavDestination = NavDestination.menu;
      }
    });
  }

  void _handleNavDestinationChange(NavDestination destination) {
    setState(() {
      _currentNavDestination = destination;
      switch (destination) {
        case NavDestination.home:
          _currentIndex = _feedIndex;
          break;
        case NavDestination.announcements:
          _currentIndex = _announcementsIndex;
          break;
        case NavDestination.marketplace:
          _currentIndex = _marketIndex;
          break;
        case NavDestination.errandJobPost:
          _currentIndex = _tasksIndex;
          break;
        case NavDestination.menu:
          _currentIndex = _isResident ? 5 : 4;
          break;
      }
    });
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
        });
      } else if (result is ProductModel) {
        // Add product to marketplace and switch to Market tab
        if (_marketplaceKey.currentState != null) {
          _marketplaceKey.currentState!.addProduct(result);
        }
        setState(() {
          _currentIndex = _marketIndex;
        });
      } else if (result is TaskModel) {
        // Add task to tasks screen and switch to Tasks tab
        if (_tasksKey.currentState != null) {
          _tasksKey.currentState!.addTask(result);
        }
        setState(() {
          _currentIndex = _tasksIndex;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // New green navbar at the top
          LinkodNavbar(
            currentDestination: _currentNavDestination,
            onDestinationChanged: _handleNavDestinationChange,
          ),
          // Content area
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      floatingActionButton: widget.userRole == UserRole.resident
          ? FloatingActionButton(
              heroTag: 'chatbot',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                );
              },
              backgroundColor: kFacebookBlue,
              foregroundColor: Colors.white,
              elevation: 4,
              tooltip: 'Chat with Barangay Assistant',
              child: const Icon(Icons.chat_bubble_outline),
            )
          : widget.userRole == UserRole.official
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
