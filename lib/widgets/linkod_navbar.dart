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

  const LinkodNavbar({
    super.key,
    required this.currentDestination,
    this.onDestinationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
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
      child: Row(
        children: [
          // LEFT: LINKod logo text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'LINKod',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF20BF6B),
                letterSpacing: 0.5,
              ),
            ),
          ),
          
          // CENTER: Icon menu
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavIcon(
                  icon: Icons.home,
                  isActive: currentDestination == NavDestination.home,
                  onTap: () => onDestinationChanged?.call(NavDestination.home),
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
                  icon: Icons.campaign,
                  isActive: currentDestination == NavDestination.announcements,
                  onTap: () => onDestinationChanged?.call(NavDestination.announcements),
                ),
                _NavIcon(
                  icon: Icons.menu,
                  isActive: currentDestination == NavDestination.menu,
                  onTap: () => onDestinationChanged?.call(NavDestination.menu),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.isActive,
    required this.onTap,
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
        child: Icon(
          icon,
          size: 24,
          color: isActive ? const Color(0xFF20BF6B) : Colors.grey.shade600,
        ),
      ),
    );
  }
}

