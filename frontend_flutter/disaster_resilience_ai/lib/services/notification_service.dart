import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disaster_resilience_ai/models/warning_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';

/// Handles periodic polling for new warnings and showing local notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _lastCheckKey = 'notification_last_check';
  static const _pollInterval = Duration(seconds: 30);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final ApiService _api = ApiService();

  Timer? _timer;
  double? _userLat;
  double? _userLon;

  /// Callback invoked when user taps a notification.
  void Function(Warning warning)? onWarningTap;

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

    switch (warning.alertLevel) {
      case AlertLevel.evacuate:
        channelId = 'disaster_evacuate';
        channelName = 'Evacuation Alerts';
        importance = Importance.max;
        priority = Priority.max;
      case AlertLevel.warning:
        channelId = 'disaster_warning';
        channelName = 'Warnings';
        importance = Importance.high;
        priority = Priority.high;
      case AlertLevel.observe:
        channelId = 'disaster_observe';
        channelName = 'Observe Notices';
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
      case AlertLevel.advisory:
        channelId = 'disaster_advisory';
        channelName = 'Advisories';
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Disaster warning notifications',
      importance: importance,
      priority: priority,
      ticker: warning.title,
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
}
