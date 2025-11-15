import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'ui_constants.dart';

void main() {
  runApp(const LinkodApp());
}

class LinkodApp extends StatelessWidget {
  const LinkodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LINKod',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kFacebookBlue),
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
          margin: const EdgeInsets.symmetric(horizontal: kPaddingSmall, vertical: kPaddingSmall / 2),
          shape: kCardShape,
          shadowColor: Colors.black12,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
