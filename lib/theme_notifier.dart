import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier._() : super(ThemeMode.light);

  static final ThemeNotifier instance = ThemeNotifier._();
  static const String _themePreferenceKey = 'theme_mode_preference';

  /// Load theme preference from SharedPreferences.
  /// Returns the saved theme or ThemeMode.light if not saved.
  Future<ThemeMode> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themePreferenceKey);
      if (savedTheme == 'dark') {
        value = ThemeMode.dark;
        return ThemeMode.dark;
      } else if (savedTheme == 'system') {
        value = ThemeMode.system;
        return ThemeMode.system;
      }
    } catch (e) {
      // If loading fails, use default
      debugPrint('Error loading theme preference: $e');
    }
    value = ThemeMode.light;
    return ThemeMode.light;
  }

  /// Save theme preference to SharedPreferences and update value.
  Future<void> toggleTheme(bool isDark) async {
    final newTheme = isDark ? ThemeMode.dark : ThemeMode.light;
    value = newTheme;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _themePreferenceKey,
        isDark ? 'dark' : 'light',
      );
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }
}
