import 'package:flutter/material.dart';

import 'package:disaster_resilience_ai/models/warning_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/ui/auth_page.dart';
import 'package:disaster_resilience_ai/ui/emergency_alert_page.dart';
import 'package:disaster_resilience_ai/ui/submit_report_page.dart';
import 'package:disaster_resilience_ai/ui/school_preparedness_page.dart';
import 'package:disaster_resilience_ai/ui/safe_routes_page.dart';
import 'package:disaster_resilience_ai/ui/emergency_contacts_page.dart';
import 'package:disaster_resilience_ai/ui/reports_tab.dart';
import 'package:disaster_resilience_ai/ui/map_tab.dart';
import 'package:disaster_resilience_ai/ui/profile_tab.dart';
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

  // ── Warning state ────────────────────────────────────────────────────────
  bool _loadingWarnings = true;
  List<Warning> _nearbyWarnings = [];
  List<Warning> _allActiveWarnings = [];
  String? _warningError;

  // Default location: Kuantan, Pahang, Malaysia (the concept doc location)
  final double _userLat = 3.8077;
  final double _userLon = 103.3260;

  @override
  void initState() {
    super.initState();
    _fetchWarnings();
    _updateBackendLocation();
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
      (prev, w) => w.alertLevel.severityIndex > prev.severityIndex ? w.alertLevel : prev,
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
          subtitle: '${_nearbyWarnings.length} warning(s) — monitor conditions closely',
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
    return RefreshIndicator(
      onRefresh: _fetchWarnings,
      color: const Color(0xFF2E7D32),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Status Card — live from backend
              _buildStatusCard(),
              const SizedBox(height: 16),
              // Active Warning Tiles (if any)
              if (_nearbyWarnings.isNotEmpty) ...[
                const Text(
                  'Active Warnings Near You',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                ..._nearbyWarnings.map(_buildWarningTile),
                const SizedBox(height: 16),
              ],
              // Quick Actions Title
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              // Quick Actions Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildActionCard(
                    icon: Icons.campaign_outlined,
                    title: 'Community\nReport',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SubmitReportPage()),
                      );
                    },
                  ),
                  _buildActionCard(
                    icon: Icons.school_outlined,
                    title: 'School\nRegistry',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SchoolPreparednessPage()),
                      );
                    },
                  ),
                  _buildActionCard(
                    icon: Icons.directions_run,
                    title: 'Safe Routes',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SafeRoutesPage()),
                      );
                    },
                  ),
                  _buildActionCard(
                    icon: Icons.phone_outlined,
                    title: 'Emergency\nContacts',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EmergencyContactsPage()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
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
              child: const Icon(
                Icons.wifi_off,
                color: Colors.white,
                size: 40,
              ),
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
            child: Icon(
              status.icon,
              color: Colors.white,
              size: 40,
            ),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_nearbyWarnings.isNotEmpty) {
                  // Navigate to emergency alert page with the most severe warning
                  final mostSevere = _nearbyWarnings.reduce(
                    (a, b) => a.alertLevel.severityIndex > b.alertLevel.severityIndex ? a : b,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmergencyAlertPage(warning: mostSevere),
                    ),
                  );
                } else {
                  // Show all active warnings page
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EmergencyAlertPage()),
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
              child: Icon(
                icon,
                color: const Color(0xFF2E7D32),
                size: 32,
              ),
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

  BottomNavigationBarItem _buildNavItem(IconData icon, IconData activeIcon, String label, int index) {
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
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: const Color(0xFFE8F5E9),
              child: IconButton(
                icon: const Icon(Icons.person_outline, color: Color(0xFF2E7D32)),
                onPressed: _logout,
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
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
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          items: [
            _buildNavItem(Icons.home_outlined, Icons.home, 'Home', 0),
            _buildNavItem(Icons.insert_chart_outlined, Icons.insert_chart, 'Reports', 1),
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
