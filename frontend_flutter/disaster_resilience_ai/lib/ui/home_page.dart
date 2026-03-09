import 'dart:ui' as ui;

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
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _fetchWarnings,
      color: colorScheme.primary,
      child: Stack(
        children: [
          Positioned(
            top: -140,
            right: -80,
            child: _softOrb(colorScheme.primary.withAlpha(32), 260),
          ),
          Positioned(
            top: 220,
            left: -90,
            child: _softOrb(colorScheme.tertiary.withAlpha(24), 220),
          ),
          SingleChildScrollView(
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
                      const SizedBox(height: 12),
                      _buildPrimaryActions(),
                      const SizedBox(height: 20),
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
                                  builder: (_) => AllWarningsPage(
                                    warnings: _allActiveWarnings,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      _buildWarningsSection(),
                      const SizedBox(height: 20),
                      // ── Disaster News & Info section (max 3) ─────────────
                      _buildSectionHeader(
                        'Disaster News & Info',
                        'View All',
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AllNewsPage(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildNewsSection(),
                      const SizedBox(height: 20),
                      // ── Quick Actions ─────────────────────────────────────
                      _buildSectionHeader('Preparedness Tools', null, null),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.1,
                        children: [
                          _buildActionCard(
                            icon: Icons.campaign_outlined,
                            title: 'Community Report',
                            subtitle: 'Submit local updates',
                            accentColor: Colors.orange,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SubmitReportPage(),
                              ),
                            ),
                          ),
                          _buildActionCard(
                            icon: Icons.school_outlined,
                            title: 'School Registry',
                            subtitle: 'Track school readiness',
                            accentColor: Colors.indigo,
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
                            subtitle: 'Fastest evacuation path',
                            accentColor: Colors.green,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SafeRoutesPage(),
                              ),
                            ),
                          ),
                          _buildActionCard(
                            icon: Icons.phone_outlined,
                            title: 'Emergency Contacts',
                            subtitle: 'Critical numbers nearby',
                            accentColor: Colors.red,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EmergencyContactsPage(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(145),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(170)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(120),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    'LIVE MONITORING',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$greeting, ${widget.username} 👋',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your community resilience command center',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(120),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.wifi_tethering_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 4),
                Text(
                  'Online',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel),
          ),
      ],
    );
  }

  Widget _buildPrimaryActions() {
    final colorScheme = Theme.of(context).colorScheme;

    return _glassSurface(
      padding: const EdgeInsets.all(10),
      borderRadius: 18,
      border: Border.all(color: colorScheme.outlineVariant.withAlpha(120)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildPrimaryActionChip(
              icon: Icons.notifications_active_outlined,
              label: 'Alerts',
              onPressed: () {
                if (_nearbyWarnings.isNotEmpty) {
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmergencyAlertPage(),
                    ),
                  );
                }
              },
              filled: true,
            ),
            const SizedBox(width: 8),
            _buildPrimaryActionChip(
              icon: Icons.alt_route,
              label: 'Safe Route',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SafeRoutesPage()),
              ),
            ),
            const SizedBox(width: 8),
            _buildPrimaryActionChip(
              icon: Icons.edit_note,
              label: 'Report',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubmitReportPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool filled = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);

    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: colorScheme.onSurface,
      side: BorderSide(color: colorScheme.outlineVariant),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: textStyle,
    );

    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textStyle,
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: buttonStyle,
    );
  }

  Widget _buildWarningsSection() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loadingWarnings) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            color: colorScheme.primary,
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
          borderRadius: BorderRadius.circular(14),
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
          borderRadius: BorderRadius.circular(14),
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
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NewsDetailPage(article: article)),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                    style: TextStyle(color: Colors.grey[700], fontSize: 11),
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
        borderRadius: BorderRadius.circular(18),
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
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: _glassSurface(
        borderRadius: 16,
        padding: const EdgeInsets.all(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(120),
          width: 1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white.withAlpha(190),
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
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () {
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
              icon: Icon(_weather?.icon ?? Icons.cloud_outlined, size: 18),
              label: Text(
                _weather != null
                    ? '${_weather!.temperature.round()}°C'
                    : '--°C',
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(175),
                foregroundColor: colorScheme.primary,
                side: BorderSide(color: Colors.white.withAlpha(165)),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        backgroundColor: Colors.white.withAlpha(190),
        indicatorColor: colorScheme.primary.withAlpha(24),
        shadowColor: colorScheme.shadow.withAlpha(24),
        elevation: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.insert_chart_outlined),
            selectedIcon: Icon(Icons.insert_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _glassSurface({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double borderRadius = 20,
    Border? border,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(122),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? Border.all(color: Colors.white.withAlpha(165)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _softOrb(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withAlpha(0)],
            stops: const [0.05, 1],
          ),
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
