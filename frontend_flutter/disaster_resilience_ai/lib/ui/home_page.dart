import 'package:flutter/material.dart';

import 'package:disaster_resilience_ai/models/warning_model.dart';
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
import 'package:disaster_resilience_ai/models/disaster_news_model.dart';
import 'package:disaster_resilience_ai/ui/all_warnings_page.dart';
import 'package:disaster_resilience_ai/ui/all_news_page.dart';
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

  @override
  void initState() {
    super.initState();
    _determineLocation();
  }

  /// Fetch the device's real GPS location, then kick off data fetches.
  Future<void> _determineLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          ).timeout(const Duration(seconds: 10));
          if (mounted) {
            setState(() {
              _userLat = position.latitude;
              _userLon = position.longitude;
              _locationLabel =
                  '${position.latitude.toStringAsFixed(4)}°N, ${position.longitude.toStringAsFixed(4)}°E';
            });
          }
        } else {
          if (mounted) setState(() => _locationLabel = 'Kuantan, Pahang');
        }
      } else {
        if (mounted) setState(() => _locationLabel = 'Kuantan, Pahang');
      }
    } catch (_) {
      // GPS unavailable — keep fallback coordinates
      if (mounted) setState(() => _locationLabel = 'Kuantan, Pahang');
    }
    _fetchWarnings();
    _updateBackendLocation();
    _fetchWeather();
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
    final isLoaded = !_loadingWarnings;
    final hasError = _warningError != null;
    final hazards = hasError ? 0 : _nearbyWarnings.length;

    final String safetyLabel;
    final Color safetyColor;
    final IconData safetyIcon;

    if (!isLoaded) {
      safetyLabel = 'Checking';
      safetyColor = const Color(0xFF2D5927);
      safetyIcon = Icons.hourglass_top_rounded;
    } else if (hasError) {
      safetyLabel = 'Unknown';
      safetyColor = const Color(0xFF6B7280);
      safetyIcon = Icons.wifi_off_rounded;
    } else if (_nearbyWarnings.isEmpty) {
      safetyLabel = 'Secure';
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
            const Expanded(
              child: Text(
                'Your Status',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
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
                backgroundColor: const Color(0xFF2D5927).withAlpha(16),
                foregroundColor: const Color(0xFF2D5927),
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
                      const Text(
                        'Safety Status',
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF2D5927).withAlpha(32),
                    ),
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
                        'Active Hazards',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        !isLoaded
                            ? 'Checking'
                            : hazards > 0
                            ? '$hazards Nearby'
                            : 'None',
                        style: const TextStyle(
                          color: Color(0xFF111827),
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
    final hasWeather = _weather != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openWeatherPage,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2D5927).withAlpha(28)),
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
                        color: const Color(0xFF2D5927).withAlpha(16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        hasWeather
                            ? _weather!.icon
                            : Icons.thunderstorm_outlined,
                        color: const Color(0xFF2D5927),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasWeather
                                ? 'Local Weather: ${_weather!.description}'
                                : 'Local Weather Update',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasWeather
                                ? 'Heavy rainfall risk can shift quickly. Check your nearest safe route now.'
                                : 'Pull down to refresh the latest weather status for your location.',
                            style: TextStyle(
                              color: Colors.grey[700],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
          children: [
            _buildPrimaryActionChip(
              icon: Icons.map_outlined,
              label: 'Maps',
              onPressed: () => setState(() => _selectedIndex = 2),
            ),
            _buildPrimaryActionChip(
              icon: Icons.assignment_outlined,
              label: 'Plan',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SchoolPreparednessPage(),
                ),
              ),
            ),
            _buildPrimaryActionChip(
              icon: Icons.medical_services_outlined,
              label: 'First Aid',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EmergencyContactsPage(),
                ),
              ),
            ),
            _buildPrimaryActionChip(
              icon: Icons.sos_outlined,
              label: 'SOS',
              onPressed: _openEmergencyDetails,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2D5927).withAlpha(16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFF2D5927)),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityFeedSection() {
    final warnings = _nearbyWarnings.take(1).toList();
    final news = DisasterNewsData.articles.take(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Community Feed',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllNewsPage()),
              ),
              child: const Text(
                'View All',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingWarnings && warnings.isEmpty)
          _buildFeedCard(
            source: 'Resilience AI',
            meta: 'Updating • $_locationLabel',
            message: 'Fetching live community updates for your area.',
            onTap: _fetchWarnings,
          ),
        if (_warningError != null && warnings.isEmpty)
          _buildFeedCard(
            source: 'Resilience AI',
            meta: 'Connection issue • $_locationLabel',
            message:
                'Unable to load warning feed right now. Pull down to retry.',
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
    final initial = source.isEmpty ? 'R' : source[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2D5927).withAlpha(30)),
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
                        color: const Color(0xFF2D5927).withAlpha(20),
                      ),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Color(0xFF2D5927),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: TextStyle(color: Colors.grey[800], height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
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
    const Color navPrimary = Color(0xFF2D5927);
    return NavigationDestination(
      label: label,
      icon: Icon(icon),
      selectedIcon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: navPrimary.withAlpha(18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selectedIcon, size: 24, color: navPrimary),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: navPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F6),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF6F7F6),
        surfaceTintColor: colorScheme.surfaceTint,
        scrolledUnderElevation: 1,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        toolbarHeight: 64,
        title: Text(
          'Resilience AI',
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFF2D5927).withAlpha(26),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Warnings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AllWarningsPage(warnings: _allActiveWarnings),
              ),
            ),
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
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
          IconButton(
            tooltip: 'Browse News',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllNewsPage()),
            ),
            icon: const Icon(Icons.search_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatbotPage()),
          );
        },
        backgroundColor: const Color(0xFF2E7D32),
        tooltip: 'Disaster Assistant',
        child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        indicatorColor: Colors.transparent,
        shadowColor: colorScheme.shadow.withAlpha(32),
        elevation: 4,
        destinations: [
          _buildNavDestination(
            label: 'Home',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
          ),
          _buildNavDestination(
            label: 'Reports',
            icon: Icons.insert_chart_outlined,
            selectedIcon: Icons.insert_chart,
          ),
          _buildNavDestination(
            label: 'Map',
            icon: Icons.map_outlined,
            selectedIcon: Icons.map,
          ),
          _buildNavDestination(
            label: 'Profile',
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
          ),
        ],
      ),
    );
  }
}
