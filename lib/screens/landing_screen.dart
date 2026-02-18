// landing_screen.dart
// Landing screen widget that matches the provided screenshot design.
// Uses logo image from assets/images/linkod_logo.png

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'create_account_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'declined_status_screen.dart';
import 'suspended_status_screen.dart';
import '../models/user_role.dart';


class LandingScreen extends StatefulWidget {
  const LandingScreen({Key? key}) : super(key: key);

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // User is already logged in, check if approved and navigate to home
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          final accountStatus = (data?['accountStatus'] as String?)?.toLowerCase();
          final isApproved = data?['isApproved'] as bool? ?? false;

          if (accountStatus == 'declined' && mounted) {
            final adminNote = (data?['adminNote'] as String?) ?? '';
            final reapplyType = (data?['reapplyType'] as String?) ?? 'full';
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => DeclinedStatusScreen(
                  adminNote: adminNote,
                  reapplyType: reapplyType,
                ),
              ),
            );
            return;
          }
          if (accountStatus == 'suspended' && mounted) {
            final adminNote = data?['adminNote'] as String?;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => SuspendedStatusScreen(adminNote: adminNote),
              ),
            );
            return;
          }
          if (isApproved || accountStatus == 'active') {
            UserRole role = UserRole.resident;
            final roleString = (data?['role'] as String?) ?? 'resident';
            final lower = roleString.toLowerCase();
            if (lower == 'official' || lower == 'admin') {
              role = UserRole.official;
            } else if (lower == 'vendor') {
              role = UserRole.vendor;
            } else {
              role = UserRole.resident;
            }

            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => HomeScreen(userRole: role),
                ),
              );
              return;
            }
          }
        }
      } catch (e) {
        // If there's an error checking user, continue to show landing screen
        debugPrint('Error checking auth state: $e');
      }
    }
    
    if (mounted) {
      setState(() {
        _isCheckingAuth = false;
      });
    }
  }

  // Primary design color from the screenshot
  static const Color kGreen = Color(0xFF20BF6B);
  static const Color kWhite = Colors.white;

  // Responsive scaling helper - scales based on screen height
  // Base design assumes ~800px height phone
  double _scale(BuildContext context, double size) {
    final height = MediaQuery.of(context).size.height;
    return size * (height / 800.0);
  }

  @override
  Widget build(BuildContext context) {
    // Show splash screen with logo while checking auth state
    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: kGreen,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo image
                Semantics(
                  label: 'Linkod logo image',
                  child: Image.asset(
                    'assets/images/linkod_logo.png',
                    width: _scale(context, 182),
                    height: _scale(context, 143),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: _scale(context, 182),
                        height: _scale(context, 143),
                        decoration: BoxDecoration(
                          color: kWhite.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.image,
                          color: kWhite.withOpacity(0.5),
                          size: _scale(context, 182) * 0.5,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(kWhite),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;

    // Scaled font sizes
    final welcomeFontSize = _scale(context, 17); // ~16-18px range
    final buttonFontSize = _scale(context, 16);
    final signInFontSize = _scale(context, 12.5); // ~12-13px range

    // Logo dimensions - new logo is 182x143, scales responsively
    final logoWidth = _scale(context, 182);
    final logoHeight = _scale(context, 143);

    // Button dimensions
    final buttonHeight = _scale(context, 48);
    final buttonWidth = width * 0.7; // 70% of screen width
    final buttonRadius = 30.0; // Pill radius

    // Spacing constants (scaled)
    final spacingAfterWelcome = _scale(context, 18);
    final spacingAfterButton = _scale(context, 26);
    final bottomPadding = _scale(context, 36);

    return Scaffold(
      backgroundColor: kGreen,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.15),

              // "Welcome to" text
              Semantics(
                label: 'Welcome label',
                child: Text(
                  'Welcome to',
                  style: TextStyle(
                    color: kWhite,
                    fontSize: welcomeFontSize,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              SizedBox(height: spacingAfterWelcome),

              // Logo image
              Semantics(
                label: 'Linkod logo image',
                child: Image.asset(
                  'assets/images/linkod_logo.png',
                  width: logoWidth,
                  height: logoHeight,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if image not found - shows placeholder
                    return Container(
                      width: logoWidth,
                      height: logoHeight,
                      decoration: BoxDecoration(
                        color: kWhite.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.image,
                        color: kWhite.withOpacity(0.5),
                        size: logoWidth * 0.5,
                      ),
                    );
                  },
                ),
              ),

              // Large spacer to push button section lower (20% of screen height)
              SizedBox(height: MediaQuery.of(context).size.height * 0.25),

              // Get Started button (white pill) - goes to Login screen
              SizedBox(
                width: buttonWidth,
                height: buttonHeight,
                child: Semantics(
                  label: 'Get Started button',
                  button: true,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateAccountScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kWhite,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(buttonRadius),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      'Get Started',
                      style: TextStyle(
                        color: kGreen,
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: spacingAfterButton),

              // "Already have an account? Sign in" text
              Semantics(
                label: 'Sign in link',
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(
                        color: kWhite,
                        fontSize: signInFontSize,
                        fontWeight: FontWeight.w400,
                      ),
                      children: [
                        TextSpan(
                          text: 'Sign in',
                          style: TextStyle(
                            color: kWhite,
                            fontSize: signInFontSize,
                            fontWeight: FontWeight.w400,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: bottomPadding),
            ],
          ),
        ),
      ),
    );
  }
}
