import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/purok.dart';
import '../models/user_role.dart';
import '../services/fcm_token_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../widgets/optimized_image.dart';
import '../theme_notifier.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'report_problem_screen.dart';

class MenuScreen extends StatefulWidget {
  final UserRole userRole;

  const MenuScreen({super.key, required this.userRole});

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
  List<String> _demographicCategories = [];
  String? _location;

  @override
  void initState() {
    super.initState();
    _darkModeEnabled = ThemeNotifier.instance.value == ThemeMode.dark;
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
      final userDoc =
          await FirestoreService.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          _userName =
              data?['fullName'] as String? ?? _getUserName(widget.userRole);
          _phoneNumber =
              data?['phoneNumber'] as String? ??
              _getPhoneNumber(widget.userRole);
          _profileImageUrl = data?['profileImageUrl'] as String?;
          _purok = (data?['purok'] as num?)?.toInt();
          _location = data?['location'] as String?;
          // Load demographic categories
          final categories = data?['categories'];
          debugPrint('Raw categories: $categories');
          if (categories is List) {
            _demographicCategories = categories
                .map((e) => e?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .toList();
            debugPrint('Processed _demographicCategories: $_demographicCategories');
          } else {
            _demographicCategories = [];
          }
          _isLoadingUser = false;
        });
      } else {
        setState(() {
          _userName = _getUserName(widget.userRole);
          _phoneNumber = _getPhoneNumber(widget.userRole);
          _purok = null;
          _demographicCategories = [];
          _location = null;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      setState(() {
        _userName = _getUserName(widget.userRole);
        _phoneNumber = _getPhoneNumber(widget.userRole);
        _purok = null;
        _demographicCategories = [];
        _location = null;
        _isLoadingUser = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with white background - same structure as announcements_screen
          Container(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
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
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                      // Profile Avatar - tap to change photo for all users
                      GestureDetector(
                        onTap: () {
                          if (_profileImageUrl != null &&
                              _profileImageUrl!.isNotEmpty) {
                            _showPhotoOptionsSheet();
                          } else {
                            _showChangePhotoSheet();
                          }
                        },
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFF20BF6B),
                              backgroundImage:
                                  _profileImageUrl != null &&
                                          _profileImageUrl!.isNotEmpty
                                      ? NetworkImage(_profileImageUrl!)
                                      : null,
                              child:
                                  _profileImageUrl == null ||
                                          _profileImageUrl!.isEmpty
                                      ? Text(
                                        (_userName?.isNotEmpty ?? false)
                                            ? _userName![0].toUpperCase()
                                            : widget.userRole.displayName[0],
                                        style: const TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                      : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF20BF6B),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // User Name (from Firestore or fallback to role-based)
                      Text(
                        _isLoadingUser
                            ? 'Loading...'
                            : (_userName ?? _getUserName(widget.userRole)),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Purok and Demographic Categories
                      if (!_isLoadingUser &&
                          (_purok != null || _demographicCategories.isNotEmpty))
                        Text(
                          _buildPurokAndCategories(),
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                          ),
                        ),
                      // Location
                      if (!_isLoadingUser && _location != null && _location!.isNotEmpty)
                        Text(
                          _location!,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Phone Number (from Firestore or fallback to role-based)
                      Text(
                        _isLoadingUser
                            ? ''
                            : (_phoneNumber ??
                                _getPhoneNumber(widget.userRole)),
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Menu Items Container - flat list matching Figma design
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                        color:
                            isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
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
                          ThemeNotifier.instance.toggleTheme(value);
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color:
                            isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                        indent: 20,
                        endIndent: 20,
                      ),
                      _MenuItem(
                        icon: Icons.logout,
                        title: 'Logout',
                        onTap: () async {
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid != null) {
                            await FcmTokenService.instance.removeTokenOnLogout(
                              uid,
                            );
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
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
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
                        color:
                            isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                        indent: 20,
                        endIndent: 20,
                      ),
                      _MenuItem(
                        icon: Icons.support_agent_outlined,
                        title: 'Report a Problem',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ReportProblemScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color:
                            isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                        indent: 20,
                        endIndent: 20,
                      ),
                      _MenuItem(
                        icon: Icons.info_outline,
                        title: 'About',
                        onTap: () {
                          _showAboutDialog(context);
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

  void _showPhotoOptionsSheet() {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.fullscreen),
                  title: const Text('View Full Size'),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (_profileImageUrl != null &&
                        _profileImageUrl!.isNotEmpty) {
                      openFullScreenImage(context, _profileImageUrl!);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Change Photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showChangePhotoSheet();
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showChangePhotoSheet() {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickProfileImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _takeProfilePhoto();
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (xFile != null && mounted) await _uploadAndSaveProfilePhoto(xFile);
  }

  Future<void> _takeProfilePhoto() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (xFile != null && mounted) await _uploadAndSaveProfilePhoto(xFile);
  }

  Future<void> _uploadAndSaveProfilePhoto(XFile xFile) async {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) return;
    try {
      final url = await StorageService.instance.uploadImageFromXFile(
        xFile,
        StorageService.profilePath(currentUser.uid),
      );
      if (url == null || !mounted) return;
      await FirestoreService.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({'profileImageUrl': url});
      if (mounted) {
        await _loadUserProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF161616) : Colors.white;
    final textColor = isDark ? Colors.grey.shade300 : Colors.black87;
    final titleColor = isDark ? Colors.white : Colors.black;
    final dividerColor =
        isDark ? const Color(0xFF2C3E32) : Colors.grey.shade300;
    final primaryColor = const Color(0xFF20BF6B);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
            ),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 800),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/linkod_logo.png',
                        width: 50,
                        height: 50,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LINKod',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                          ),
                          Text(
                            'Community Connection Platform',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          'About LINKod',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: textColor,
                            ),
                            children: [
                              const TextSpan(text: 'LINKod is a '),
                              TextSpan(
                                text: 'digital community',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(
                                text:
                                    ' platform designed to strengthen communication and service delivery between barangay officials and residents. The platform provides a centralized space where users can access ',
                              ),
                              TextSpan(
                                text: 'announcements',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(
                                text:
                                    ', community services, and local opportunities.\n\nBy using LINKod, residents can stay informed, participate in community activities, and easily connect with their local barangay through modern digital tools.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Divider(color: dividerColor),
                        const SizedBox(height: 16),
                        Text(
                          'Key Features',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(
                          'Announcements',
                          'Receive important updates and notices from barangay officials.',
                          primaryColor,
                          textColor,
                          isDark,
                        ),
                        _buildFeatureItem(
                          'Marketplace',
                          'Buy, sell, or promote items within the community.',
                          primaryColor,
                          textColor,
                          isDark,
                        ),
                        _buildFeatureItem(
                          'Errands',
                          'Request or offer help for small community tasks.',
                          primaryColor,
                          textColor,
                          isDark,
                        ),
                        _buildFeatureItem(
                          'Bulletin Board',
                          'View community postings, events, and public information.',
                          primaryColor,
                          textColor,
                          isDark,
                        ),
                        const SizedBox(height: 16),
                        Divider(color: dividerColor),
                        const SizedBox(height: 16),
                        Text(
                          'Our Mission',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Our mission is to improve local community engagement by providing an accessible, reliable, and user-friendly platform that connects residents with their barangay services.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Divider(color: dividerColor),
                        const SizedBox(height: 16),
                        Text(
                          'Application Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(
                                Icons.link,
                                'Application Name:',
                                'LINKod',
                                primaryColor,
                                textColor,
                                isDark,
                              ),
                            ),
                            Expanded(
                              child: _buildInfoItem(
                                Icons.verified_user_outlined,
                                'Version: 1.0.0',
                                'Mobile and Desktop',
                                primaryColor,
                                textColor,
                                isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(
                                Icons.phone_android,
                                'Platform:',
                                'Mobile and Desktop',
                                primaryColor,
                                textColor,
                                isDark,
                              ),
                            ),
                            Expanded(
                              child: _buildInfoItem(
                                Icons.code,
                                'Developer:',
                                'LINKod Development Team',
                                primaryColor,
                                textColor,
                                isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(color: dividerColor),
                        const SizedBox(height: 16),
                        Text(
                          'Support',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: textColor,
                            ),
                            children: [
                              const TextSpan(
                                text:
                                    'If you encounter issues or have suggestions, please use the ',
                              ),
                              TextSpan(
                                text: 'Help & Support',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(
                                text: ' section within the application.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(
    String title,
    String description,
    Color primaryColor,
    Color textColor,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, color: primaryColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$title - ',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: description,
                    style: TextStyle(color: textColor, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    IconData icon,
    String title,
    String subtitle,
    Color primaryColor,
    Color textColor,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: primaryColor, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: textColor, fontSize: 12)),
            ],
          ),
        ),
      ],
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

  String _buildPurokAndCategories() {
    final parts = <String>[];
    
    // Add purok if available
    if (_purok != null) {
      parts.add(purokDisplayName(_purok!));
    }
    
    // Add demographic categories if available
    if (_demographicCategories.isNotEmpty) {
      parts.add(_demographicCategories.join(', '));
    }
    
    // Join with bullet separator
    return parts.join(' • ');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              child: Icon(icon, size: 20, color: const Color(0xFF20BF6B)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            child: Icon(icon, size: 20, color: const Color(0xFF20BF6B)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
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
