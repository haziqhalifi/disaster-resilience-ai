import 'dart:async';

import 'package:flutter/material.dart';

import 'package:disaster_resilience_ai/models/warning_model.dart';
import 'package:disaster_resilience_ai/models/prediction_result.dart';
import 'package:disaster_resilience_ai/localization/app_language.dart';
import 'package:disaster_resilience_ai/models/weather_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/services/weather_service.dart';
import 'package:disaster_resilience_ai/ui/auth_page.dart';
import 'package:disaster_resilience_ai/ui/emergency_alert_page.dart';
import 'package:disaster_resilience_ai/ui/emergency_contacts_page.dart';
import 'package:disaster_resilience_ai/ui/notifications_tab.dart';
import 'package:disaster_resilience_ai/ui/map_tab.dart';
import 'package:disaster_resilience_ai/ui/profile_tab.dart';
import 'package:disaster_resilience_ai/ui/weather_page.dart';
import 'package:disaster_resilience_ai/ui/chatbot_page.dart';
import 'package:disaster_resilience_ai/ui/disaster_checklist_page.dart';
import 'package:disaster_resilience_ai/ui/learn_page.dart';
import 'package:disaster_resilience_ai/ui/safe_routes_page.dart';
import 'package:disaster_resilience_ai/ui/submit_report_page.dart';
import 'package:disaster_resilience_ai/ui/family_tab.dart';
import 'package:disaster_resilience_ai/models/disaster_news_model.dart';
import 'package:disaster_resilience_ai/ui/all_warnings_page.dart';
import 'package:disaster_resilience_ai/ui/all_news_page.dart';
import 'package:disaster_resilience_ai/ui/widgets/landa_wordmark.dart';
import 'package:disaster_resilience_ai/services/notification_service.dart';
import 'package:disaster_resilience_ai/ui/incoming_alert_page.dart';
import 'package:disaster_resilience_ai/ui/siren_management_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  static const _notificationsPrefKey = 'notifications_enabled';

  int _selectedIndex = 0;
  final ScrollController _homeScrollController = ScrollController();

  final ApiService _api = ApiService();
  final WeatherService _weatherService = WeatherService();

  // ── Warning state ────────────────────────────────────────────────────────
  bool _loadingWarnings = true;
  List<Warning> _nearbyWarnings = [];
  List<Warning> _allActiveWarnings = [];
  String? _warningError;

  // ── Weather state ─────────────────────────────────────────────────────────
  WeatherData? _weather;

  // ── AI Risk state ─────────────────────────────────────────────────────────
  PredictionResult? _aiRisk;
  bool _loadingAiRisk = false;
  bool _showAiRiskDetails = false;

  // Location — updated from GPS; falls back to Kuantan if unavailable
  double _userLat = 3.8077;
  double _userLon = 103.3260;
  String _locationLabel = 'Locating...';
  Timer? _liveLocationTimer;

  bool get _isMalay =>
      AppLanguageScope.of(context).language == AppLanguage.malay;
  bool get _isIndonesian =>
      AppLanguageScope.of(context).language == AppLanguage.indonesian;
  bool get _isChinese =>
      AppLanguageScope.of(context).language == AppLanguage.chinese;

  String _tr({required String en, required String ms, String? zh}) {
    if (_isIndonesian) {
      final id = indonesianText(en);
      return id == en ? ms : id;
    }
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
    _homeScrollController.dispose();
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
            en: 'Updating location...',
            ms: 'Mengemas kini lokasi...',
            zh: '正在更新位置...',
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
        });

        final place = await _weatherService.fetchLocationName(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        if (mounted && place != null && place.isNotEmpty) {
          setState(() => _locationLabel = place);
        }

        await _updateBackendLocation();
      } catch (_) {
        // Non-critical in background loop.
      }
    });
  }

  /// Begin polling for new warnings and showing local notifications.
  Future<void> _startNotificationPolling() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool(_notificationsPrefKey) ?? true;
    if (!notificationsEnabled) {
      NotificationService.instance.stopPolling();
      return;
    }

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
    // Refresh warning cards on every poll so resolved warnings disappear
    notif.onPollComplete = () {
      if (mounted) _fetchWarnings();
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
      _fetchAiRisk();
    } catch (_) {
      // Non-critical — widget shows placeholder if unavailable
    }
  }

  /// Call the AI flood-risk model using live weather data as features.
  Future<void> _fetchAiRisk() async {
    final w = _weather;
    if (w == null) return;
    setState(() => _loadingAiRisk = true);
    try {
      // Today's precipitation from the daily forecast
      final todayPrecip = w.daily.isNotEmpty
          ? w.daily.first.precipitation
          : 0.0;
      // Features: rainfall_mm, elevation_m, slope_deg, soil_saturation,
      //           distance_to_river_km, historical_incidents, population_density
      // We derive rainfall from weather; the rest use sensible ASEAN defaults.
      final features = <double>[
        todayPrecip, // rainfall_mm
        35.0, // elevation_m (coastal ASEAN avg)
        2.0, // slope_deg
        w.humidity / 100.0, // soil_saturation proxy
        1.5, // distance_to_river_km
        5.0, // historical_incidents
        2500.0, // population_density
      ];
      final json = await _api.predictRisk(features);
      if (mounted) {
        setState(() {
          _aiRisk = PredictionResult.fromJson(json);
          _loadingAiRisk = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAiRisk = false);
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
        controller: _homeScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusSection(),
              const SizedBox(height: 18),
              _buildAiRiskCard(),
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

    final isLoaded = !_loadingWarnings;
    final hasError = _warningError != null;
    final hasWeather = _weather != null;

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
      switch (_highestAlertLevel) {
        case AlertLevel.advisory:
          safetyLabel = _tr(en: 'Advisory', ms: 'Nasihat', zh: '建议');
          safetyColor = const Color(0xFF2563EB);
          safetyIcon = Icons.info_outline;
          break;
        case AlertLevel.observe:
          safetyLabel = _tr(en: 'Observe', ms: 'Perhati', zh: '观察');
          safetyColor = const Color(0xFFD97706);
          safetyIcon = Icons.visibility_outlined;
          break;
        case AlertLevel.warning:
          safetyLabel = _tr(en: 'Warning', ms: 'Amaran', zh: '警告');
          safetyColor = const Color(0xFFEA580C);
          safetyIcon = Icons.warning_amber_rounded;
          break;
        case AlertLevel.evacuate:
          safetyLabel = _tr(en: 'Evacuate', ms: 'Pindah', zh: '撤离');
          safetyColor = const Color(0xFFDC2626);
          safetyIcon = Icons.directions_run;
          break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr(en: 'Your Status', ms: 'Status Anda', zh: '您的状态'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
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
                onTap: _openWeatherPage,
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
                        hasWeather ? (_weather!.icon) : Icons.cloud_outlined,
                        color: const Color(0xFF2D5927),
                        size: 30,
                      ),
                      const Spacer(),
                      Text(
                        _tr(
                          en: 'Local Weather',
                          ms: 'Cuaca Tempatan',
                          zh: '本地天气',
                        ),
                        style: TextStyle(color: subtleText, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasWeather
                            ? '${_weather!.temperature.round()}°C'
                            : _tr(
                                en: 'Unavailable',
                                ms: 'Tidak Tersedia',
                                zh: '不可用',
                              ),
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasWeather
                            ? _weather!.description
                            : _tr(
                                en: 'Tap to view forecast',
                                ms: 'Ketik untuk lihat ramalan',
                                zh: '点击查看天气预报',
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: subtleText, fontSize: 12),
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

  Widget _buildAiRiskCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1B1F2B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2A3A5C)
        : const Color(0xFF2563EB).withAlpha(32);

    if (_loadingAiRisk && _aiRisk == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              _tr(
                en: 'Analysing flood risk…',
                ms: 'Menganalisis risiko banjir…',
                zh: '正在分析洪水风险…',
              ),
              style: TextStyle(
                color: isDark
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    final risk = _aiRisk;
    if (risk == null) return const SizedBox.shrink();

    // Color coding by risk level
    final Color riskColor;
    final IconData riskIcon;
    switch (risk.riskLevel) {
      case 'critical':
        riskColor = const Color(0xFFDC2626);
        riskIcon = Icons.warning_rounded;
        break;
      case 'high':
        riskColor = const Color(0xFFEA580C);
        riskIcon = Icons.warning_amber_rounded;
        break;
      case 'moderate':
        riskColor = const Color(0xFFD97706);
        riskIcon = Icons.info_rounded;
        break;
      case 'low':
        riskColor = const Color(0xFF2563EB);
        riskIcon = Icons.check_circle_outline;
        break;
      default:
        riskColor = const Color(0xFF16A34A);
        riskIcon = Icons.verified_rounded;
    }

    final percentage = (risk.riskScore * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: riskColor.withAlpha(64)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, color: riskColor, size: 20),
              const SizedBox(width: 8),
              Text(
                _tr(
                  en: 'AI Flood Risk Assessment',
                  ms: 'Penilaian Risiko Banjir AI',
                  zh: 'AI洪水风险评估',
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFE5E7EB)
                      : const Color(0xFF111827),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: riskColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  risk.riskLevel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: riskColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Risk bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: risk.riskScore,
              minHeight: 8,
              backgroundColor: riskColor.withAlpha(30),
              valueColor: AlwaysStoppedAnimation<Color>(riskColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(riskIcon, size: 16, color: riskColor),
              const SizedBox(width: 6),
              Text(
                '$percentage% ${_tr(en: 'flood probability', ms: 'kebarangkalian banjir', zh: '洪水概率')}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: riskColor,
                ),
              ),
              const Spacer(),
              Text(
                risk.model,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // "How is this calculated?" toggle
          GestureDetector(
            onTap: () =>
                setState(() => _showAiRiskDetails = !_showAiRiskDetails),
            child: Row(
              children: [
                Icon(
                  _showAiRiskDetails
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  _tr(
                    en: 'Why did I get this result?',
                    ms: 'Kenapa saya dapat keputusan ini?',
                    zh: '为什么会得到这个结果？',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          if (_showAiRiskDetails)
            ..._buildAiRiskDetails(risk, riskColor, isDark),
        ],
      ),
    );
  }

  List<Widget> _buildAiRiskDetails(
    PredictionResult risk,
    Color accent,
    bool isDark,
  ) {
    final subtleText = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF6B7280);
    final labelColor = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF374151);
    final barBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    // Friendly labels for feature names
    String featureLabel(String key) {
      switch (key) {
        case 'rainfall_mm':
          return _tr(en: 'Rainfall', ms: 'Hujan', zh: '降雨量');
        case 'elevation_m':
          return _tr(en: 'Ground height', ms: 'Ketinggian tanah', zh: '地面高度');
        case 'slope_deg':
          return _tr(en: 'Land steepness', ms: 'Kecerunan tanah', zh: '地势陡度');
        case 'soil_saturation':
          return _tr(
            en: 'How wet the soil is',
            ms: 'Tahap kebasahan tanah',
            zh: '土壤湿度',
          );
        case 'distance_to_river_km':
          return _tr(
            en: 'Distance to river',
            ms: 'Jarak ke sungai',
            zh: '离河流距离',
          );
        case 'historical_incidents':
          return _tr(
            en: 'Past floods nearby',
            ms: 'Banjir lampau berdekatan',
            zh: '附近过往洪灾',
          );
        case 'population_density':
          return _tr(
            en: 'People living nearby',
            ms: 'Penduduk berdekatan',
            zh: '附近人口',
          );
        default:
          return key;
      }
    }

    // Sort importances descending
    final entries = risk.featureImportances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxImportance = entries.isNotEmpty ? entries.first.value : 1.0;

    return [
      const SizedBox(height: 10),
      Text(
        _tr(
          en:
              'This flood score is based on current weather and local area '
              'conditions, such as rain, ground level, nearby rivers, and '
              'past flood history.',
          ms:
              'Skor banjir ini berdasarkan cuaca semasa dan keadaan kawasan '
              'setempat, seperti hujan, ketinggian tanah, sungai berdekatan, '
              'dan sejarah banjir.',
          zh:
              '这个洪水分数根据当前天气和本地情况计算，'
              '例如降雨、地势高低、附近河流和过往洪灾记录。',
        ),
        style: TextStyle(fontSize: 11, color: subtleText, height: 1.5),
      ),
      const SizedBox(height: 12),
      Text(
        _tr(
          en: 'What affected this result most',
          ms: 'Faktor yang paling mempengaruhi keputusan',
          zh: '最影响结果的因素',
        ),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: labelColor,
        ),
      ),
      const SizedBox(height: 8),
      ...entries.map((e) {
        final pct = (e.value * 100).toStringAsFixed(1);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  featureLabel(e.key),
                  style: TextStyle(fontSize: 11, color: labelColor),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: maxImportance > 0 ? e.value / maxImportance : 0,
                    minHeight: 6,
                    backgroundColor: barBg,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      accent.withAlpha(160),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 38,
                child: Text(
                  '$pct%',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10, color: subtleText),
                ),
              ),
            ],
          ),
        );
      }),
      const SizedBox(height: 4),
      Text(
        _tr(
          en: 'Model: ${risk.model} ${risk.modelVersion}',
          ms: 'Model: ${risk.model} ${risk.modelVersion}',
          zh: '模型: ${risk.model} ${risk.modelVersion}',
        ),
        style: TextStyle(fontSize: 10, color: subtleText),
      ),
    ];
  }

  Widget _buildPrimaryActions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF111827);
    final surface = isDark ? const Color(0xFF1B251B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334236)
        : const Color(0xFF2D5927).withAlpha(26);
    final bodyColor = isDark
        ? const Color(0xFFA7B5A8)
        : const Color(0xFF64748B);

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
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr(
                  en: 'Get to your most important tools quickly.',
                  ms: 'Akses alat yang paling penting dengan cepat.',
                  zh: '快速进入最重要的工具。',
                ),
                style: TextStyle(color: bodyColor, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 14),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
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
                    icon: Icons.school_outlined,
                    label: _tr(en: 'Learn', ms: 'Belajar', zh: '学习'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LearnPage()),
                    ),
                  ),
                  _buildPrimaryActionChip(
                    icon: Icons.local_phone_outlined,
                    label: _tr(en: 'SOS', ms: 'SOS', zh: '求助'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmergencyContactsPage(),
                      ),
                    ),
                  ),
                  _buildPrimaryActionChip(
                    icon: Icons.flag_outlined,
                    label: _tr(en: 'New Report', ms: 'Laporan Baru', zh: '新报告'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SubmitReportPage(accessToken: widget.accessToken),
                      ),
                    ),
                  ),
                  _buildPrimaryActionChip(
                    icon: Icons.group_outlined,
                    label: _tr(en: 'My Family', ms: 'Keluarga', zh: '我的家人'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FamilyTab(accessToken: widget.accessToken),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
        child: Ink(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, size: 24, color: chipIcon),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
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
            onTap: () {
              final isHigh = warning.alertLevel == AlertLevel.warning ||
                  warning.alertLevel == AlertLevel.evacuate;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => isHigh
                      ? IncomingAlertPage(warning: warning)
                      : EmergencyAlertPage(warning: warning),
                ),
              );
            },
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
        return MapTab(accessToken: widget.accessToken);
      case 2:
        return NotificationsTab(
          accessToken: widget.accessToken,
          warnings: _allActiveWarnings,
        );
      case 3:
        return ProfileTab(
          accessToken: widget.accessToken,
          username: widget.username,
          email: widget.email,
          onLogout: _logout,
        );
      case 4:
        return SirenManagementPage(accessToken: widget.accessToken);
      default:
        return _buildDashboard();
    }
  }

  Widget _buildTopBarTitle(bool isDark) {
    if (_selectedIndex == 0) {
      return LandaWordmark(
        fontSize: 24,
        colors: isDark
            ? const [Color(0xFF9EDB94), Color(0xFFE3F3DF)]
            : const [Color(0xFF163A12), Color(0xFF2D5927)],
        letterSpacing: 1.0,
        strokeColor: isDark ? const Color(0x4D86C77C) : const Color(0x991B3516),
        strokeWidth: 0.9,
        withShadow: false,
        textAlign: TextAlign.left,
      );
    }

    String title;
    switch (_selectedIndex) {
      case 1:
        title = _tr(en: 'Map', ms: 'Peta', zh: '地图');
      case 2:
        title = _tr(en: 'Notifications', ms: 'Notifikasi', zh: '通知');
      case 3:
        title = _tr(en: 'Profile', ms: 'Profil', zh: '个人');
      case 4:
        title = _tr(en: 'Admin', ms: 'Admin', zh: '管理');
      default:
        title = _tr(en: 'Home', ms: 'Laman', zh: '主页');
    }

    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
      ),
    );
  }

  List<Widget>? _buildTopBarActions(bool isDark) {
    if (_selectedIndex != 0) {
      return null;
    }

    final chatTextColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF163A12);
    final chatBorder = isDark
        ? const Color(0xFF3A4A3A)
        : const Color(0xFFCEE4C8);

    final actions = <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: TextButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatbotPage()),
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: chatTextColor,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: chatBorder),
            ),
          ),
          icon: const Icon(Icons.chat_bubble_rounded, size: 16),
          label: const Text(
            'LANDAi',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
        ),
      ),
    ];

    return actions;
  }

  void _scrollHomeToTop() {
    if (!_homeScrollController.hasClients) return;
    _homeScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
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
      return Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: ExcludeSemantics(
          child: SizedBox(
            width: 72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                              ? const Color(0xFF2D5927).withAlpha(64)
                              : navPrimary.withAlpha(18))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    isSelected ? selectedIcon : icon,
                    size: 24,
                    color: isSelected ? navPrimary : navInactive,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? navPrimary : navInactive,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
    final isHomeTab = _selectedIndex == 0;
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
        centerTitle: isHomeTab,
        titleSpacing: isHomeTab ? 0 : 16,
        toolbarHeight: 64,
        title: _buildTopBarTitle(isDark),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: borderColor),
        ),
        actions: _buildTopBarActions(isDark),
      ),
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: barBg,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            if (index == 0) {
              if (_selectedIndex == 0) {
                _scrollHomeToTop();
                return;
              }
              setState(() => _selectedIndex = 0);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollHomeToTop();
              });
              return;
            }
            setState(() => _selectedIndex = index);
          },
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
              label: _tr(en: 'Map', ms: 'Peta', zh: '地图'),
              icon: Icons.map_outlined,
              selectedIcon: Icons.map,
            ),
            _buildNavDestination(
              label: _tr(en: 'Notifications', ms: 'Notifikasi', zh: '通知'),
              icon: Icons.notifications_none_rounded,
              selectedIcon: Icons.notifications_rounded,
            ),
            _buildNavDestination(
              label: _tr(en: 'Profile', ms: 'Profil', zh: '个人'),
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
            ),
            if (kIsWeb)
              _buildNavDestination(
                label: _tr(en: 'Admin', ms: 'Admin', zh: '管理'),
                icon: Icons.admin_panel_settings_outlined,
                selectedIcon: Icons.admin_panel_settings,
              ),
          ],
        ),
      ),
    );
  }
}
