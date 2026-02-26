import 'package:flutter/foundation.dart';

/// Tracks which post detail screen is currently visible so we can avoid
/// showing in-app banners for that same post.
class CurrentPostTracker {
  static final ValueNotifier<String?> currentPostId =
      ValueNotifier<String?>(null);
}

