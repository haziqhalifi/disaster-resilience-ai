import 'dart:async';

import 'package:flutter/material.dart';

import 'package:disaster_resilience_ai/models/warning_model.dart';
import 'package:disaster_resilience_ai/localization/app_language.dart';
import 'package:disaster_resilience_ai/models/weather_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/services/weather_service.dart';
import 'package:disaster_resilience_ai/ui/auth_page.dart';
import 'package:disaster_resilience_ai/ui/emergency_alert_page.dart';
import 'package:disaster_resilience_ai/ui/school_preparedness_page.dart';
import 'package:disaster_resilience_ai/ui/emergency_contacts_page.dart';
import 'package:disaster_resilience_ai/ui/reports_tab.dart';
import 'package:disaster_resilience_ai/ui/map_tab.dart';
import 'package:disaster_resilience_ai/ui/profile_tab.dart';
import 'package:disaster_resilience_ai/ui/weather_page.dart';
import 'package:disaster_resilience_ai/ui/chatbot_page.dart';
import 'package:disaster_resilience_ai/ui/disaster_checklist_page.dart';
import 'package:disaster_resilience_ai/ui/learn_page.dart';
import 'package:disaster_resilience_ai/ui/safe_routes_page.dart';
import 'package:disaster_resilience_ai/models/disaster_news_model.dart';
import 'package:disaster_resilience_ai/ui/all_warnings_page.dart';
import 'package:disaster_resilience_ai/ui/all_news_page.dart';
import 'package:disaster_resilience_ai/ui/widgets/landa_wordmark.dart';
import 'package:disaster_resilience_ai/services/notification_service.dart';
import 'package:disaster_resilience_ai/ui/incoming_alert_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.accessToken,
    required this.email,
    required this.username,
  });

  final String accessToken;
  final String email;
  final String username;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final ApiService _api = ApiService();
  final WeatherService _weatherService = WeatherService();

  // ── Warning state ────────────────────────────────────────────────────────
  bool _loadingWarnings = true;
  List<Warning> _nearbyWarnings = [];
  List<Warning> _allActiveWarnings = [];
  String? _warningError;

  // ── Weather state ─────────────────────────────────────────────────────────
  WeatherData? _weather;

  // Location — updated from GPS; falls back to Kuantan if unavailable
  double _userLat = 3.8077;
  double _userLon = 103.3260;
  String _locationLabel = 'Locating...';
  Timer? _liveLocationTimer;

  bool get _isMalay =>
      AppLanguageScope.of(context).language == AppLanguage.malay;
  bool get _isChinese =>
      AppLanguageScope.of(context).language == AppLanguage.chinese;

  String _tr({required String en, required String ms, String? zh}) {
    if (_isMalay) return ms;
    if (_isChinese) return zh ?? en;
    return en;
  }

  @override
  void initState() {
    super.initState();
    _determineLocation();
  }

  @override
  void dispose() {
    _liveLocationTimer?.cancel();
    super.dispose();
  }

  /// Fetch the device's real GPS location, then kick off data fetches.
  Future<void> _determineLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userLat = position.latitude;
          _userLon = position.longitude;
          _locationLabel = _tr(
            en: 'Current location',
            ms: 'Lokasi semasa',
            zh: '当前位置',
          );
        });
      }

      final place = await _weatherService.fetchLocationName(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (mounted && place != null && place.isNotEmpty) {
        setState(() => _locationLabel = place);
      }
    } catch (_) {
      // GPS unavailable — keep fallback coordinates
      if (mounted) {
        setState(
          () => _locationLabel = _tr(
            en: 'Location unavailable',
            ms: 'Lokasi tidak tersedia',
            zh: '无法获取位置',
          ),
        );
      }
    }
    _fetchWarnings();
    _updateBackendLocation();
    _fetchWeather();
    _startNotificationPolling();
    _startLiveLocationSync();
  }

  /// Keep uploading user's location while app is open so family members
  /// can view near real-time movement.
  void _startLiveLocationSync() {
    _liveLocationTimer?.cancel();
    _liveLocationTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return;

        final permission = await Geolocator.checkPermission();
        if (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse) {
          return;
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        ).timeout(const Duration(seconds: 8));

        if (!mounted) return;
        setState(() {
          _userLat = position.latitude;
          _userLon = position.longitude;
          _locationLabel =
              '${position.latitude.toStringAsFixed(4)}°N, ${position.longitude.toStringAsFixed(4)}°E';
        });

        await _updateBackendLocation();
      } catch (_) {
        // Non-critical in background loop.
      }
    });
  }

  /// Begin polling for new warnings and showing local notifications.
  void _startNotificationPolling() {
    final notif = NotificationService.instance;
    notif.onWarningTap = (warning) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmergencyAlertPage(warning: warning),
          ),
        );
      }
    };
    notif.onEmergencyAlert = (warning) {
      // Push the full-screen incoming alert page (like a phone call)
      final nav = notif.navigatorKey?.currentState;
      if (nav != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => IncomingAlertPage(warning: warning),
          ),
        );
      }
    };
    notif.startPolling(
      accessToken: widget.accessToken,
      latitude: _userLat,
      longitude: _userLon,
    );
  }

  Future<void> _fetchWeather() async {
    try {
      final data = await _weatherService.fetchWeather(
        latitude: _userLat,
        longitude: _userLon,
      );
      if (mounted) setState(() => _weather = data);
    } catch (_) {
      // Non-critical — widget shows placeholder if unavailable
    }
  }

  /// Send user's location to backend so the warning system can target them.
  Future<void> _updateBackendLocation() async {
    try {
      await _api.updateLocation(
        accessToken: widget.accessToken,
        latitude: _userLat,
        longitude: _userLon,
      );
      NotificationService.instance.updateLocation(
        latitude: _userLat,
        longitude: _userLon,
      );
    } catch (_) {
      // Non-critical — silently fail if backend is down
    }
  }

  /// Fetch warnings from the backend.
  Future<void> _fetchWarnings() async {
    setState(() {
      _loadingWarnings = true;
      _warningError = null;
    });

    try {
      // Fetch both nearby warnings and all active warnings in parallel
      final results = await Future.wait([
        _api.fetchNearbyWarnings(latitude: _userLat, longitude: _userLon),
        _api.fetchWarnings(activeOnly: true),
      ]);

      final nearbyData = WarningList.fromJson(results[0]);
      final allData = WarningList.fromJson(results[1]);

      if (mounted) {
        setState(() {
          _nearbyWarnings = nearbyData.warnings;
          _allActiveWarnings = allData.warnings;
          _loadingWarnings = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _warningError = e.toString().replaceFirst('Exception: ', '');
          _loadingWarnings = false;
        });
      }
    }
  }

  /// Determine the highest alert level from nearby warnings.
  AlertLevel get _highestAlertLevel {
    if (_nearbyWarnings.isEmpty) return AlertLevel.advisory;
    return _nearbyWarnings.fold<AlertLevel>(
      AlertLevel.advisory,
      (prev, w) =>
          w.alertLevel.severityIndex > prev.severityIndex ? w.alertLevel : prev,
    );
  }

  Future<void> _logout() async {
    NotificationService.instance.stopPolling();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_access_token');
    await prefs.remove('auth_email');
    await prefs.remove('auth_username');
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthPage()));
  }

  void _openEmergencyDetails() {
    if (_nearbyWarnings.isNotEmpty) {
      final mostSevere = _nearbyWarnings.reduce(
        (a, b) =>
            a.alertLevel.severityIndex > b.alertLevel.severityIndex ? a : b,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmergencyAlertPage(warning: mostSevere),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmergencyAlertPage()),
    );
  }

  void _openWeatherPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeatherPage(
          latitude: _userLat,
          longitude: _userLon,
          locationName: _locationLabel,
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_fetchWarnings(), _fetchWeather()]);
      },
      color: Theme.of(context).colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusSection(),
              const SizedBox(height: 18),
              _buildWeatherSection(),
              const SizedBox(height: 24),
              _buildPrimaryActions(),
              const SizedBox(height: 24),
              _buildCommunityFeedSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF111827);
    final surface = isDark ? const Color(0xFF1B251B) : Colors.white;
    final subtleText = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF6B7280);
    final borderColor = isDark
        ? const Color(0xFF334236)
        : const Color(0xFF2D5927).withAlpha(32);
    final chipBg = isDark
        ? const Color(0xFF2D5927).withAlpha(64)
        : const Color(0xFF2D5927).withAlpha(16);
    final chipFg = isDark ? const Color(0xFF9EDB94) : const Color(0xFF2D5927);

    final isLoaded = !_loadingWarnings;
    final hasError = _warningError != null;
    final hazards = hasError ? 0 : _nearbyWarnings.length;

    final String safetyLabel;
    final Color safetyColor;
    final IconData safetyIcon;

    if (!isLoaded) {
      safetyLabel = _tr(en: 'Checking', ms: 'Menyemak', zh: '检查中');
      safetyColor = const Color(0xFF2D5927);
      safetyIcon = Icons.hourglass_top_rounded;
    } else if (hasError) {
      safetyLabel = _tr(en: 'Unknown', ms: 'Tidak Diketahui', zh: '未知');
      safetyColor = const Color(0xFF6B7280);
      safetyIcon = Icons.wifi_off_rounded;
    } else if (_nearbyWarnings.isEmpty) {
      safetyLabel = _tr(en: 'Secure', ms: 'Selamat', zh: '安全');
      safetyColor = const Color(0xFF2D5927);
      safetyIcon = Icons.check_circle_rounded;
    } else {
      safetyLabel = _highestAlertLevel.displayName;
      switch (_highestAlertLevel) {
        case AlertLevel.advisory:
          safetyColor = const Color(0xFF2563EB);
          safetyIcon = Icons.info_outline;
          break;
        case AlertLevel.observe:
          safetyColor = const Color(0xFFD97706);
          safetyIcon = Icons.visibility_outlined;
          break;
        case AlertLevel.warning:
          safetyColor = const Color(0xFFEA580C);
          safetyIcon = Icons.warning_amber_rounded;
          break;
        case AlertLevel.evacuate:
          safetyColor = const Color(0xFFDC2626);
          safetyIcon = Icons.directions_run;
          break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _tr(en: 'Your Status', ms: 'Status Anda', zh: '您的状态'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _openWeatherPage,
              icon: Icon(_weather?.icon ?? Icons.cloud_outlined, size: 18),
              label: Text(
                _weather != null
                    ? '${_weather!.temperature.round()}°C'
                    : '--°C',
              ),
              style: TextButton.styleFrom(
                backgroundColor: chipBg,
                foregroundColor: chipFg,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openEmergencyDetails,
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: safetyColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: safetyColor.withAlpha(46),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(safetyIcon, color: Colors.white, size: 30),
                      const Spacer(),
                      Text(
                        _tr(
                          en: 'Safety Status',
                          ms: 'Status Keselamatan',
                          zh: '安全状态',
                        ),
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        safetyLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (_allActiveWarnings.isEmpty) {
                    _openEmergencyDetails();
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AllWarningsPage(warnings: _allActiveWarnings),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        hazards > 0
                            ? Icons.warning_amber_rounded
                            : Icons.warning_amber_outlined,
                        color: hazards > 0
                            ? const Color(0xFFF97316)
                            : const Color(0xFF2D5927),
                        size: 30,
                      ),
                      const Spacer(),
                      Text(
                        _tr(
                          en: 'Active Hazards',
                          ms: 'Bahaya Aktif',
                          zh: '当前风险',
                        ),
                        style: TextStyle(color: subtleText, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        !isLoaded
                            ? _tr(en: 'Checking', ms: 'Menyemak', zh: '检查中')
                            : hazards > 0
                            ? _tr(
                                en: '$hazards Nearby',
                                ms: '$hazards Berhampiran',
                                zh: '$hazards 个附近',
                              )
                            : _tr(en: 'None', ms: 'Tiada', zh: '无'),
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeatherSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1B251B) : Colors.white;
    final headingColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF111827);
    final bodyColor = isDark
        ? const Color(0xFFB8C2BA)
        : const Color(0xFF374151);
    final borderColor = isDark
        ? const Color(0xFF334236)
        : const Color(0xFF2D5927).withAlpha(28);
    final iconChipBg = isDark
        ? const Color(0xFF2D5927).withAlpha(64)
        : const Color(0xFF2D5927).withAlpha(16);
    final iconColor = isDark
        ? const Color(0xFF9EDB94)
        : const Color(0xFF2D5927);

    final hasWeather = _weather != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openWeatherPage,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconChipBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        hasWeather
                            ? _weather!.icon
                            : Icons.thunderstorm_outlined,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasWeather
                                ? _tr(
                                    en: 'Local Weather: ${_weather!.description}',
                                    ms: 'Cuaca Tempatan: ${_weather!.description}',
                                    zh: '本地天气：${_weather!.description}',
                                  )
                                : _tr(
                                    en: 'Local Weather Update',
                                    ms: 'Kemas Kini Cuaca Tempatan',
                                    zh: '本地天气更新',
                                  ),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: headingColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasWeather
                                ? _tr(
                                    en: 'Heavy rainfall risk can shift quickly. Check your nearest safe route now.',
                                    ms: 'Risiko hujan lebat boleh berubah dengan cepat. Semak laluan selamat terdekat anda sekarang.',
                                    zh: '强降雨风险可能快速变化。请立即查看最近的安全路线。',
                                  )
                                : _tr(
                                    en: 'Pull down to refresh the latest weather status for your location.',
                                    ms: 'Tarik ke bawah untuk memuat semula status cuaca terkini bagi lokasi anda.',
                                    zh: '下拉以刷新您所在位置的最新天气状态。',
                                  ),
                            style: TextStyle(
                              color: bodyColor,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 146,
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    colors: [Color(0xFF3A6EA5), Color(0xFF22325C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _locationLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          hasWeather
                              ? '${_weather!.temperature.round()}°C'
                              : '--°C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 30,
                          ),
                        ),
                        const Icon(
                          Icons.radar_rounded,
                          color: Colors.white70,
                          size: 32,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryActions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF111827);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr(en: 'Quick Actions', ms: 'Tindakan Pantas', zh: '快捷操作'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 12),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 90,
          ),
          children: [
            _buildPrimaryActionChip(
              icon: Icons.checklist,
              label: _tr(en: 'Checklist', ms: 'Senarai', zh: '清单'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DisasterChecklistPage(),
                ),
              ),
            ),
            _buildPrimaryActionChip(
              icon: Icons.alt_route,
              label: _tr(en: 'Safe Routes', ms: 'Laluan', zh: '安全路线'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SafeRoutesPage()),
              ),
            ),
            _buildPrimaryActionChip(
              icon: Icons.menu_book,
              label: _tr(en: 'Learn', ms: 'Belajar', zh: '学习'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LearnPage()),
              ),
            ),
            _buildPrimaryActionChip(
              icon: Icons.call,
              label: _tr(en: 'SOS', ms: 'SOS', zh: '求助'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EmergencyContactsPage(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrimaryActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark
        ? const Color(0xFF2D5927).withAlpha(64)
        : const Color(0xFF2D5927).withAlpha(16);
    final chipIcon = isDark ? const Color(0xFF9EDB94) : const Color(0xFF2D5927);
    final labelColor = isDark
        ? const Color(0xFFD1D5DB)
        : const Color(0xFF111827);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 25, color: chipIcon),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommunityFeedSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF111827);
    final warnings = _nearbyWarnings.take(1).toList();
    final news = DisasterNewsData.articles.take(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _tr(en: 'Community Feed', ms: 'Suapan Komuniti', zh: '社区动态'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllNewsPage()),
              ),
              child: Text(
                _tr(en: 'View All', ms: 'Lihat Semua', zh: '查看全部'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingWarnings && warnings.isEmpty)
          _buildFeedCard(
            source: 'LANDA',
            meta: _tr(
              en: 'Updating • $_locationLabel',
              ms: 'Mengemas kini • $_locationLabel',
              zh: '更新中 • $_locationLabel',
            ),
            message: _tr(
              en: 'Fetching live community updates for your area.',
              ms: 'Sedang mendapatkan kemas kini komuniti secara langsung untuk kawasan anda.',
              zh: '正在获取您所在区域的社区实时更新。',
            ),
            onTap: _fetchWarnings,
          ),
        if (_warningError != null && warnings.isEmpty)
          _buildFeedCard(
            source: 'LANDA',
            meta: _tr(
              en: 'Connection issue • $_locationLabel',
              ms: 'Masalah sambungan • $_locationLabel',
              zh: '连接问题 • $_locationLabel',
            ),
            message: _tr(
              en: 'Unable to load warning feed right now. Pull down to retry.',
              ms: 'Tidak dapat memuatkan suapan amaran sekarang. Tarik ke bawah untuk cuba lagi.',
              zh: '暂时无法加载警报信息流。请下拉重试。',
            ),
            onTap: _fetchWarnings,
          ),
        ...warnings.map(
          (warning) => _buildFeedCard(
            source: warning.source,
            meta: '${_timeAgo(warning.createdAt)} • $_locationLabel',
            message: warning.description,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EmergencyAlertPage(warning: warning),
              ),
            ),
          ),
        ),
        ...news.map(
          (article) => _buildFeedCard(
            source: article.source,
            meta: '${_timeAgo(article.publishedAt)} • ${article.category}',
            message: article.summary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NewsDetailPage(article: article),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedCard({
    required String source,
    required String meta,
    required String message,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1B251B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334236)
        : const Color(0xFF2D5927).withAlpha(30);
    final avatarBg = isDark
        ? const Color(0xFF2D5927).withAlpha(64)
        : const Color(0xFF2D5927).withAlpha(20);
    final primaryText = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF111827);
    final metaText = isDark ? const Color(0xFF9AA79B) : const Color(0xFF6B7280);
    final bodyText = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF1F2937);

    final initial = source.isEmpty ? 'R' : source[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: avatarBg,
                      ),
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF9EDB94)
                              : const Color(0xFF2D5927),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            style: TextStyle(color: metaText, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(message, style: TextStyle(color: bodyText, height: 1.35)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) {
      return _tr(en: 'Just now', ms: 'Baru sahaja', zh: '刚刚');
    }
    if (diff.inMinutes < 60) {
      if (_isMalay) return '${diff.inMinutes}m lalu';
      if (_isChinese) return '${diff.inMinutes}分钟前';
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      if (_isMalay) return '${diff.inHours}j lalu';
      if (_isChinese) return '${diff.inHours}小时前';
      return '${diff.inHours}h ago';
    }
    if (_isMalay) return '${diff.inDays}h lalu';
    if (_isChinese) return '${diff.inDays}天前';
    return '${diff.inDays}d ago';
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return const ReportsTab();
      case 2:
        return const MapTab();
      case 3:
        return ProfileTab(
          accessToken: widget.accessToken,
          username: widget.username,
          email: widget.email,
          onLogout: _logout,
        );
      default:
        return _buildDashboard();
    }
  }

  NavigationDestination _buildNavDestination({
    required String label,
    required IconData icon,
    required IconData selectedIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navPrimary = isDark
        ? const Color(0xFF86C77C)
        : const Color(0xFF2D5927);
    final navInactive = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF66726A);

    Widget navItem({required bool isSelected}) {
      return SizedBox(
        width: 88,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                      ? const Color(0xFF2D5927).withAlpha(64)
                      : navPrimary.withAlpha(18))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: 24,
                color: isSelected ? navPrimary : navInactive,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? navPrimary : navInactive,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return NavigationDestination(
      label: label,
      icon: navItem(isSelected: false),
      selectedIcon: navItem(isSelected: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F140F) : const Color(0xFFF0F2F5);
    final barBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334236)
        : const Color(0xFF2D5927).withAlpha(26);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: barBg,
        foregroundColor: isDark
            ? const Color(0xFFE5E7EB)
            : const Color(0xFF111827),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        elevation: 0,
        shadowColor: Colors.transparent,
        centerTitle: true,
        titleSpacing: 0,
        toolbarHeight: 64,
        title: LandaBrandTitle(
          wordmarkSize: 24,
          iconColor: isDark ? const Color(0xFF86C77C) : const Color(0xFF2D5927),
          wordmarkColors: isDark
              ? const [Color(0xFF9EDB94), Color(0xFFE3F3DF)]
              : const [Color(0xFF163A12), Color(0xFF2D5927)],
          wordmarkStrokeColor: isDark
              ? const Color(0x4D86C77C)
              : const Color(0x991B3516),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: borderColor),
        ),
        actions: [
          IconButton(
            tooltip: _tr(en: 'Warnings', ms: 'Amaran', zh: '警报'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AllWarningsPage(warnings: _allActiveWarnings),
              ),
            ),
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none_rounded),
                if (_nearbyWarnings.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: const Color(0xFFE8F5E9),
              child: IconButton(
                icon: const Icon(
                  Icons.person_outline,
                  color: Color(0xFF2E7D32),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileTab(
                        accessToken: widget.accessToken,
                        username: widget.username,
                        email: widget.email,
                        onLogout: _logout,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatbotPage()),
                );
              },
              backgroundColor: const Color(0xFF2E7D32),
              tooltip: _tr(
                en: 'Disaster Assistant',
                ms: 'Pembantu Bencana',
                zh: '灾害助手',
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: barBg,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          backgroundColor: barBg,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          indicatorColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          destinations: [
            _buildNavDestination(
              label: _tr(en: 'Home', ms: 'Laman', zh: '主页'),
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
            ),
            _buildNavDestination(
              label: _tr(en: 'Reports', ms: 'Laporan', zh: '报告'),
              icon: Icons.insert_chart_outlined,
              selectedIcon: Icons.insert_chart,
            ),
            _buildNavDestination(
              label: _tr(en: 'Map', ms: 'Peta', zh: '地图'),
              icon: Icons.map_outlined,
              selectedIcon: Icons.map,
            ),
            _buildNavDestination(
              label: _tr(en: 'Profile', ms: 'Profil', zh: '个人'),
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
            ),
          ],
        ),
      ),
    );
  }
}
