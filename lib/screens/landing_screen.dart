// landing_screen.dart
// Landing screen widget that matches the provided screenshot design.
// Uses logo image from assets/images/linkod_logo.png

import 'package:flutter/material.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({Key? key}) : super(key: key);

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
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;

    // Scaled font sizes
    final welcomeFontSize = _scale(context, 17); // ~16-18px range
    final buttonFontSize = _scale(context, 16);
    final signInFontSize = _scale(context, 12.5); // ~12-13px range

    // Logo dimensions - scales responsively (~140-180px base)
    final logoWidth = _scale(context, 160);

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
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if image not found - shows placeholder
                    return Container(
                      width: logoWidth,
                      height: logoWidth,
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

              // Get Started button (white pill)
              SizedBox(
                width: buttonWidth,
                height: buttonHeight,
                child: Semantics(
                  label: 'Get Started button',
                  button: true,
                  child: ElevatedButton(
                    onPressed: () {
                      debugPrint('Get Started pressed');
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
                    debugPrint('Sign in tapped');
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
