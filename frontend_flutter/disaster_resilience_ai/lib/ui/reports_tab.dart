import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:disaster_resilience_ai/models/report_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/services/weather_service.dart';
import 'package:disaster_resilience_ai/ui/submit_report_page.dart';
import 'package:disaster_resilience_ai/ui/location_news_page.dart';

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
        if (perm != LocationPermission.deniedForever && perm != LocationPermission.denied) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
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
    } catch (_) {
      // Keep fallback coords
    }
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
  }

  // Stats computed from live validated data
  int get _activeCount => _reports.length;
  int get _resolvedCount => _reports.where((r) => r.status == 'resolved').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SubmitReportPage(accessToken: widget.accessToken),
            ),
          );
          _fetchReports();
        },
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Report', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchReports,
        color: const Color(0xFF2E7D32),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Community Reports',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Real-time situational awareness from your community',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Location bar
              GestureDetector(
                onTap: _showLocationSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 18, color: const Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationName,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_isCurrentLocation) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Custom', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      const SizedBox(width: 4),
                      Text('Change', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
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
                    // Re-resolve name from GPS
                    _weather.fetchLocationName(latitude: _currentLat, longitude: _currentLon).then((name) {
                      if (mounted) setState(() => _locationName = name ?? 'My Location');
                    });
                    _fetchReports();
                  },
                  child: Row(
                    children: [
                      Icon(Icons.my_location, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text('Reset to my location', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Stats row
              Row(
                children: [
                  _buildStatCard('$_activeCount', 'Verified\nReports', const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
                  const SizedBox(width: 12),
                  _buildStatCard('$_resolvedCount', 'Resolved\nToday', Colors.grey[600]!, Colors.grey[100]!),
                ],
              ),
              const SizedBox(height: 24),

              // Results count
              if (!_loading && _error == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${_reports.length} verified report${_reports.length == 1 ? '' : 's'} near you',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),

              // Disaster overview banner
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      const Icon(Icons.map_outlined, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Full Disaster Overview',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Warnings, reports & news for $_locationName',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),

              // Live feed label
              const Row(
                children: [
                  Icon(Icons.circle, color: Colors.red, size: 10),
                  SizedBox(width: 6),
                  Text(
                    'LIVE FEED',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Report list body
              _buildBody(),
              const SizedBox(height: 24),

              const SizedBox(height: 80), // space so FAB doesn't overlap last card
            ],
          ),
        ),
      ),
    );
  }

  void _showLocationSheet() {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          Future<void> doSearch(String q) async {
            if (q.trim().isEmpty) {
              setSheetState(() { results = []; searching = false; });
              return;
            }
            setSheetState(() => searching = true);
            final found = await _weather.searchLocation(q);
            setSheetState(() { results = found; searching = false; });
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Choose Location', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 12),
                // Search field
                TextField(
                  controller: searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search city or state in Malaysia...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                    suffixIcon: searching
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E7D32))))
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) {
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (searchController.text == v) doSearch(v);
                    });
                  },
                ),
                const SizedBox(height: 8),
                // Use current location row
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.my_location, color: Color(0xFF2E7D32), size: 18),
                  ),
                  title: const Text('Use my current location', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    setState(() {
                      _userLat = _currentLat;
                      _userLon = _currentLon;
                      _isCurrentLocation = true;
                    });
                    _weather.fetchLocationName(latitude: _currentLat, longitude: _currentLon).then((name) {
                      if (mounted) setState(() => _locationName = name ?? 'My Location');
                    });
                    _fetchReports();
                  },
                ),
                if (results.isNotEmpty) ...[
                  const Divider(height: 1),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final r = results[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                            child: Icon(Icons.location_on_outlined, color: Colors.grey[600], size: 18),
                          ),
                          title: Text(r['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.wifi_off, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'Could not load reports',
                style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final visible = _reports;

    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: Colors.green[300]),
              const SizedBox(height: 12),
              Text(
                'No reports in your area',
                style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Pull to refresh or submit one if you see something.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: visible.map(_buildReportItem).toList(),
    );
  }

  Widget _buildReportItem(Report report) {
    final typeIcon = _iconFor(report.reportType);
    final typeColor = _colorFor(report.reportType);
    final timeAgo = _timeAgo(report.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(typeIcon, color: typeColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${report.typeLabel} — ${report.locationName}',
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  report.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 13, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(timeAgo, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                    if (report.distanceKm != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.near_me, size: 13, color: Colors.grey[400]),
                      const SizedBox(width: 2),
                      Text(
                        '${report.distanceKm!.toStringAsFixed(1)} km',
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ],
                    if (report.vulnerablePerson) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.priority_high, size: 13, color: Colors.red[400]),
                      Text(
                        'Priority',
                        style: TextStyle(color: Colors.red[400], fontSize: 11),
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

  Widget _buildStatusBadge(String status) {
    final config = switch (status) {
      'validated' => (Icons.verified, Colors.green[700]!, Colors.green[50]!, 'Verified'),
      'resolved'  => (Icons.check_circle, Colors.grey[600]!, Colors.grey[100]!, 'Resolved'),
      'pending'   => (Icons.hourglass_top, Colors.orange[700]!, Colors.orange[50]!, 'Pending Review'),
      _           => (Icons.hourglass_top, Colors.orange[700]!, Colors.orange[50]!, 'Pending Review'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(config.$1, size: 11, color: config.$2),
        const SizedBox(width: 3),
        Text(
          config.$4,
          style: TextStyle(color: config.$2, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildStatCard(String count, String label, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'flood':
        return Icons.water_drop;
      case 'blocked_road':
        return Icons.block;
      case 'landslide':
        return Icons.landscape;
      case 'medical_emergency':
        return Icons.medical_services_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'flood':
        return Colors.blue[700]!;
      case 'blocked_road':
        return Colors.orange[700]!;
      case 'landslide':
        return Colors.brown[700]!;
      case 'medical_emergency':
        return Colors.red[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
