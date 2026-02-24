import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../services/fcm_token_service.dart';
import '../services/firestore_service.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';

class MenuScreen extends StatefulWidget {
  final UserRole userRole;

  const MenuScreen({
    super.key,
    required this.userRole,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _darkModeEnabled = false;
  String? _userName;
  String? _phoneNumber;
  String? _profileImageUrl;
  bool _isLoadingUser = true;
  int? _purok;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _userName = _getUserName(widget.userRole);
        _phoneNumber = _getPhoneNumber(widget.userRole);
        _isLoadingUser = false;
      });
      return;
    }

    try {
      final userDoc = await FirestoreService.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          _userName = data?['fullName'] as String? ?? _getUserName(widget.userRole);
          _phoneNumber = data?['phoneNumber'] as String? ?? _getPhoneNumber(widget.userRole);
          _profileImageUrl = data?['profileImageUrl'] as String?;
          _purok = (data?['purok'] as num?)?.toInt();
          _isLoadingUser = false;
        });
      } else {
        setState(() {
          _userName = _getUserName(widget.userRole);
          _phoneNumber = _getPhoneNumber(widget.userRole);
          _purok = null;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      setState(() {
        _userName = _getUserName(widget.userRole);
        _phoneNumber = _getPhoneNumber(widget.userRole);
        _purok = null;
        _isLoadingUser = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with white background - same structure as announcements_screen
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Scrollable content below title
          Expanded(
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                // Profile Header Card - simplified to match Figma design
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Profile Avatar
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF20BF6B),
                        backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                            ? NetworkImage(_profileImageUrl!)
                            : null,
                        child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                            ? Text(
                                (_userName?.isNotEmpty ?? false) ? _userName![0].toUpperCase() : widget.userRole.displayName[0],
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      // User Name (from Firestore or fallback to role-based)
                      Text(
                        _isLoadingUser ? 'Loading...' : (_userName ?? _getUserName(widget.userRole)),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Phone Number (from Firestore or fallback to role-based)
                      Text(
                        _isLoadingUser ? '' : (_phoneNumber ?? _getPhoneNumber(widget.userRole)),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (!_isLoadingUser && _purok != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Purok $_purok',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Menu Items Container - flat list matching Figma design
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _MenuItem(
                        icon: Icons.person_outline,
                        title: 'Edit Profile',
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(),
                            ),
                          );
                          _loadUserProfile();
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.grey.shade200,
                        indent: 20,
                        endIndent: 20,
                      ),
                      _DarkModeMenuItem(
                        icon: Icons.dark_mode_outlined,
                        title: 'Dark Mode',
                        value: _darkModeEnabled,
                        onChanged: (value) {
                          setState(() {
                            _darkModeEnabled = value;
                          });
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.grey.shade200,
                        indent: 20,
                        endIndent: 20,
                      ),
                      _MenuItem(
                        icon: Icons.logout,
                        title: 'Logout',
                        onTap: () async {
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid != null) {
                            await FcmTokenService.instance.removeTokenOnLogout(uid);
                          }
                          await FirebaseAuth.instance.signOut();
                          if (!context.mounted) return;
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Help & Support Section - kept as requested
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
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
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Text(
                          'Help & Support',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.help_outline,
                        title: 'Help Center',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Help Center coming soon!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.grey.shade200,
                        indent: 20,
                        endIndent: 20,
                      ),
                      _MenuItem(
                        icon: Icons.support_agent_outlined,
                        title: 'Report a Problem',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Report a Problem feature coming soon!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.grey.shade200,
                        indent: 20,
                        endIndent: 20,
                      ),
                      _MenuItem(
                        icon: Icons.info_outline,
                        title: 'About',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('About LINKod coming soon!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getUserName(UserRole role) {
    switch (role) {
      case UserRole.official:
        return 'Barangay Official';
      case UserRole.vendor:
        return 'Maria\'s Store';
      case UserRole.resident:
        return 'Juan Dela Cruz';
    }
  }

  String _getPhoneNumber(UserRole role) {
    switch (role) {
      case UserRole.official:
        return '09703985626';
      case UserRole.vendor:
        return '0978192739813';
      case UserRole.resident:
        return '09703985626';
    }
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF20BF6B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 20,
                color: const Color(0xFF20BF6B),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkModeMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DarkModeMenuItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF20BF6B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFF20BF6B),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF20BF6B),
          ),
        ],
      ),
    );
  }
}
