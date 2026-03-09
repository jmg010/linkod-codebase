import 'package:flutter/material.dart';
import '../screens/bulletin_board_screen.dart';

enum NavDestination {
  home,
  marketplace,
  errandJobPost,
  bulletin,
  announcements,
  menu,
}

class LinkodNavbar extends StatelessWidget {
  final NavDestination currentDestination;
  final ValueChanged<NavDestination>? onDestinationChanged;
  final bool hasUnreadAnnouncements;
  /// Number of notifications for owner's errand/task posts (e.g. pending volunteers, unread task chat).
  final int errandNotificationCount;
  /// Number of unread comments on owner's feed posts.
  final int postCommentsNotificationCount;
  /// Number of unread messages on owner's marketplace products.
  final int marketplaceNotificationCount;

  const LinkodNavbar({
    super.key,
    required this.currentDestination,
    this.onDestinationChanged,
    this.hasUnreadAnnouncements = false,
    this.errandNotificationCount = 0,
    this.postCommentsNotificationCount = 0,
    this.marketplaceNotificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // LINKod text at top-left and barangay logo placeholder at top-right - accounting for status bar
          Padding(
            padding: EdgeInsets.fromLTRB(20, statusBarHeight + 8, 20, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'LINKod',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF20BF6B),
                    letterSpacing: 0.8,
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BulletinBoardScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade200,
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      // Placeholder for future barangay logo image upload
                      child: Icon(
                        Icons.image_outlined,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Navigation icons row below LINKod
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavIcon(
                icon: Icons.home,
                label: 'Home',
                isActive: currentDestination == NavDestination.home,
                onTap: () => onDestinationChanged?.call(NavDestination.home),
              ),
              _NavIcon(
                icon: Icons.campaign,
                label: 'Announcement',
                isActive: currentDestination == NavDestination.announcements,
                onTap: () => onDestinationChanged?.call(NavDestination.announcements),
                showAlert: hasUnreadAnnouncements && postCommentsNotificationCount == 0,
                notificationCount: postCommentsNotificationCount,
              ),
              _NavIcon(
                icon: Icons.storefront,
                label: 'Marketplace',
                isActive: currentDestination == NavDestination.marketplace,
                onTap: () => onDestinationChanged?.call(NavDestination.marketplace),
                notificationCount: marketplaceNotificationCount,
              ),
              _NavIcon(
                icon: Icons.handshake,
                label: 'Errands',
                isActive: currentDestination == NavDestination.errandJobPost,
                onTap: () => onDestinationChanged?.call(NavDestination.errandJobPost),
                notificationCount: errandNotificationCount,
              ),
              _NavIcon(
                icon: Icons.menu,
                label: 'Menu',
                isActive: currentDestination == NavDestination.menu,
                onTap: () => onDestinationChanged?.call(NavDestination.menu),
              ),
            ],
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool isActive;
  final VoidCallback onTap;
  final bool showAlert;
  final int notificationCount;

  const _NavIcon({
    required this.icon,
    this.label,
    required this.isActive,
    required this.onTap,
    this.showAlert = false,
    this.notificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final showCount = notificationCount > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF20BF6B) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 26,
                  color: isActive ? const Color(0xFF20BF6B) : Colors.grey.shade600,
                ),
                if (showAlert && !showCount)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '!',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (showCount)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.all(Radius.circular(9)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        notificationCount > 99 ? '99+' : '$notificationCount',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (label != null) ...[
              const SizedBox(height: 2),
              Text(
                label!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? const Color(0xFF20BF6B) : Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

