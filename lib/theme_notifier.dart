import 'package:flutter/material.dart';

class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier._() : super(ThemeMode.light);

  static final ThemeNotifier instance = ThemeNotifier._();

  void toggleTheme(bool isDark) {
    value = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}
