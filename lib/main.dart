import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/landing_screen.dart';
import 'ui_constants.dart';
import 'firebase_options.dart';
import 'services/fcm_token_service.dart';
import 'services/push_notification_handler.dart';
import 'services/auto_approval_service.dart';
import 'theme_notifier.dart';

/// Top-level handler for FCM messages when app is in background or terminated.
/// Must be a top-level or static function so the isolate can call it.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // No UI here; tap is handled via getInitialMessage / onMessageOpenedApp.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final navigatorKey = GlobalKey<NavigatorState>();
  final pushHandler = PushNotificationHandler(navigatorKey);
  await pushHandler.setup();

  FcmTokenService.instance.start();

  // Request notification permission on first app run
  await FcmTokenService.instance.requestPermissionOnFirstRun();

  // Run auto-approval sweeper once per session so that marketplace
  // products and errands are auto-approved based on the
  // adminSettings/approvals flags even if the admin Approvals screen
  // is never opened.
  await AutoApprovalService.runOnceOnStartup();

  runApp(LinkodApp(navigatorKey: navigatorKey));

  WidgetsBinding.instance.addPostFrameCallback((_) {
    PushNotificationHandler.handleInitialMessage(navigatorKey);
  });
}

class LinkodApp extends StatelessWidget {
  const LinkodApp({super.key, this.navigatorKey});

  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.instance,
      builder: (context, themeMode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'LINKod',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: kFacebookBlue,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black87),
              titleTextStyle: TextStyle(
                color: kFacebookBlue,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 1,
              margin: const EdgeInsets.symmetric(
                horizontal: kPaddingSmall,
                vertical: kPaddingSmall / 2,
              ),
              shape: kCardShape,
              shadowColor: Colors.black12,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: kFacebookBlue,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: kFacebookBlue,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF1E1E1E),
              elevation: 1,
              margin: const EdgeInsets.symmetric(
                horizontal: kPaddingSmall,
                vertical: kPaddingSmall / 2,
              ),
              shape: kCardShape,
              shadowColor: Colors.black45,
            ),
          ),
          home: const LandingScreen(),
        );
      },
    );
  }
}
