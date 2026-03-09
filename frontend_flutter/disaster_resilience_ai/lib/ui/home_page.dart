import 'package:flutter/material.dart';

import 'package:disaster_resilience_ai/models/warning_model.dart';
import 'package:disaster_resilience_ai/models/weather_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/services/weather_service.dart';
import 'package:disaster_resilience_ai/ui/auth_page.dart';
import 'package:disaster_resilience_ai/ui/emergency_alert_page.dart';
import 'package:disaster_resilience_ai/ui/submit_report_page.dart';
import 'package:disaster_resilience_ai/ui/school_preparedness_page.dart';
import 'package:disaster_resilience_ai/ui/safe_routes_page.dart';
import 'package:disaster_resilience_ai/ui/emergency_contacts_page.dart';
import 'package:disaster_resilience_ai/ui/reports_tab.dart';
import 'package:disaster_resilience_ai/ui/map_tab.dart';
import 'package:disaster_resilience_ai/ui/profile_tab.dart';
import 'package:disaster_resilience_ai/ui/weather_page.dart';
import 'package:disaster_resilience_ai/ui/chatbot_page.dart';
import 'package:disaster_resilience_ai/models/disaster_news_model.dart';
import 'package:disaster_resilience_ai/ui/all_warnings_page.dart';
import 'package:disaster_resilience_ai/ui/all_news_page.dart';
import 'package:disaster_resilience_ai/services/notification_service.dart';
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
    _startNotificationPolling();
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

  /// Get status display props based on alert level.
  _StatusDisplay get _statusDisplay {
    if (_nearbyWarnings.isEmpty) {
      return _StatusDisplay(
        icon: Icons.check_circle_outline,
        label: 'Risk Status: LOW',
        subtitle: 'Your community is currently safe',
        gradientColors: [const Color(0xFF4CAF50), const Color(0xFF2E7D32)],
        buttonLabel: 'VIEW ALL WARNINGS (${_allActiveWarnings.length})',
      );
    }

    final level = _highestAlertLevel;
    switch (level) {
      case AlertLevel.advisory:
        return _StatusDisplay(
          icon: Icons.info_outline,
          label: 'Risk Status: ADVISORY',
          subtitle: '${_nearbyWarnings.length} advisory notice(s) in your area',
          gradientColors: [Colors.blue[400]!, Colors.blue[700]!],
          buttonLabel: 'VIEW ADVISORIES',
        );
      case AlertLevel.observe:
        return _StatusDisplay(
          icon: Icons.visibility_outlined,
          label: 'Risk Status: OBSERVE',
          subtitle:
              '${_nearbyWarnings.length} warning(s) — monitor conditions closely',
          gradientColors: [Colors.amber[600]!, Colors.orange[700]!],
          buttonLabel: 'VIEW WARNINGS',
        );
      case AlertLevel.warning:
        return _StatusDisplay(
          icon: Icons.warning_amber_rounded,
          label: 'Risk Status: WARNING',
          subtitle: '${_nearbyWarnings.length} active warning(s) near you',
          gradientColors: [Colors.orange[600]!, Colors.deepOrange[700]!],
          buttonLabel: 'VIEW EMERGENCY DETAILS',
        );
      case AlertLevel.evacuate:
        return _StatusDisplay(
          icon: Icons.directions_run,
          label: 'EVACUATE NOW',
          subtitle: 'Immediate evacuation recommended',
          gradientColors: [Colors.red[600]!, Colors.red[900]!],
          buttonLabel: 'VIEW EVACUATION DETAILS',
        );
    }
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

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _fetchWarnings,
      color: const Color(0xFF2E7D32),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreetingBanner(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildStatusCard(),
                  const SizedBox(height: 24),
                  // ── Active Warnings section (max 3) ──────────────────
                  _buildSectionHeader(
                    'Active Warnings',
                    _allActiveWarnings.isEmpty
                        ? null
                        : 'View All (${_allActiveWarnings.length})',
                    _allActiveWarnings.isEmpty
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AllWarningsPage(warnings: _allActiveWarnings),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  _buildWarningsSection(),
                  const SizedBox(height: 24),
                  // ── Disaster News & Info section (max 3) ─────────────
                  _buildSectionHeader(
                    'Disaster News & Info',
                    'View All',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AllNewsPage()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildNewsSection(),
                  const SizedBox(height: 24),
                  // ── Quick Actions ─────────────────────────────────────
                  _buildSectionHeader('Quick Actions', null, null),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      _buildActionCard(
                        icon: Icons.campaign_outlined,
                        title: 'Community\nReport',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubmitReportPage(),
                          ),
                        ),
                      ),
                      _buildActionCard(
                        icon: Icons.school_outlined,
                        title: 'School\nRegistry',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SchoolPreparednessPage(),
                          ),
                        ),
                      ),
                      _buildActionCard(
                        icon: Icons.directions_run,
                        title: 'Safe Routes',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SafeRoutesPage(),
                          ),
                        ),
                      ),
                      _buildActionCard(
                        icon: Icons.phone_outlined,
                        title: 'Emergency\nContacts',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EmergencyContactsPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingBanner() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: const BoxDecoration(color: Color(0xFFF1F8E9)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, ${widget.username} 👋',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Stay informed. Stay safe.',
            style: TextStyle(fontSize: 13, color: Color(0xFF4CAF50)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String? actionLabel,
    VoidCallback? onAction,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWarningsSection() {
    if (_loadingWarnings) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(
            color: Color(0xFF2E7D32),
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (_warningError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange[700], size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Could not fetch warnings. Pull down to retry.',
                style: TextStyle(color: Colors.orange[800], fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    if (_nearbyWarnings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F8E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC8E6C9)),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Color(0xFF4CAF50),
              size: 28,
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active warnings',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                Text(
                  'Your area is currently safe',
                  style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      );
    }
    final shown = _nearbyWarnings.take(3).toList();
    return Column(children: shown.map(_buildWarningTile).toList());
  }

  Widget _buildNewsSection() {
    final news = DisasterNewsData.articles.take(3).toList();
    return Column(children: news.map(_buildNewsTile).toList());
  }

  Widget _buildNewsTile(DisasterNews article) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NewsDetailPage(article: article)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E0E0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: article.accentColor.withAlpha(28),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(article.icon, color: article.accentColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${article.category} · ${article.readMinutes} min read',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    if (_loadingWarnings) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Checking area status...',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_warningError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'CURRENT STATUS',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unable to check warnings',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Backend unreachable — pull to refresh',
              style: TextStyle(
                color: Colors.white.withAlpha(178),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _fetchWarnings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'RETRY',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final status = _statusDisplay;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: status.gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: Icon(status.icon, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'CURRENT STATUS',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_nearbyWarnings.isNotEmpty) {
                  // Navigate to emergency alert page with the most severe warning
                  final mostSevere = _nearbyWarnings.reduce(
                    (a, b) =>
                        a.alertLevel.severityIndex > b.alertLevel.severityIndex
                        ? a
                        : b,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EmergencyAlertPage(warning: mostSevere),
                    ),
                  );
                } else {
                  // Show all active warnings page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmergencyAlertPage(),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: status.gradientColors.last,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                status.buttonLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningTile(Warning warning) {
    final Color tileColor;
    final Color borderColor;
    final Color iconColor;
    final IconData icon;

    switch (warning.alertLevel) {
      case AlertLevel.evacuate:
        tileColor = Colors.red[50]!;
        borderColor = Colors.red[300]!;
        iconColor = Colors.red[700]!;
        icon = Icons.directions_run;
        break;
      case AlertLevel.warning:
        tileColor = Colors.orange[50]!;
        borderColor = Colors.orange[300]!;
        iconColor = Colors.orange[700]!;
        icon = Icons.warning_amber_rounded;
        break;
      case AlertLevel.observe:
        tileColor = Colors.amber[50]!;
        borderColor = Colors.amber[300]!;
        iconColor = Colors.amber[700]!;
        icon = Icons.visibility_outlined;
        break;
      case AlertLevel.advisory:
        tileColor = Colors.blue[50]!;
        borderColor = Colors.blue[200]!;
        iconColor = Colors.blue[700]!;
        icon = Icons.info_outline;
        break;
    }

    final timeAgo = _timeAgo(warning.createdAt);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmergencyAlertPage(warning: warning),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    warning.title,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${warning.hazardType.displayName} • ${warning.alertLevel.displayName} • $timeAgo',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: iconColor),
          ],
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

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC8E6C9), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFC8E6C9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF2E7D32), size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1B5E20),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
    IconData icon,
    IconData activeIcon,
    String label,
    int index,
  ) {
    final isSelected = _selectedIndex == index;
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? const Color(0xFF2E7D32) : Colors.grey,
        ),
      ),
      label: label,
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF2E7D32)),
          onPressed: () {},
        ),
        title: const Text(
          'Resilience AI',
          style: TextStyle(
            color: Color(0xFF2E7D32),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // ── Weather mini-widget ─────────────────────────────────────────
          GestureDetector(
            onTap: () {
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
            },
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _weather?.icon ?? Icons.cloud_outlined,
                    color: const Color(0xFF2E7D32),
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _weather != null
                        ? '${_weather!.temperature.round()}°C'
                        : '--°C',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
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
                  setState(() => _selectedIndex = 3);
                },
              ),
            ),
          ),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF2E7D32),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
          items: [
            _buildNavItem(Icons.home_outlined, Icons.home, 'Home', 0),
            _buildNavItem(
              Icons.insert_chart_outlined,
              Icons.insert_chart,
              'Reports',
              1,
            ),
            _buildNavItem(Icons.map_outlined, Icons.map, 'Map', 2),
            _buildNavItem(Icons.person_outline, Icons.person, 'Profile', 3),
          ],
        ),
      ),
    );
  }
}

/// Helper class for status card display properties.
class _StatusDisplay {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradientColors;
  final String buttonLabel;

  const _StatusDisplay({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradientColors,
    required this.buttonLabel,
  });
}
