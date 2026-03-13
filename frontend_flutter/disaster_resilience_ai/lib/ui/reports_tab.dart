import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:disaster_resilience_ai/localization/app_language.dart';
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
  bool _loadingLiveReports = true; // true from the start so spinner shows immediately
  String? _liveReportsError;
  List<_ReportItem> _liveItems = [];
  int _retryCount = 0;
  double _userLat = 3.8077;
  double _userLon = 103.3260;
  double _currentLat = 3.8077;
  double _currentLon = 103.3260;
  String _locationName = 'My Location';
  bool _isCurrentLocation = true;
  final Set<String> _vouchingIds = <String>{};
  Timer? _refreshTimer;
  List<Map<String, dynamic>> _nearbyFloodReports = [];
  String? _myCheckinStatus;
  bool _checkinLoading = false;

  @override
  void initState() {
    super.initState();
    // Load reports immediately with default location — don't wait for GPS
    _loadNearbyReports();
    // Fetch real location in background and refresh once ready
    _initLocation();
    // Auto-refresh every 60s so resolved/rejected reports disappear promptly
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) _loadNearbyReports();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      _userLat = pos.latitude;
      _userLon = pos.longitude;
      _currentLat = pos.latitude;
      _currentLon = pos.longitude;

      // Refresh reports with real coordinates
      _loadNearbyReports();

      final place = await _weather.fetchLocationName(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      if (mounted && place != null && place.isNotEmpty) {
        setState(() => _locationName = place);
      }
    } catch (_) {
      // GPS unavailable — keep defaults, reports already loaded above
    }
  }

  Future<void> _loadNearbyReports({bool manual = false}) async {
    if (!mounted) return;
    if (manual) _retryCount = 0; // reset backoff on manual retry
    setState(() {
      _loadingLiveReports = true;
      _liveReportsError = null;
    });

    try {
      final token = widget.accessToken;
      if (token.isEmpty) {
        if (mounted) {
          setState(() {
            _loadingLiveReports = false;
            _liveReportsError = 'Sign in required to load live reports.';
          });
        }
        return;
      }

      final payload = await _api.fetchNearbyReports(
        accessToken: token,
        latitude: _userLat,
        longitude: _userLon,
        radiusKm: 50,
        statusFilter: 'validated',
      );
      final rows = (payload['reports'] as List<dynamic>? ?? const []);
      final parsed = rows
          .whereType<Map<String, dynamic>>()
          .map(_reportItemFromApi)
          .toList();

      // Derive nearby flood reports from the same fetch — no second API call needed
      final nearbyFloods = rows
          .whereType<Map<String, dynamic>>()
          .where((r) =>
              r['report_type'] == 'flood' &&
              r['status'] == 'validated' &&
              _distanceKm(
                _currentLat, _currentLon,
                (r['latitude'] as num?)?.toDouble() ?? _currentLat,
                (r['longitude'] as num?)?.toDouble() ?? _currentLon,
              ) <= 10.0)
          .toList();

      // Restore persisted checkin status for the current nearby flood report
      String? savedCheckin;
      if (nearbyFloods.isNotEmpty) {
        final floodId = nearbyFloods.first['id']?.toString() ?? '';
        if (floodId.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          savedCheckin = prefs.getString('checkin_$floodId');
        }
      }

      if (mounted) {
        setState(() {
          _liveItems = parsed;
          _nearbyFloodReports = nearbyFloods;
          _loadingLiveReports = false;
          _retryCount = 0;
          // Only restore if user hasn't manually changed status this session
          if (savedCheckin != null && _myCheckinStatus == null) {
            _myCheckinStatus = savedCheckin;
          }
          // Clear checkin if flood is gone
          if (nearbyFloods.isEmpty) _myCheckinStatus = null;
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _loadingLiveReports = false;
          _liveReportsError = msg;
        });
        // Auto-retry up to 3 times with increasing delay (2s, 4s, 8s)
        if (_retryCount < 3) {
          _retryCount++;
          final delay = Duration(seconds: 2 * _retryCount);
          Future.delayed(delay, () {
            if (mounted && _liveReportsError != null) {
              _loadNearbyReports();
            }
          });
        }
      }
    }
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Future<void> _selfCheckin(String status) async {
    if (_checkinLoading) return;
    setState(() { _checkinLoading = true; });
    try {
      await _api.selfCheckin(accessToken: widget.accessToken, status: status);
      // Persist checkin so it survives tab rebuilds and app restarts
      if (_nearbyFloodReports.isNotEmpty) {
        final floodId = _nearbyFloodReports.first['id']?.toString() ?? '';
        if (floodId.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('checkin_$floodId', status);
        }
      }
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

  _ReportItem _reportItemFromApi(Map<String, dynamic> row) {
    final reportType = (row['report_type']?.toString() ?? '').toLowerCase();
    final status = (row['status']?.toString() ?? 'pending');
    final distanceKm = (row['distance_km'] as num?)?.toDouble();
    final createdAtRaw = row['created_at']?.toString();
    final createdAt = createdAtRaw != null
        ? DateTime.tryParse(createdAtRaw)?.toLocal()
        : null;
    final locationName = row['location_name']?.toString().trim() ?? '';
    final typeLabel = _titleForType(reportType);
    final displayTitle = locationName.isNotEmpty
        ? '$typeLabel - $locationName'
        : typeLabel;
    final mediaUrls = (row['media_urls'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final iconSet = _iconSetForType(reportType);
    final statusSet = _statusSetForStatus(status);
    return _ReportItem(
      id: row['id']?.toString(),
      title: displayTitle,
      subtitle: (row['description']?.toString().trim().isNotEmpty ?? false)
          ? row['description'].toString()
          : 'Community-submitted report',
      location: locationName.isNotEmpty ? locationName : _locationName,
      time: createdAt != null ? _timeAgo(createdAt) : 'Recently',
      distance: distanceKm != null ? '${distanceKm.toStringAsFixed(1)} km' : null,
      icon: iconSet.icon,
      iconBgLight: iconSet.iconBgLight,
      iconBgDark: iconSet.iconBgDark,
      iconColorLight: iconSet.iconColorLight,
      iconColorDark: iconSet.iconColorDark,
      status: statusSet.status,
      statusBgLight: statusSet.statusBgLight,
      statusBgDark: statusSet.statusBgDark,
      statusTextLight: statusSet.statusTextLight,
      statusTextDark: statusSet.statusTextDark,
      imageUrl: mediaUrls.isNotEmpty ? mediaUrls.first : null,
      userVouched: row['current_user_vouched'] == true,
      vouchCount: (row['vouch_count'] as num?)?.toInt() ?? 0,
      confidenceScore: (row['confidence_score'] as num?)?.toDouble(),
      vulnerablePerson: row['vulnerable_person'] == true,
    );
  }

  // ── Safety self-checkin banner (SMS feature) ──────────────────────────────

  Widget _buildSafetyBanner({bool isDark = false}) {
    if (_nearbyFloodReports.isEmpty) return const SizedBox.shrink();
    final flood = _nearbyFloodReports.first;
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
                ? (isDark ? const Color(0xFF14291A) : Colors.green.shade50)
                : (isDark ? const Color(0xFF2A1010) : Colors.red.shade50))
            : (isDark ? const Color(0xFF2A1A0A) : Colors.orange.shade50),
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
            alreadyChecked ? (isSafe ? Icons.check_circle : Icons.warning_rounded) : Icons.water_damage,
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
                        ? (isDark ? Colors.green.shade300 : Colors.green.shade800)
                        : (isDark ? Colors.red.shade300 : Colors.red.shade800))
                    : (isDark ? Colors.orange.shade300 : Colors.orange.shade900),
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
              color: isDark ? Colors.orange.shade200 : Colors.orange.shade800,
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
                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() { _myCheckinStatus = null; }),
              child: Text('Change', style: TextStyle(fontSize: 11, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => FamilyCheckinPage(accessToken: widget.accessToken),
              )),
              child: Text('View Family', style: TextStyle(fontSize: 11, color: isDark ? Colors.green.shade300 : Colors.green.shade700, fontWeight: FontWeight.bold)),
            ),
          ]),
        ],
      ]),
    );
  }


  // ── Location search bottom sheet ───────────────────────────────────────────

  _IconSet _iconSetForType(String reportType) {
    switch (reportType) {
      case 'flood':
      case 'water_rising':
        return const _IconSet(
          icon: Icons.water_drop,
          iconBgLight: Color(0xFFDBEAFE),
          iconBgDark: Color(0xFF1E3A5F),
          iconColorLight: Color(0xFF2563EB),
          iconColorDark: Color(0xFF60A5FA),
        );
      case 'blocked_road':
        return const _IconSet(
          icon: Icons.block,
          iconBgLight: Color(0xFFFFEDD5),
          iconBgDark: Color(0xFF4A2F16),
          iconColorLight: Color(0xFFEA580C),
          iconColorDark: Color(0xFFFDBA74),
        );
      case 'medical_emergency':
        return const _IconSet(
          icon: Icons.medical_services_rounded,
          iconBgLight: Color(0xFFFEE2E2),
          iconBgDark: Color(0xFF4A1F1F),
          iconColorLight: Color(0xFFDC2626),
          iconColorDark: Color(0xFFFCA5A5),
        );
      default:
        return const _IconSet(
          icon: Icons.landslide,
          iconBgLight: Color(0x1A2D5927),
          iconBgDark: Color(0xFF223724),
          iconColorLight: Color(0xFF2D5927),
          iconColorDark: Color(0xFF86C77C),
        );
    }
  }

  _StatusSet _statusSetForStatus(String status) {
    final value = status.toLowerCase();
    if (value == 'validated' || value == 'verified' || value == 'resolved') {
      return const _StatusSet(
        status: 'Verified',
        statusBgLight: Color(0xFFDCFCE7),
        statusBgDark: Color(0xFF224032),
        statusTextLight: Color(0xFF15803D),
        statusTextDark: Color(0xFF86EFAC),
      );
    }
    if (value == 'rejected') {
      return const _StatusSet(
        status: 'Rejected',
        statusBgLight: Color(0xFFFEE2E2),
        statusBgDark: Color(0xFF4A1F1F),
        statusTextLight: Color(0xFFB91C1C),
        statusTextDark: Color(0xFFFCA5A5),
      );
    }
    return const _StatusSet(
      status: 'Pending',
      statusBgLight: Color(0xFFFEF3C7),
      statusBgDark: Color(0xFF453714),
      statusTextLight: Color(0xFFB45309),
      statusTextDark: Color(0xFFFCD34D),
    );
  }

  String _titleForType(String reportType) {
    switch (reportType) {
      case 'flood':
      case 'water_rising':
        return 'Water Rising';
      case 'blocked_road':
        return 'Road Blocked';
      case 'medical_emergency':
        return 'Medical Emergency';
      default:
        return 'Landslide';
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  Future<void> _vouchToggle(String reportId) async {
    if (_vouchingIds.contains(reportId)) return;
    final index = _liveItems.indexWhere((it) => it.id == reportId);
    if (index < 0) return;
    final item = _liveItems[index];
    final token = widget.accessToken;

    // Optimistic update
    final optimistic = item.copyWith(
      userVouched: !item.userVouched,
      vouchCount: item.userVouched
          ? (item.vouchCount - 1).clamp(0, 9999)
          : item.vouchCount + 1,
    );
    setState(() {
      _vouchingIds.add(reportId);
      _liveItems[index] = optimistic;
    });

    try {
      if (item.userVouched) {
        await _api.unvouchReport(accessToken: token, reportId: reportId);
      } else {
        await _api.vouchReport(accessToken: token, reportId: reportId);
      }
    } catch (_) {
      // Revert on failure
      if (mounted) {
        final rollbackIndex = _liveItems.indexWhere((it) => it.id == reportId);
        if (rollbackIndex >= 0) {
          setState(() => _liveItems[rollbackIndex] = item);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _vouchingIds.remove(reportId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = AppLanguageScope.of(context).language;
    String tr({required String en, required String ms, required String zh}) {
      return switch (language) {
        AppLanguage.english => en,
        AppLanguage.indonesian => (() {
          final id = indonesianText(en);
          return id == en ? ms : id;
        })(),
        AppLanguage.malay => ms,
        AppLanguage.chinese => zh,
      };
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F140F) : const Color(0xFFF0F2F5);
    final cardBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final border = isDark ? const Color(0xFF334236) : const Color(0xFFE2E8F0);
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF0F172A);
    final subtitleColor = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF64748B);
    final visibleItems = _liveItems;

    final reportsList = SingleChildScrollView(
      key: const ValueKey('reports_list'),
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _showLocationSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationName,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!_isCurrentLocation) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withAlpha(28),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tr(en: 'Custom', ms: 'Kustom', zh: '自定义'),
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      tr(en: 'Change', ms: 'Tukar', zh: '更改'),
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 16, color: subtitleColor),
                  ],
                ),
              ),
            ),
            if (!_isCurrentLocation) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _userLat = _currentLat;
                    _userLon = _currentLon;
                    _isCurrentLocation = true;
                  });
                  _weather
                      .fetchLocationName(
                        latitude: _currentLat,
                        longitude: _currentLon,
                      )
                      .then((name) {
                        if (mounted)
                          setState(() => _locationName = name ?? 'My Location');
                      });
                  _loadNearbyReports();
                },
                child: Row(
                  children: [
                    Icon(Icons.my_location, size: 13, color: subtitleColor),
                    const SizedBox(width: 4),
                    Text(
                      tr(
                        en: 'Reset to my location',
                        ms: 'Tetapkan semula ke lokasi saya',
                        zh: '重置为我的位置',
                      ),
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (_nearbyFloodReports.isNotEmpty) _buildSafetyBanner(isDark: isDark),
            Text(
              tr(en: 'Nearby Activity', ms: 'Aktiviti Berhampiran', zh: '附近动态'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingLiveReports)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_liveReportsError != null && _liveItems.isEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF3A2020)
                        : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF7F1D1D)
                          : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(
                          en: 'Unable to load nearby activity.',
                          ms: 'Tidak dapat memuatkan aktiviti berhampiran.',
                          zh: '无法加载附近动态。',
                        ),
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFB91C1C),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _liveReportsError!,
                        style: TextStyle(color: subtitleColor, fontSize: 12),
                      ),
                      if (_retryCount < 3) ...[
                        const SizedBox(height: 6),
                        Text(
                          tr(
                            en: 'Auto-retrying… (attempt $_retryCount/3)',
                            ms: 'Cuba semula secara automatik… (percubaan $_retryCount/3)',
                            zh: '自动重试中… (第 $_retryCount/3 次)',
                          ),
                          style: TextStyle(color: subtitleColor, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ],
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _loadNearbyReports(manual: true),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(tr(en: 'Retry Now', ms: 'Cuba Sekarang', zh: '立即重试')),
                      ),
                    ],
                  ),
                ),
              if (_liveReportsError == null && visibleItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      tr(
                        en: 'No nearby activity yet.',
                        ms: 'Belum ada aktiviti berhampiran.',
                        zh: '附近暂时没有动态。',
                      ),
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                  ),
                ),
              ...visibleItems.indexed.map(
                ((int, _ReportItem) entry) => _buildReportCard(
                  index: entry.$1,
                  item: entry.$2,
                  cardBg: cardBg,
                  border: border,
                  titleColor: titleColor,
                  subtitleColor: subtitleColor,
                  isDark: isDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => SubmitReportPage(accessToken: widget.accessToken),
            ),
          );
          if (created == true || created == null) {
            _loadNearbyReports();
          }
        },
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(tr(en: 'Report', ms: 'Lapor', zh: '报告')),
      ),
      body: SafeArea(top: false, child: reportsList),
    );
  }

  void _showLocationSheet() {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1B251B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
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

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final titleColor = isDark
                ? const Color(0xFFE5E7EB)
                : const Color(0xFF1E293B);
            final subColor = isDark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B);
            final border = isDark
                ? const Color(0xFF334236)
                : const Color(0xFFE2E8F0);

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
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    style: TextStyle(color: titleColor),
                    decoration: InputDecoration(
                      hintText: 'Search city or state in Malaysia...',
                      hintStyle: TextStyle(color: subColor),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF2E7D32),
                      ),
                      suffixIcon: searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E2720)
                          : const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border),
                      ),
                    ),
                    onChanged: (v) {
                      Future.delayed(const Duration(milliseconds: 400), () {
                        if (searchController.text == v) doSearch(v);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.my_location,
                      color: Color(0xFF2E7D32),
                      size: 18,
                    ),
                    title: Text(
                      'Use my current location',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: titleColor,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _locationName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: subColor, fontSize: 12),
                      ),
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
                            longitude: _currentLon,
                          )
                          .then((name) {
                            if (mounted)
                              setState(
                                () => _locationName = name ?? 'My Location',
                              );
                          });
                      _loadNearbyReports();
                    },
                  ),
                  if (results.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (_, i) {
                          final r = results[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 2,
                            ),
                            leading: Icon(
                              Icons.location_on_outlined,
                              color: subColor,
                              size: 18,
                            ),
                            title: Text(
                              r['name'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: titleColor,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              setState(() {
                                _userLat = r['lat'] as double;
                                _userLon = r['lon'] as double;
                                _locationName = r['name'] as String;
                                _isCurrentLocation = false;
                              });
                              _loadNearbyReports();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReportCard({
    required int index,
    required _ReportItem item,
    required Color cardBg,
    required Color border,
    required Color titleColor,
    required Color subtitleColor,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isDark ? item.iconBgDark : item.iconBgLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  color: isDark ? item.iconColorDark : item.iconColorLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 13, color: subtitleColor),
                        const SizedBox(width: 4),
                        Text(
                          item.time,
                          style: TextStyle(color: subtitleColor, fontSize: 11),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: subtitleColor,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            item.distance ?? item.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildStatusBadge(item.status, isDark),
                        if (item.vulnerablePerson)
                          _buildChip(
                            icon: Icons.warning_amber_rounded,
                            label: 'Needs Help',
                            fg: isDark
                                ? const Color(0xFFFCA5A5)
                                : Colors.red.shade700,
                            bg: isDark
                                ? const Color(0xFF3E1D1D)
                                : Colors.red.shade50,
                          ),
                        if (item.confidenceScore != null)
                          _buildChip(
                            icon: Icons.smart_toy_outlined,
                            label: _aiCredLabel(item.confidenceScore!),
                            fg: _aiCredFg(item.confidenceScore!, isDark),
                            bg: _aiCredBg(item.confidenceScore!, isDark),
                          ),
                        // ── Interactive vouch button ──
                        if (item.id != null)
                          GestureDetector(
                            onTap: _vouchingIds.contains(item.id!)
                                ? null
                                : () => _vouchToggle(item.id!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: item.userVouched
                                    ? (isDark
                                          ? const Color(0xFF1E3A5F)
                                          : Colors.blue.shade50)
                                    : (isDark
                                          ? const Color(0xFF1B251B)
                                          : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: item.userVouched
                                      ? (isDark
                                            ? const Color(0xFF3B82F6)
                                            : Colors.blue.shade300)
                                      : (isDark
                                            ? const Color(0xFF334236)
                                            : const Color(0xFFCBD5E1)),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _vouchingIds.contains(item.id!)
                                      ? SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.8,
                                            color: item.userVouched
                                                ? (isDark
                                                      ? const Color(0xFF93C5FD)
                                                      : Colors.blue.shade700)
                                                : (isDark
                                                      ? const Color(0xFF9AA79B)
                                                      : Colors.grey.shade500),
                                          ),
                                        )
                                      : Icon(
                                          item.userVouched
                                              ? Icons.thumb_up_alt
                                              : Icons.thumb_up_alt_outlined,
                                          size: 12,
                                          color: item.userVouched
                                              ? (isDark
                                                    ? const Color(0xFF93C5FD)
                                                    : Colors.blue.shade700)
                                              : (isDark
                                                    ? const Color(0xFF9AA79B)
                                                    : Colors.grey.shade500),
                                        ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.vouchCount > 0
                                        ? '${item.vouchCount} Vouch'
                                        : 'Vouch',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: item.userVouched
                                          ? (isDark
                                                ? const Color(0xFF93C5FD)
                                                : Colors.blue.shade700)
                                          : (isDark
                                                ? const Color(0xFF9AA79B)
                                                : Colors.grey.shade600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _aiCredLabel(double score) {
    if (score >= 0.75) return 'AI: High';
    if (score >= 0.50) return 'AI: Medium';
    return 'AI: Low';
  }

  Color _aiCredFg(double score, bool isDark) {
    if (score >= 0.75)
      return isDark ? const Color(0xFF86EFAC) : Colors.green.shade700;
    if (score >= 0.50)
      return isDark ? const Color(0xFFFCD34D) : Colors.amber.shade700;
    return isDark ? const Color(0xFFFCA5A5) : Colors.red.shade700;
  }

  Color _aiCredBg(double score, bool isDark) {
    if (score >= 0.75)
      return isDark ? const Color(0xFF14532D) : Colors.green.shade50;
    if (score >= 0.50)
      return isDark ? const Color(0xFF373018) : Colors.amber.shade50;
    return isDark ? const Color(0xFF3E1D1D) : Colors.red.shade50;
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    final normalized = status.toLowerCase();
    final (icon, fg, bg, label) = switch (normalized) {
      'verified' || 'validated' => (
        Icons.verified,
        isDark ? const Color(0xFF4CAF50) : Colors.green.shade700,
        isDark ? const Color(0xFF1A2D1A) : Colors.green.shade50,
        'Verified',
      ),
      'resolved' => (
        Icons.check_circle,
        isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
        isDark ? const Color(0xFF1A1F1A) : Colors.grey.shade100,
        'Resolved',
      ),
      _ => (
        Icons.hourglass_top,
        isDark ? Colors.orange.shade300 : Colors.orange.shade700,
        isDark ? const Color(0xFF2A1F0F) : Colors.orange.shade50,
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
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNewReportForm extends StatefulWidget {
  const _InlineNewReportForm({
    super.key,
    required this.accessToken,
    required this.onBack,
  });

  final String accessToken;
  final VoidCallback onBack;

  @override
  State<_InlineNewReportForm> createState() => _InlineNewReportFormState();
}

class _InlineNewReportFormState extends State<_InlineNewReportForm> {
  int _selectedIncident = 0;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ApiService _api = ApiService();
  final WeatherService _weatherService = WeatherService();
  final List<Map<String, String>> _media = [];
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _resolveLocation() async {
    const fallbackLat = 3.8077;
    const fallbackLon = 103.3260;
    const fallbackName = 'Kuantan, Pahang';

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return {
          'latitude': fallbackLat,
          'longitude': fallbackLon,
          'location_name': fallbackName,
        };
      }
      final pos = await Geolocator.getCurrentPosition();
      final place = await _weatherService.fetchLocationName(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      return {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'location_name': (place != null && place.isNotEmpty)
            ? place
            : fallbackName,
      };
    } catch (_) {
      return {
        'latitude': fallbackLat,
        'longitude': fallbackLon,
        'location_name': fallbackName,
      };
    }
  }

  String _incidentToReportType(int selected) {
    switch (selected) {
      case 0:
        return 'flood';
      case 1:
      case 2:
        return 'landslide';
      case 3:
      default:
        return 'blocked_road';
    }
  }

  Future<void> _pickAndUploadMedia({required bool video}) async {
    final token = widget.accessToken;
    if (token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please sign in again.')));
      }
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: video ? FileType.video : FileType.image,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    for (final file in picked.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      final filename = file.name;
      final ext = filename.toLowerCase();
      final contentType = video
          ? (ext.endsWith('.webm')
                ? 'video/webm'
                : ext.endsWith('.mov')
                ? 'video/quicktime'
                : 'video/mp4')
          : (ext.endsWith('.png')
                ? 'image/png'
                : ext.endsWith('.webp')
                ? 'image/webp'
                : 'image/jpeg');

      try {
        final res = await _api.uploadReportMedia(
          accessToken: token,
          bytes: bytes,
          filename: filename,
          contentType: contentType,
        );
        final url = res['url']?.toString();
        final mediaType =
            res['media_type']?.toString() ?? (video ? 'video' : 'image');
        if (url != null && url.isNotEmpty && mounted) {
          setState(() => _media.add({'url': url, 'type': mediaType}));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        }
      }
    }
  }

  Future<void> _submitReport() async {
    final token = widget.accessToken;
    if (token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please sign in again.')));
      }
      return;
    }

    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();
    final description = [title, desc].where((s) => s.isNotEmpty).join('\n\n');
    if (description.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add report details first.')),
        );
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      final loc = await _resolveLocation();
      await _api.submitCommunityReport(
        accessToken: token,
        reportType: _incidentToReportType(_selectedIncident),
        description: description,
        locationName: loc['location_name'] as String,
        latitude: (loc['latitude'] as num).toDouble(),
        longitude: (loc['longitude'] as num).toDouble(),
        mediaUrls: _media.map((m) => m['url']!).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully.')),
        );
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2D5927);
    final language = AppLanguageScope.of(context).language;
    String tr({required String en, required String ms, required String zh}) {
      return switch (language) {
        AppLanguage.english => en,
        AppLanguage.indonesian => (() {
          final id = indonesianText(en);
          return id == en ? ms : id;
        })(),
        AppLanguage.malay => ms,
        AppLanguage.chinese => zh,
      };
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF86C77C) : primary;
    final bg = isDark ? const Color(0xFF0F140F) : const Color(0xFFF0F2F5);
    final sectionLabel = isDark
        ? const Color(0xFF97A09B)
        : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF2A332A) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF1D251D) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF0F172A);

    return Container(
      key: const ValueKey('new_report_form'),
      color: bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: Icon(
                    Icons.arrow_back,
                    color: isDark
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF334155),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Text(
                  tr(
                    en: 'New Community Report',
                    ms: 'Laporan Komuniti Baharu',
                    zh: '新社区报告',
                  ),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                en: 'Share what you\'re observing to help LANDA predict local risks.',
                ms: 'Kongsi apa yang anda perhatikan untuk membantu LANDA meramal risiko setempat.',
                zh: '分享您观察到的情况，帮助 LANDA 预测当地风险。',
              ),
              style: TextStyle(color: sectionLabel, height: 1.35),
            ),
            const SizedBox(height: 22),
            Text(
              tr(
                en: 'WHAT ARE YOU OBSERVING?',
                ms: 'APA YANG ANDA PERHATIKAN?',
                zh: '您观察到了什么？',
              ),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: sectionLabel,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.of(
                  context,
                ).textScaler.scale(1).clamp(1.0, 1.3);
                final cellWidth = (constraints.maxWidth - 10) / 2;
                final cardHeight = (cellWidth * 0.68 + (textScale - 1.0) * 14)
                    .clamp(88.0, 118.0);

                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: cellWidth / cardHeight,
                  children: [
                    _buildIncidentCard(
                      index: 0,
                      selectedIndex: _selectedIncident,
                      icon: Icons.water_drop,
                      label: tr(
                        en: 'Rising Water',
                        ms: 'Air Meningkat',
                        zh: '水位上涨',
                      ),
                      onTap: () => setState(() => _selectedIncident = 0),
                      border: border,
                      cardBg: cardBg,
                      isDark: isDark,
                      selectedColor: accent,
                    ),
                    _buildIncidentCard(
                      index: 1,
                      selectedIndex: _selectedIncident,
                      icon: Icons.texture,
                      label: tr(
                        en: 'Cracks in Soil',
                        ms: 'Retakan Tanah',
                        zh: '土壤裂缝',
                      ),
                      onTap: () => setState(() => _selectedIncident = 1),
                      border: border,
                      cardBg: cardBg,
                      isDark: isDark,
                      selectedColor: accent,
                    ),
                    _buildIncidentCard(
                      index: 2,
                      selectedIndex: _selectedIncident,
                      icon: Icons.landslide,
                      label: tr(
                        en: 'Land Movement',
                        ms: 'Pergerakan Tanah',
                        zh: '地面位移',
                      ),
                      onTap: () => setState(() => _selectedIncident = 2),
                      border: border,
                      cardBg: cardBg,
                      isDark: isDark,
                      selectedColor: accent,
                    ),
                    _buildIncidentCard(
                      index: 3,
                      selectedIndex: _selectedIncident,
                      icon: Icons.more_horiz,
                      label: tr(
                        en: 'Other Concern',
                        ms: 'Lain-lain Kebimbangan',
                        zh: '其他问题',
                      ),
                      onTap: () => setState(() => _selectedIncident = 3),
                      border: border,
                      cardBg: cardBg,
                      isDark: isDark,
                      selectedColor: accent,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            Text(
              tr(en: 'EVIDENCE', ms: 'BUKTI', zh: '证据'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: sectionLabel,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildEvidenceButton(
                    icon: Icons.add_a_photo,
                    label: tr(en: 'Add Photos', ms: 'Tambah Foto', zh: '添加照片'),
                    border: border,
                    isDark: isDark,
                    onTap: () => _pickAndUploadMedia(video: false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildEvidenceButton(
                    icon: Icons.videocam,
                    label: tr(en: 'Add Video', ms: 'Tambah Video', zh: '添加视频'),
                    border: border,
                    isDark: isDark,
                    onTap: () => _pickAndUploadMedia(video: true),
                  ),
                ),
              ],
            ),
            if (_media.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _media
                    .asMap()
                    .entries
                    .map(
                      (entry) => Chip(
                        label: Text('${entry.value['type']} ${entry.key + 1}'),
                        onDeleted: () =>
                            setState(() => _media.removeAt(entry.key)),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 22),
            Text(
              tr(en: 'REPORT DETAILS', ms: 'BUTIRAN LAPORAN', zh: '报告详情'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: sectionLabel,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              maxLength: 60,
              style: TextStyle(
                color: isDark
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFF111827),
              ),
              cursorColor: accent,
              decoration: InputDecoration(
                hintText: tr(
                  en: 'Title (optional)',
                  ms: 'Tajuk (pilihan)',
                  zh: '标题（可选）',
                ),
                hintStyle: TextStyle(
                  color: isDark
                      ? const Color(0xFF9AA79B)
                      : const Color(0xFF64748B),
                ),
                filled: true,
                fillColor: cardBg,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accent, width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 6,
              maxLength: 500,
              style: TextStyle(
                color: isDark
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFF111827),
              ),
              cursorColor: accent,
              decoration: InputDecoration(
                hintText: tr(
                  en: 'Describe what happened, where, and how severe it is.',
                  ms: 'Terangkan apa yang berlaku, di mana, dan tahap keterukannya.',
                  zh: '请描述发生了什么、地点以及严重程度。',
                ),
                hintStyle: TextStyle(
                  color: isDark
                      ? const Color(0xFF9AA79B)
                      : const Color(0xFF64748B),
                ),
                counterStyle: TextStyle(
                  color: isDark
                      ? const Color(0xFF9AA79B)
                      : const Color(0xFF64748B),
                ),
                filled: true,
                fillColor: cardBg,
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accent, width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        tr(
                          en: 'Submit Report',
                          ms: 'Hantar Laporan',
                          zh: '提交报告',
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentCard({
    required int index,
    required int selectedIndex,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color border,
    required Color cardBg,
    required bool isDark,
    required Color selectedColor,
  }) {
    final selected = index == selectedIndex;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? (isDark
                      ? selectedColor.withAlpha(40)
                      : selectedColor.withAlpha(18))
                : cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? selectedColor : border,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 30,
                color: selected
                    ? selectedColor
                    : (isDark
                          ? const Color(0xFFA7B5A8)
                          : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? selectedColor
                      : (isDark
                            ? const Color(0xFFD1D5DB)
                            : const Color(0xFF334155)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEvidenceButton({
    required IconData icon,
    required String label,
    required Color border,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: isDark ? const Color(0xFF4F6252) : const Color(0xFF64748B),
            radius: 12,
            strokeWidth: 1.5,
            dashWidth: 5,
            dashGap: 4,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isDark
                      ? const Color(0xFFA7B5A8)
                      : const Color(0xFF94A3B8),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return color != oldDelegate.color ||
        radius != oldDelegate.radius ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashWidth != oldDelegate.dashWidth ||
        dashGap != oldDelegate.dashGap;
  }
}

class _ReportItem {
  const _ReportItem({
    this.id,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.time,
    required this.distance,
    required this.icon,
    required this.iconBgLight,
    required this.iconBgDark,
    required this.iconColorLight,
    required this.iconColorDark,
    required this.status,
    required this.statusBgLight,
    required this.statusBgDark,
    required this.statusTextLight,
    required this.statusTextDark,
    this.imageUrl,
    this.userVouched = false,
    this.vouchCount = 0,
    this.confidenceScore,
    this.vulnerablePerson = false,
  });

  final String? id;
  final String title;
  final String subtitle;
  final String location;
  final String time;
  final String? distance;
  final IconData icon;
  final Color iconBgLight;
  final Color iconBgDark;
  final Color iconColorLight;
  final Color iconColorDark;
  final String status;
  final Color statusBgLight;
  final Color statusBgDark;
  final Color statusTextLight;
  final Color statusTextDark;
  final String? imageUrl;
  final bool userVouched;
  final int vouchCount;
  final double? confidenceScore;
  final bool vulnerablePerson;

  _ReportItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? location,
    String? time,
    String? distance,
    IconData? icon,
    Color? iconBgLight,
    Color? iconBgDark,
    Color? iconColorLight,
    Color? iconColorDark,
    String? status,
    Color? statusBgLight,
    Color? statusBgDark,
    Color? statusTextLight,
    Color? statusTextDark,
    String? imageUrl,
    bool? userVouched,
    int? vouchCount,
    double? confidenceScore,
    bool? vulnerablePerson,
  }) {
    return _ReportItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      location: location ?? this.location,
      time: time ?? this.time,
      distance: distance ?? this.distance,
      icon: icon ?? this.icon,
      iconBgLight: iconBgLight ?? this.iconBgLight,
      iconBgDark: iconBgDark ?? this.iconBgDark,
      iconColorLight: iconColorLight ?? this.iconColorLight,
      iconColorDark: iconColorDark ?? this.iconColorDark,
      status: status ?? this.status,
      statusBgLight: statusBgLight ?? this.statusBgLight,
      statusBgDark: statusBgDark ?? this.statusBgDark,
      statusTextLight: statusTextLight ?? this.statusTextLight,
      statusTextDark: statusTextDark ?? this.statusTextDark,
      imageUrl: imageUrl ?? this.imageUrl,
      userVouched: userVouched ?? this.userVouched,
      vouchCount: vouchCount ?? this.vouchCount,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      vulnerablePerson: vulnerablePerson ?? this.vulnerablePerson,
    );
  }
}

class _IconSet {
  const _IconSet({
    required this.icon,
    required this.iconBgLight,
    required this.iconBgDark,
    required this.iconColorLight,
    required this.iconColorDark,
  });

  final IconData icon;
  final Color iconBgLight;
  final Color iconBgDark;
  final Color iconColorLight;
  final Color iconColorDark;
}

class _StatusSet {
  const _StatusSet({
    required this.status,
    required this.statusBgLight,
    required this.statusBgDark,
    required this.statusTextLight,
    required this.statusTextDark,
  });

  final String status;
  final Color statusBgLight;
  final Color statusBgDark;
  final Color statusTextLight;
  final Color statusTextDark;
}
