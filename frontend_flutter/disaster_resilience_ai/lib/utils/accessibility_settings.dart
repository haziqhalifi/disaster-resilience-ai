import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AccessibilitySettings {
  static const String largeTextKey = 'accessibility_large_text_enabled';
  static const String reducedMotionKey = 'accessibility_reduced_motion_enabled';
  static const String hapticOnlyAlertKey =
      'accessibility_haptic_only_alert_enabled';

  static final ValueNotifier<bool> largeTextEnabledNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<bool> reducedMotionEnabledNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<bool> hapticOnlyAlertsEnabledNotifier =
      ValueNotifier<bool>(false);

  const AccessibilitySettings({
    required this.largeTextEnabled,
    required this.reducedMotionEnabled,
    required this.hapticOnlyAlertsEnabled,
  });

  final bool largeTextEnabled;
  final bool reducedMotionEnabled;
  final bool hapticOnlyAlertsEnabled;

  static Future<AccessibilitySettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = AccessibilitySettings(
      largeTextEnabled: prefs.getBool(largeTextKey) ?? false,
      reducedMotionEnabled: prefs.getBool(reducedMotionKey) ?? false,
      hapticOnlyAlertsEnabled: prefs.getBool(hapticOnlyAlertKey) ?? false,
    );
    largeTextEnabledNotifier.value = settings.largeTextEnabled;
    reducedMotionEnabledNotifier.value = settings.reducedMotionEnabled;
    hapticOnlyAlertsEnabledNotifier.value = settings.hapticOnlyAlertsEnabled;
    return settings;
  }

  static Future<void> setLargeTextEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(largeTextKey, enabled);
    largeTextEnabledNotifier.value = enabled;
  }

  static Future<void> setReducedMotionEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(reducedMotionKey, enabled);
    reducedMotionEnabledNotifier.value = enabled;
  }

  static Future<void> setHapticOnlyAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hapticOnlyAlertKey, enabled);
    hapticOnlyAlertsEnabledNotifier.value = enabled;
  }
}
