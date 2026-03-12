import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:disaster_resilience_ai/models/report_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/services/weather_service.dart';
import 'package:disaster_resilience_ai/ui/submit_report_page.dart';
import 'package:disaster_resilience_ai/ui/location_news_page.dart';
import 'package:disaster_resilience_ai/ui/family_checkin_page.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key, required this.accessToken});

  final String accessToken;

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  final ApiService _api = ApiService();
  final WeatherService _weather = WeatherService();
  List<Report> _reports = [];
  bool _loading = true;
  String? _error;
  double _userLat = 3.8077;
  double _userLon = 103.3260;
  double _currentLat = 3.8077;
  double _currentLon = 103.3260;
  String _locationName = 'My Location';
  bool _isCurrentLocation = true;

  // Safety banner — shown when a flood report is within 10km
  List<dynamic> _nearbyFloodReports = [];
  String? _myCheckinStatus; // 'safe' | 'needs_help' | null
  bool _checkinLoading = false;

  // ── Theme helpers ──────────────────────────────────────────────────────────
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bg          => _isDark ? const Color(0xFF0F140F) : const Color(0xFFF0F2F5);
  Color get _card        => _isDark ? const Color(0xFF1B251B) : Colors.white;
  Color get _cardBorder  => _isDark ? const Color(0xFF334236) : const Color(0xFFE2E8F0);
  Color get _textPrimary => _isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B);
  Color get _textSub     => _isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;
  Color get _textMuted   => _isDark ? const Color(0xFF64748B) : Colors.grey.shade400;
  Color get _inputFill   => _isDark ? const Color(0xFF1E2720) : const Color(0xFFF8F9FA);

  static const Color _green = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm != LocationPermission.deniedForever &&
            perm != LocationPermission.denied) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.medium),
          );
          _userLat = pos.latitude;
          _userLon = pos.longitude;
          _currentLat = pos.latitude;
          _currentLon = pos.longitude;
          final name = await _weather.fetchLocationName(
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
          if (mounted && name != null) {
            setState(() => _locationName = name);
          }
        }
      }
    } catch (_) {}
    if (mounted) _fetchReports();
  }

  Future<void> _fetchReports() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchNearbyReports(
        accessToken: widget.accessToken,
        latitude: _userLat,
        longitude: _userLon,
        radiusKm: 50,
        statusFilter: 'validated',
      );
      final list = ReportList.fromJson(data);
      if (mounted) {
        setState(() {
          _reports = list.reports;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
    _checkNearbyFloods();
  }

  Future<void> _checkNearbyFloods() async {
    try {
      final data = await _api.fetchNearbyReports(
        accessToken: widget.accessToken,
        latitude: _currentLat,
        longitude: _currentLon,
        radiusKm: 10.0,
        statusFilter: 'validated',
      );
      final all = (data['reports'] as List<dynamic>? ?? []);
      final floods = all.where((r) => (r as Map)['report_type'] == 'flood').toList();
      if (mounted) setState(() { _nearbyFloodReports = floods; });
    } catch (_) {}
  }

  Future<void> _selfCheckin(String status) async {
    if (_checkinLoading) return;
    setState(() { _checkinLoading = true; });
    try {
      await _api.selfCheckin(accessToken: widget.accessToken, status: status);
      if (mounted) {
        setState(() { _myCheckinStatus = status; _checkinLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'safe'
              ? 'Status updated: You are SAFE. Your family has been notified.'
              : 'Status updated: DANGER reported. Your family and admin have been notified.'),
          backgroundColor: status == 'safe' ? Colors.green.shade700 : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() { _checkinLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  int get _activeCount   => _reports.length;
  int get _resolvedCount => _reports.where((r) => r.status == 'resolved').length;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SubmitReportPage(accessToken: widget.accessToken),
            ),
          );
          _fetchReports();
        },
        backgroundColor: _green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Report',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchReports,
        color: _green,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────────
              Text(
                'Community Reports',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Real-time situational awareness from your community',
                style: TextStyle(color: _textSub, fontSize: 14),
              ),
              const SizedBox(height: 16),

              // ── Location bar ────────────────────────────────────────────
              GestureDetector(
                onTap: _showLocationSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardBorder),
                    boxShadow: _isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 18, color: _green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationName,
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_isCurrentLocation) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Custom',
                              style: TextStyle(
                                  color: _green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      const SizedBox(width: 4),
                      Text('Change',
                          style: TextStyle(color: _textMuted, fontSize: 12)),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right,
                          size: 16, color: _textMuted),
                    ],
                  ),
                ),
              ),

              if (!_isCurrentLocation) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _userLat = _currentLat;
                      _userLon = _currentLon;
                      _isCurrentLocation = true;
                    });
                    _weather
                        .fetchLocationName(
                            latitude: _currentLat, longitude: _currentLon)
                        .then((name) {
                      if (mounted) {
                        setState(() => _locationName = name ?? 'My Location');
                      }
                    });
                    _fetchReports();
                  },
                  child: Row(
                    children: [
                      Icon(Icons.my_location, size: 13, color: _textMuted),
                      const SizedBox(width: 4),
                      Text('Reset to my location',
                          style:
                              TextStyle(color: _textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // ── Safety self-checkin banner (shown when a flood is within 10km) ─
              if (_nearbyFloodReports.isNotEmpty) _buildSafetyBanner(),

              // ── Stats row ───────────────────────────────────────────────
              Row(
                children: [
                  _buildStatCard(
                    '$_activeCount',
                    'Verified\nReports',
                    _green,
                    _isDark
                        ? const Color(0xFF1A2D1A)
                        : const Color(0xFFE8F5E9),
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    '$_resolvedCount',
                    'Resolved\nToday',
                    _textSub,
                    _isDark
                        ? const Color(0xFF1A1F1A)
                        : Colors.grey.shade100,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Results count ───────────────────────────────────────────
              if (!_loading && _error == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${_reports.length} verified report${_reports.length == 1 ? '' : 's'} near you',
                    style: TextStyle(
                        color: _textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),

              // ── Disaster overview banner ────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocationNewsPage(
                      locationName: _locationName,
                      latitude: _userLat,
                      longitude: _userLon,
                      accessToken: widget.accessToken,
                    ),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.map_outlined,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Full Disaster Overview',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            Text(
                              'Warnings, reports & news for $_locationName',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),

              // ── Live feed label ─────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.circle, color: Colors.red, size: 10),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE FEED',
                    style: TextStyle(
                      color: Colors.red[_isDark ? 300 : 600],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Report list ─────────────────────────────────────────────
              _buildBody(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ── Safety self-checkin banner ─────────────────────────────────────────────

  Widget _buildSafetyBanner() {
    final flood = _nearbyFloodReports.first as Map<String, dynamic>;
    final location = flood['location_name'] as String? ?? 'nearby area';
    final distKm = flood['distance_km'] as num?;
    final distText = distKm != null ? ' (${distKm.toStringAsFixed(1)} km)' : '';

    final alreadyChecked = _myCheckinStatus != null;
    final isSafe = _myCheckinStatus == 'safe';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alreadyChecked
            ? (isSafe
                ? (_isDark ? const Color(0xFF14291A) : Colors.green.shade50)
                : (_isDark ? const Color(0xFF2A1010) : Colors.red.shade50))
            : (_isDark ? const Color(0xFF2A1A0A) : Colors.orange.shade50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alreadyChecked
              ? (isSafe ? Colors.green.shade400 : Colors.red.shade400)
              : Colors.orange.shade400,
          width: 1.5,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            alreadyChecked
                ? (isSafe ? Icons.check_circle : Icons.warning_rounded)
                : Icons.water_damage,
            color: alreadyChecked ? (isSafe ? Colors.green : Colors.red) : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alreadyChecked
                  ? (isSafe ? 'You reported: SAFE' : 'You reported: NEED HELP')
                  : 'Flood confirmed near $location$distText',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: alreadyChecked
                    ? (isSafe
                        ? (_isDark ? Colors.green.shade300 : Colors.green.shade800)
                        : (_isDark ? Colors.red.shade300 : Colors.red.shade800))
                    : (_isDark ? Colors.orange.shade300 : Colors.orange.shade900),
              ),
            ),
          ),
          if (_nearbyFloodReports.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade600,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_nearbyFloodReports.length}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
        ]),
        if (!alreadyChecked) ...[
          const SizedBox(height: 8),
          Text(
            'Are you safe? Confirm your status — your family and the admin will be notified.',
            style: TextStyle(
              fontSize: 12,
              color: _isDark ? Colors.orange.shade200 : Colors.orange.shade800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _checkinLoading
                  ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : ElevatedButton.icon(
                      onPressed: () => _selfCheckin('safe'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text("I'm SAFE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _checkinLoading
                  ? const SizedBox.shrink()
                  : ElevatedButton.icon(
                      onPressed: () => _selfCheckin('needs_help'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.warning_rounded, size: 16),
                      label: const Text('I Need Help', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
            ),
          ]),
        ] else ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text(
                'Your family has been notified. Tap to update your status.',
                style: TextStyle(
                  fontSize: 11,
                  color: _isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() { _myCheckinStatus = null; }),
              child: Text(
                'Change',
                style: TextStyle(
                  fontSize: 11,
                  color: _isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => FamilyCheckinPage(accessToken: widget.accessToken),
              )),
              child: Text(
                'View Family',
                style: TextStyle(
                  fontSize: 11,
                  color: _isDark ? Colors.green.shade300 : Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  // ── Location search bottom sheet ───────────────────────────────────────────

  void _showLocationSheet() {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          Future<void> doSearch(String q) async {
            if (q.trim().isEmpty) {
              setSheetState(() {
                results = [];
                searching = false;
              });
              return;
            }
            setSheetState(() => searching = true);
            final found = await _weather.searchLocation(q);
            setSheetState(() {
              results = found;
              searching = false;
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _isDark
                          ? const Color(0xFF334236)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Choose Location',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Search field
                TextField(
                  controller: searchController,
                  autofocus: true,
                  style: TextStyle(color: _textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search city or state in Malaysia...',
                    hintStyle: TextStyle(color: _textMuted),
                    prefixIcon:
                        const Icon(Icons.search, color: _green),
                    suffixIcon: searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _green,
                              ),
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: _inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _green, width: 1.5),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) {
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (searchController.text == v) doSearch(v);
                    });
                  },
                ),
                const SizedBox(height: 8),

                // Use current location
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.my_location,
                        color: _green, size: 18),
                  ),
                  title: Text(
                    'Use my current location',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: _textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    setState(() {
                      _userLat = _currentLat;
                      _userLon = _currentLon;
                      _isCurrentLocation = true;
                    });
                    _weather
                        .fetchLocationName(
                            latitude: _currentLat,
                            longitude: _currentLon)
                        .then((name) {
                      if (mounted) {
                        setState(
                            () => _locationName = name ?? 'My Location');
                      }
                    });
                    _fetchReports();
                  },
                ),

                if (results.isNotEmpty) ...[
                  Divider(
                      height: 1,
                      color: _isDark
                          ? const Color(0xFF334236)
                          : Colors.grey.shade200),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final r = results[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 2),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isDark
                                  ? const Color(0xFF1E2720)
                                  : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.location_on_outlined,
                                color: _textSub, size: 18),
                          ),
                          title: Text(
                            r['name'] as String,
                            style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: _textPrimary),
                          ),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            setState(() {
                              _userLat = r['lat'] as double;
                              _userLon = r['lon'] as double;
                              _locationName = r['name'] as String;
                              _isCurrentLocation = false;
                            });
                            _fetchReports();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        });
      },
    );
  }

  // ── Body states ────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: CircularProgressIndicator(color: _green),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.wifi_off, size: 48, color: _textMuted),
              const SizedBox(height: 12),
              Text(
                'Could not load reports',
                style: TextStyle(
                    color: _textSub, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 48,
                  color: _isDark
                      ? const Color(0xFF4CAF50)
                      : Colors.green.shade300),
              const SizedBox(height: 12),
              Text(
                'No reports in your area',
                style: TextStyle(
                    color: _textSub, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Pull to refresh or submit one if you see something.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: _reports.map(_buildReportItem).toList());
  }

  // ── Report card ────────────────────────────────────────────────────────────

  Widget _buildReportItem(Report report) {
    final typeIcon  = _iconFor(report.reportType);
    final typeColor = _colorFor(report.reportType);
    final timeAgo   = _timeAgo(report.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: _isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: _isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(typeIcon, color: typeColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${report.typeLabel} — ${report.locationName}',
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  report.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: _textSub, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 13, color: _textMuted),
                    const SizedBox(width: 4),
                    Text(timeAgo,
                        style:
                            TextStyle(color: _textMuted, fontSize: 11)),
                    if (report.distanceKm != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.near_me,
                          size: 13, color: _textMuted),
                      const SizedBox(width: 2),
                      Text(
                        '${report.distanceKm!.toStringAsFixed(1)} km',
                        style: TextStyle(
                            color: _textMuted, fontSize: 11),
                      ),
                    ],
                    if (report.vulnerablePerson) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.priority_high,
                          size: 13,
                          color: _isDark
                              ? Colors.red.shade300
                              : Colors.red.shade400),
                      Text(
                        'Priority',
                        style: TextStyle(
                            color: _isDark
                                ? Colors.red.shade300
                                : Colors.red.shade400,
                            fontSize: 11),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                _buildStatusBadge(report.status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Status badge ───────────────────────────────────────────────────────────

  Widget _buildStatusBadge(String status) {
    final (icon, fg, bg, label) = switch (status) {
      'validated' => (
          Icons.verified,
          _isDark ? const Color(0xFF4CAF50) : Colors.green.shade700,
          _isDark ? const Color(0xFF1A2D1A) : Colors.green.shade50,
          'Verified',
        ),
      'resolved' => (
          Icons.check_circle,
          _textSub,
          _isDark ? const Color(0xFF1A1F1A) : Colors.grey.shade100,
          'Resolved',
        ),
      _ => (
          Icons.hourglass_top,
          _isDark ? Colors.orange.shade300 : Colors.orange.shade700,
          _isDark ? const Color(0xFF2A1F0F) : Colors.orange.shade50,
          'Pending Review',
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  color: fg,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Stat card ──────────────────────────────────────────────────────────────

  Widget _buildStatCard(
      String count, String label, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  IconData _iconFor(String type) => switch (type) {
        'flood'             => Icons.water_drop,
        'blocked_road'      => Icons.block,
        'landslide'         => Icons.landscape,
        'medical_emergency' => Icons.medical_services_rounded,
        _                   => Icons.warning_amber_rounded,
      };

  Color _colorFor(String type) => switch (type) {
        'flood'             => Colors.blue.shade700,
        'blocked_road'      => Colors.orange.shade700,
        'landslide'         => Colors.brown.shade700,
        'medical_emergency' => Colors.red.shade700,
        _                   => Colors.grey.shade600,
      };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
