import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disaster_resilience_ai/models/warning_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';

/// Handles periodic polling for new warnings and showing local notifications.
///
/// High-severity alerts (warning / evacuate) trigger a full-screen incoming
/// alert experience with vibration, alarm sound, and an overlay page.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _lastCheckKey = 'notification_last_check';
  static const _pollInterval = Duration(seconds: 30);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final ApiService _api = ApiService();

  Timer? _timer;
  bool _initialized = false;
  double? _userLat;
  double? _userLon;

  /// Navigator key used to push the full-screen alert from anywhere.
  GlobalKey<NavigatorState>? navigatorKey;

  /// Callback invoked when user taps a standard (low-priority) notification.
  void Function(Warning warning)? onWarningTap;

  /// Callback invoked for high-severity alerts to show the full-screen page.
  /// If set, it takes priority over the default notification for
  /// warning / evacuate level alerts.
  void Function(Warning warning)? onEmergencyAlert;

  /// Cached list of warnings shown in the latest poll (for tap lookup).
  List<Warning> _recentWarnings = [];

  /// Initialise the local-notification plugin and request permissions.
  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request notification permission on Android 13+
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    _initialized = true;
  }

  /// Start polling for new warnings.
  ///
  /// [accessToken] is used for authenticated endpoints.
  /// [latitude]/[longitude] enable hyper-local filtering.
  void startPolling({
    required String accessToken,
    required double latitude,
    required double longitude,
  }) {
    _userLat = latitude;
    _userLon = longitude;
    _timer?.cancel();
    // Do an immediate check, then schedule periodic checks.
    _checkForNewWarnings();
    _timer = Timer.periodic(_pollInterval, (_) => _checkForNewWarnings());
  }

  /// Update the location used for hyper-local filtering without restarting.
  void updateLocation({required double latitude, required double longitude}) {
    _userLat = latitude;
    _userLon = longitude;
  }

  /// Stop the polling timer (e.g. on logout).
  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _checkForNewWarnings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck =
          prefs.getString(_lastCheckKey) ??
          DateTime.now().toUtc().toIso8601String();

      final params = <String, String>{'since': lastCheck};
      if (_userLat != null && _userLon != null) {
        params['latitude'] = _userLat.toString();
        params['longitude'] = _userLon.toString();
      }

      final uri = Uri.parse(
        '${ApiService.baseUrl}/api/v1/warnings/since/',
      ).replace(queryParameters: params);
      final response = await _api.httpGet(uri);

      if (response == null) return;

      final warningList = WarningList.fromJson(response);
      if (warningList.warnings.isEmpty) {
        // Update the last-check timestamp even if nothing new
        await prefs.setString(
          _lastCheckKey,
          DateTime.now().toUtc().toIso8601String(),
        );
        return;
      }

      _recentWarnings = warningList.warnings;

      for (final warning in warningList.warnings) {
        final isHighSeverity =
            warning.alertLevel == AlertLevel.warning ||
            warning.alertLevel == AlertLevel.evacuate;

        if (isHighSeverity && onEmergencyAlert != null) {
          // Trigger full-screen incoming alert experience
          onEmergencyAlert!(warning);
        }
        // Always also post a system notification (visible in tray)
        await _showNotification(warning);
      }

      // Persist the current time as last-checked.
      await prefs.setString(
        _lastCheckKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (e) {
      debugPrint('NotificationService poll error: $e');
    }
  }

  Future<void> _showNotification(Warning warning) async {
    final String channelId;
    final String channelName;
    final Importance importance;
    final Priority priority;
    final bool isEmergency;

    switch (warning.alertLevel) {
      case AlertLevel.evacuate:
        channelId = 'disaster_evacuate';
        channelName = 'Evacuation Alerts';
        importance = Importance.max;
        priority = Priority.max;
        isEmergency = true;
      case AlertLevel.warning:
        channelId = 'disaster_warning';
        channelName = 'Warnings';
        importance = Importance.max;
        priority = Priority.max;
        isEmergency = true;
      case AlertLevel.observe:
        channelId = 'disaster_observe';
        channelName = 'Observe Notices';
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
        isEmergency = false;
      case AlertLevel.advisory:
        channelId = 'disaster_advisory';
        channelName = 'Advisories';
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
        isEmergency = false;
    }

    // Long vibration pattern for emergencies:  wait-vib-wait-vib-wait-vib
    final vibrationPattern = isEmergency
        ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000])
        : null;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Disaster warning notifications',
      importance: importance,
      priority: priority,
      ticker: warning.title,
      // Emergency: use the device alarm sound, show on lock screen, insistent
      sound: isEmergency
          ? const RawResourceAndroidNotificationSound('alarm')
          : null,
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      ongoing: isEmergency,
      autoCancel: !isEmergency,
      fullScreenIntent: isEmergency,
      category: isEmergency ? AndroidNotificationCategory.alarm : null,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        '${warning.hazardType.displayName} — ${warning.description}',
        contentTitle: '[${warning.alertLevel.displayName}] ${warning.title}',
      ),
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      warning.id.hashCode,
      '[${warning.alertLevel.displayName}] ${warning.title}',
      '${warning.hazardType.displayName} alert — ${warning.description}',
      details,
      payload: warning.id,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    final warningId = response.payload;
    if (warningId == null) return;

    final match = _recentWarnings.where((w) => w.id == warningId).toList();
    if (match.isNotEmpty && onWarningTap != null) {
      onWarningTap!(match.first);
    }
  }

  /// Fire a test notification immediately to verify the system works.
  Future<void> showTestNotification() async {
    if (!_initialized) {
      throw StateError(
        'Notifications are not available on this platform or init() was not called.',
      );
    }
    const androidDetails = AndroidNotificationDetails(
      'disaster_test',
      'Test Notifications',
      channelDescription: 'Used to verify notifications are working',
      importance: Importance.max,
      priority: Priority.high,
      autoCancel: true,
    );
    await _plugin.show(
      0,
      '\u2705 Notifications are working!',
      'You will receive alerts like this when a disaster warning is issued.',
      const NotificationDetails(android: androidDetails),
    );
  }
}
