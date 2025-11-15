import 'package:flutter/material.dart';
import '../ui_constants.dart';
import '../models/user_role.dart';
import '../models/post_model.dart';
import '../models/product_model.dart';
import '../models/task_model.dart';
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
  final GlobalKey<AnnouncementsScreenState> _announcementsKey =
      GlobalKey<AnnouncementsScreenState>();
  final GlobalKey<MarketplaceScreenState> _marketplaceKey =
      GlobalKey<MarketplaceScreenState>();
  final GlobalKey<TasksScreenState> _tasksKey = GlobalKey<TasksScreenState>();
  late final bool _isResident = widget.userRole == UserRole.resident;
  late final int _feedIndex = 0;
  late final int _marketIndex = 1;
  late final int _tasksIndex = 2;

  late final List<Widget> _screens = [
    AnnouncementsScreen(key: _announcementsKey),
    MarketplaceScreen(key: _marketplaceKey),
    TasksScreen(key: _tasksKey),
    if (_isResident) const ChatbotScreen(),
    ProfileScreen(userRole: widget.userRole),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
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
      appBar: AppBar(
        titleSpacing: 16,
        elevation: 2,
        shadowColor: Colors.black12,
        title: Text(
          'LINKod',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: kFacebookBlue,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_box_outlined, color: Colors.grey.shade800),
            tooltip: 'Create',
            onPressed: _openCreatePost,
          ),
          IconButton(
            icon: Icon(Icons.search_outlined, color: Colors.grey.shade800),
            tooltip: 'Search',
            onPressed: () => _showSnack('Search is coming soon.'),
          ),
          IconButton(
            icon: Icon(Icons.message_outlined, color: Colors.grey.shade800),
            tooltip: 'Messenger',
            onPressed: () => _showSnack('Messenger is coming soon.'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _TopNavBar(
            currentIndex: _currentIndex,
            isResident: _isResident,
            onSelect: (TopNavDestination destination) {
              switch (destination) {
                case TopNavDestination.announcements:
                  _onTabTapped(_feedIndex);
                  break;
                case TopNavDestination.marketplace:
                  _onTabTapped(_marketIndex);
                  break;
                case TopNavDestination.tasks:
                  _onTabTapped(_tasksIndex);
                  break;
                case TopNavDestination.officials:
                  if (widget.userRole == UserRole.official) {
                    _openCreatePost();
                  } else {
                    _showSnack('Officials module is only available for barangay staff.');
                  }
                  break;
                case TopNavDestination.profile:
                  _onTabTapped(_isResident ? 4 : 3);
                  break;
              }
            },
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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

enum TopNavDestination { announcements, marketplace, tasks, officials, profile }

class _TopNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isResident;
  final ValueChanged<TopNavDestination> onSelect;

  const _TopNavBar({
    required this.currentIndex,
    required this.isResident,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_TopNavItem>[
      const _TopNavItem(
        destination: TopNavDestination.announcements,
        icon: Icons.home_filled,
        label: 'Home',
      ),
      const _TopNavItem(
        destination: TopNavDestination.marketplace,
        icon: Icons.storefront_outlined,
        label: 'Market',
      ),
      const _TopNavItem(
        destination: TopNavDestination.tasks,
        icon: Icons.handshake_outlined,
        label: 'Community',
      ),
      const _TopNavItem(
        destination: TopNavDestination.officials,
        icon: Icons.account_balance_outlined,
        label: 'Officials',
      ),
      const _TopNavItem(
        destination: TopNavDestination.profile,
        icon: Icons.person_outline,
        label: 'Profile',
      ),
    ];

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0), width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final item in items)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelect(item.destination),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      size: 22,
                      color: _isDestinationActive(item.destination)
                          ? kFacebookBlue
                          : Colors.grey.shade700,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _isDestinationActive(item.destination)
                                ? kFacebookBlue
                                : Colors.grey.shade700,
                          ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isDestinationActive(TopNavDestination destination) {
    switch (destination) {
      case TopNavDestination.announcements:
        return currentIndex == 0;
      case TopNavDestination.marketplace:
        return currentIndex == 1;
      case TopNavDestination.tasks:
        return currentIndex == 2;
      case TopNavDestination.officials:
        return false;
      case TopNavDestination.profile:
        return currentIndex == (isResident ? 4 : 3);
    }
  }
}

class _TopNavItem {
  final TopNavDestination destination;
  final IconData icon;
  final String label;

  const _TopNavItem({
    required this.destination,
    required this.icon,
    required this.label,
  });
}
