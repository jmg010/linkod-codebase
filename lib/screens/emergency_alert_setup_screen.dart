import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

class EmergencyAlertSetupScreen extends StatefulWidget {
  const EmergencyAlertSetupScreen({super.key});

  @override
  State<EmergencyAlertSetupScreen> createState() =>
      _EmergencyAlertSetupScreenState();
}

class _EmergencyAlertSetupScreenState extends State<EmergencyAlertSetupScreen> {
  static const MethodChannel _overlayChannel = MethodChannel(
    'linkod.overlay_control',
  );
  static const MethodChannel _capabilitiesChannel = MethodChannel(
    'linkod.notification_capabilities',
  );

  bool _loading = true;
  bool _notificationsEnabled = false;
  bool _overlayEnabled = false;
  bool _fullScreenEnabled = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notificationsEnabled = true;
        _overlayEnabled = true;
        _fullScreenEnabled = true;
      });
      return;
    }

    final notificationsEnabled = await _hasNotificationPermission();
    final overlayEnabled = await _canDrawOverlay();
    final fullScreenEnabled = await _canUseFullScreenIntent();

    if (!mounted) return;
    setState(() {
      _loading = false;
      _notificationsEnabled = notificationsEnabled;
      _overlayEnabled = overlayEnabled;
      _fullScreenEnabled = fullScreenEnabled;
    });
  }

  Future<bool> _hasNotificationPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _canDrawOverlay() async {
    try {
      return await _overlayChannel.invokeMethod<bool>('canDrawOverlay') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _canUseFullScreenIntent() async {
    try {
      return await _capabilitiesChannel.invokeMethod<bool>(
            'canUseFullScreenIntent',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _enableNotifications() async {
    try {
      final androidImplementation =
          FlutterLocalNotificationsPlugin()
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      await androidImplementation?.requestNotificationsPermission();
      await _capabilitiesChannel.invokeMethod<bool>('openNotificationSettings');
    } catch (_) {
      // Keep screen responsive even if settings bridge is unavailable.
    } finally {
      await _refreshStatus();
    }
  }

  Future<void> _enableOverlay() async {
    try {
      await _overlayChannel.invokeMethod<bool>('requestOverlayPermission');
    } catch (_) {
      // Keep screen responsive even if settings bridge is unavailable.
    } finally {
      await _refreshStatus();
    }
  }

  Future<void> _enableFullScreenAlerts() async {
    try {
      await _capabilitiesChannel.invokeMethod<bool>('openFullScreenIntentSettings');
    } catch (_) {
      // Keep screen responsive even if settings bridge is unavailable.
    } finally {
      await _refreshStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allEnabled =
        _notificationsEnabled && _overlayEnabled && _fullScreenEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement Alerts'),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF20BF6B)))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Enable all capabilities to maximize announcement visibility on your device.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: isDark ? Colors.grey[300] : Colors.black87,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 24),
                    _PermissionTile(
                      title: 'Notifications',
                      description:
                          'Required for announcement delivery and fallback notifications.',
                      enabled: _notificationsEnabled,
                      actionLabel: 'Enable notifications',
                      onTap: _enableNotifications,
                    ),
                    const SizedBox(height: 12),
                    _PermissionTile(
                      title: 'Draw Over Other Apps',
                      description:
                          'Allows overlay notifications when your app is not open.',
                      enabled: _overlayEnabled,
                      actionLabel: 'Enable overlay',
                      onTap: _enableOverlay,
                    ),
                    const SizedBox(height: 12),
                    _PermissionTile(
                      title: 'Full-screen Alerts',
                      description:
                          'Allows full-screen interruption for important announcements.',
                      enabled: _fullScreenEnabled,
                      actionLabel: 'Enable full-screen',
                      onTap: _enableFullScreenAlerts,
                    ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF20BF6B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: allEnabled
                          ? () => Navigator.of(context).pop()
                          : _refreshStatus,
                      child: Text(
                        allEnabled ? 'All Set!' : 'Refresh Status',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.title,
    required this.description,
    required this.enabled,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool enabled;
  final String actionLabel;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? const Color(0xFF20BF6B) : Colors.grey.shade500;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF1E1E1E) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                enabled ? Icons.check_circle_rounded : Icons.info_outlined,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: enabled ? null : () => onTap(),
              style: OutlinedButton.styleFrom(
                foregroundColor: enabled ? color : Colors.grey.shade600,
                side: BorderSide(
                  color: color.withOpacity(enabled ? 1 : 0.3),
                  width: 1,
                ),
              ),
              child: Text(enabled ? 'Enabled' : actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
