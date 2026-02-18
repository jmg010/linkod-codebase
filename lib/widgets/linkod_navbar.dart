import 'package:flutter/material.dart';

enum NavDestination {
  home,
  marketplace,
  errandJobPost,
  announcements,
  menu,
}

class LinkodNavbar extends StatelessWidget {
  final NavDestination currentDestination;
  final ValueChanged<NavDestination>? onDestinationChanged;
  final bool hasUnreadAnnouncements;

  const LinkodNavbar({
    super.key,
    required this.currentDestination,
    this.onDestinationChanged,
    this.hasUnreadAnnouncements = false,
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
          // LINKod text at top-left - accounting for status bar
          Padding(
            padding: EdgeInsets.fromLTRB(20, statusBarHeight + 8, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                'LINKod',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF20BF6B),
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          // Navigation icons row below LINKod
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavIcon(
                icon: Icons.home,
                isActive: currentDestination == NavDestination.home,
                onTap: () => onDestinationChanged?.call(NavDestination.home),
              ),
              _NavIcon(
                icon: Icons.campaign,
                isActive: currentDestination == NavDestination.announcements,
                onTap: () => onDestinationChanged?.call(NavDestination.announcements),
                showAlert: hasUnreadAnnouncements,
              ),
              _NavIcon(
                icon: Icons.storefront,
                isActive: currentDestination == NavDestination.marketplace,
                onTap: () => onDestinationChanged?.call(NavDestination.marketplace),
              ),
              _NavIcon(
                icon: Icons.handshake,
                isActive: currentDestination == NavDestination.errandJobPost,
                onTap: () => onDestinationChanged?.call(NavDestination.errandJobPost),
              ),
              _NavIcon(
                icon: Icons.menu,
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
  final bool isActive;
  final VoidCallback onTap;
  final bool showAlert;

  const _NavIcon({
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.showAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF20BF6B) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              icon,
              size: 28,
              color: isActive ? const Color(0xFF20BF6B) : Colors.grey.shade600,
            ),
            if (showAlert)
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
          ],
        ),
      ),
    );
  }
}

