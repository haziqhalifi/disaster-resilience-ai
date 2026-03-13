import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

import 'package:disaster_resilience_ai/models/warning_model.dart';
import 'package:disaster_resilience_ai/models/risk_map_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/ui/evacuation_navigation_page.dart';
import 'package:disaster_resilience_ai/utils/time_utils.dart';

class EmergencyAlertPage extends StatefulWidget {
  const EmergencyAlertPage({super.key, this.warning});

  final Warning? warning;

  @override
  State<EmergencyAlertPage> createState() => _EmergencyAlertPageState();
}

class _EmergencyAlertPageState extends State<EmergencyAlertPage> {
  final ApiService _api = ApiService();
  final MapController _mapController = MapController();

  LatLng? _userLocation;
  bool _loading = true;
  bool _usingFallbackLocation = false;
  EvacuationCentre? _nearestCentre;
  List<LatLng> _routePoints = [];

  // Dengkil, Selangor — used as fallback when location is unavailable or outside Malaysia
  static const _dengkilFallback = LatLng(2.8595, 101.6781);

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _loading = true);
    try {
      // 1. Get location with Malaysian sanity check + fallback
      final (userLatLng, isFallback) = await _getSafeLocation();

      // 2. Fetch map data (centres/routes)
      final json = await _api.fetchMapData();
      final mapData = MapData.fromJson(json);

      // 3. Find nearest centre
      EvacuationCentre? nearest;
      double minDist = double.infinity;

      for (final c in mapData.evacuationCentres) {
        final dist = _calculateDistance(
          userLatLng.latitude,
          userLatLng.longitude,
          c.latitude,
          c.longitude,
        );
        if (dist < minDist) {
          minDist = dist;
          nearest = c;
        }
      }

      // 4. Fetch real road route — only if nearest centre is within 200 km
      //    (prevents cross-ocean OSRM queries from emulator default location)
      List<LatLng> route = [];
      if (nearest != null && minDist < 200) {
        try {
          final routeData = await _api.fetchRoute(
            startLat: userLatLng.latitude,
            startLon: userLatLng.longitude,
            endLat: nearest.latitude,
            endLon: nearest.longitude,
          );
          route = routeData.map((p) => LatLng(p['lat']!, p['lng']!)).toList();
        } catch (_) {
          // Route fetch failed — navigator will still work without polyline
        }
      }

      if (mounted) {
        setState(() {
          _userLocation = userLatLng;
          _usingFallbackLocation = isFallback;
          _nearestCentre = nearest;
          _routePoints = route;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userLocation = _dengkilFallback;
          _usingFallbackLocation = true;
          _loading = false;
        });
      }
    }
  }

  /// Returns (location, isFallback). Uses Dengkil as fallback when
  /// permission is denied OR when the device reports a non-Malaysian location
  /// (typical for Android emulators defaulting to Mountain View, CA).
  Future<(LatLng, bool)> _getSafeLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        return (_dengkilFallback, true);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Malaysia bounding box check (lat 0.8–7.5, lon 99.5–120)
      final inMalaysia =
          pos.latitude >= 0.8 &&
          pos.latitude <= 7.5 &&
          pos.longitude >= 99.5 &&
          pos.longitude <= 120.0;

      if (!inMalaysia) {
        return (_dengkilFallback, true);
      }

      return (LatLng(pos.latitude, pos.longitude), false);
    } catch (_) {
      return (_dengkilFallback, true);
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295;
    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  /// Returns (Bahasa Malaysia direction, English direction)
  (String, String) _getDirectionBilingual(LatLng from, LatLng to) {
    final latDiff = to.latitude - from.latitude;
    final lonDiff = to.longitude - from.longitude;
    if (latDiff.abs() > lonDiff.abs()) {
      return latDiff > 0 ? ('Utara', 'North') : ('Selatan', 'South');
    } else {
      return lonDiff > 0 ? ('Timur', 'East') : ('Barat', 'West');
    }
  }

  String _safeTipBm(HazardType type) => switch (type) {
    HazardType.flood => 'Elak jalan rendah berhampiran sungai walaupun kelihatan lebih dekat.',
    HazardType.infrastructure => 'Jauhi bangunan dan tiang elektrik yang rosak.',
    _ => 'Ikuti arahan pegawai berwajib dan jangan balik ke kawasan bahaya.',
  };

  String _safeTipEn(HazardType type) => switch (type) {
    HazardType.flood => 'Avoid low-lying river paths even if they seem shorter.',
    HazardType.infrastructure => 'Stay away from damaged buildings and power lines.',
    _ => 'Follow official instructions and do not return to the danger zone.',
  };

  @override
  Widget build(BuildContext context) {
    if (widget.warning == null) {
      return _buildNoWarningState(context);
    }
    return _buildWarningState(context, widget.warning!);
  }

  Widget _buildNoWarningState(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.scaffoldBackgroundColor;
    final onSurface = scheme.onSurface;
    final successBg = isDark ? const Color(0xFF1B3320) : const Color(0xFFE8F5E9);
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Warning Details',
          style: TextStyle(
            color: onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: successBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF2D5927),
                  size: 72,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'All Clear',
                style: TextStyle(
                  color: Color(0xFF2D5927),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No active warnings near your location.\nStay safe and prepared.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'BACK TO DASHBOARD',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningState(BuildContext context, Warning w) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = _alertBackground(w.alertLevel, isDark);
    final cardColor = isDark ? theme.cardColor : Colors.white;
    final cardText = isDark ? scheme.onSurface : const Color(0xFF111827);
    final tipBg = isDark
        ? scheme.tertiaryContainer.withAlpha(180)
        : Colors.amber[50]!;
    final fallbackFill = isDark ? Colors.black.withAlpha(56) : Colors.white.withAlpha(38);
    final fallbackBorder = isDark ? Colors.white24 : Colors.white.withAlpha(80);
    final timeAgo = localizedTimeAgo(w.createdAt, context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Emergency Alert',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showWarningDetails(context, w),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  shape: BoxShape.circle,
                ),
                child: Icon(_alertIcon(w), color: Colors.white, size: 60),
              ),
              const SizedBox(height: 16),
              Text(
                '${w.alertLevel.displayName} • ${w.hazardType.displayName.toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                w.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                w.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(230),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInfoChip(Icons.access_time, timeAgo),
                  _buildInfoChip(Icons.radar, '${w.radiusKm} km radius'),
                  _buildInfoChip(Icons.source, w.source),
                ],
              ),
              const SizedBox(height: 24),

              // Map Card
              Container(
                height: 220,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter:
                              _userLocation ??
                              LatLng(w.location.latitude, w.location.longitude),
                          initialZoom: 13.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName:
                                'com.disasterai.disaster_resilience_ai',
                          ),
                          // Real-world road route
                          if (_routePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePoints,
                                  color: Colors.blue[600]!,
                                  strokeWidth: 4,
                                ),
                              ],
                            ),
                          // Warning Circle
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: LatLng(
                                  w.location.latitude,
                                  w.location.longitude,
                                ),
                                radius: w.radiusKm * 1000,
                                useRadiusInMeter: true,
                                color: bgColor.withAlpha(51),
                                borderColor: bgColor.withAlpha(153),
                                borderStrokeWidth: 2,
                              ),
                            ],
                          ),
                          // Nearest Centre Marker
                          if (_nearestCentre != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    _nearestCentre!.latitude,
                                    _nearestCentre!.longitude,
                                  ),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.local_hospital,
                                    color: Color(0xFF2E7D32),
                                    size: 30,
                                  ),
                                ),
                              ],
                            ),
                          // User Location Marker
                          if (_userLocation != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _userLocation!,
                                  width: 30,
                                  height: 30,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person_pin_circle,
                                      color: Colors.blue,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
              ),

              const SizedBox(height: 20),

              // Rural Evacuation Guide (Text Instructions)
              if (_nearestCentre != null && _userLocation != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withAlpha(44)
                            : Colors.black.withAlpha(26),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.record_voice_over,
                            color: Color(0xFF2E7D32),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'RURAL EVACUATION GUIDE',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Builder(builder: (context) {
                        final centre = LatLng(_nearestCentre!.latitude, _nearestCentre!.longitude);
                        final (bmDir, enDir) = _getDirectionBilingual(_userLocation!, centre);
                        final distKm = _calculateDistance(
                          _userLocation!.latitude, _userLocation!.longitude,
                          _nearestCentre!.latitude, _nearestCentre!.longitude,
                        ).toStringAsFixed(1);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BAHASA MALAYSIA:',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sila bergerak ke arah $bmDir menuju ke ${_nearestCentre!.name}. '
                              'Jarak adalah lebih kurang $distKm KM dari sini.',
                              style: TextStyle(
                                color: cardText,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'ENGLISH:',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Please head $enDir towards ${_nearestCentre!.name}. '
                              'It is about $distKm KM away.',
                              style: TextStyle(
                                color: cardText,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: tipBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.tips_and_updates, color: Colors.amber[800], size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${_safeTipBm(w.hazardType)}\n${_safeTipEn(w.hazardType)}',
                                      style: TextStyle(
                                        color: cardText,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Fallback location notice
              if (_usingFallbackLocation)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: fallbackFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: fallbackBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.location_searching,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '📍 Location approximated — showing nearest PPS to Dengkil.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _nearestCentre != null && !_loading
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EvacuationNavigationPage(
                                routePoints: _routePoints,
                                userLocation: _userLocation ?? _dengkilFallback,
                                destination: _nearestCentre!,
                              ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? scheme.surfaceContainerHighest.withAlpha(235)
                        : Colors.white,
                    foregroundColor: isDark ? scheme.onSurface : bgColor,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white70,
                          ),
                        )
                      : Icon(
                          w.alertLevel == AlertLevel.evacuate
                              ? Icons.directions_run
                              : Icons.navigation,
                          size: 28,
                        ),
                  label: Text(
                    _loading
                        ? 'MENCARI PUSAT EVAKUASI...'
                        : w.alertLevel == AlertLevel.evacuate
                            ? 'EVACUATE NOW'
                            : 'VIEW SAFE ROUTES',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _nearestCentre == null
                    ? 'LOADING EVACUATION CENTRES...'
                    : _routePoints.isEmpty
                    ? 'ROUTE MAP UNAVAILABLE — CENTRE LOCATION SHOWN'
                    : (w.alertLevel == AlertLevel.evacuate
                          ? 'TAP FOR TURN-BY-TURN NAVIGATION'
                          : 'TAP TO VIEW RECOMMENDED SAFE ROUTES'),
                style: TextStyle(
                  color: _routePoints.isEmpty && !_loading
                      ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                      : Colors.white70,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(60),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white38),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }

  Color _alertColor(AlertLevel level) {
    switch (level) {
      case AlertLevel.advisory:
        return Colors.blue[700]!;
      case AlertLevel.observe:
        return Colors.amber[700]!;
      case AlertLevel.warning:
        return Colors.deepOrange[700]!;
      case AlertLevel.evacuate:
        return const Color(0xFFD32F2F);
    }
  }

  Color _alertBackground(AlertLevel level, bool isDark) {
    final base = _alertColor(level);
    if (!isDark) return base;
    return Color.alphaBlend(Colors.black.withAlpha(90), base);
  }

  IconData _alertIcon(Warning w) {
    // Priority icons for non-standard hazard types
    if (w.hazardType == HazardType.aid) return Icons.volunteer_activism;
    if (w.hazardType == HazardType.forecast) return Icons.wb_cloudy_outlined;
    if (w.hazardType == HazardType.infrastructure) return Icons.construction;

    switch (w.alertLevel) {
      case AlertLevel.advisory:
        return Icons.info_outline;
      case AlertLevel.observe:
        return Icons.visibility_outlined;
      case AlertLevel.warning:
        return Icons.warning_amber_rounded;
      case AlertLevel.evacuate:
        return Icons.directions_run;
    }
  }


  void _showWarningDetails(BuildContext context, Warning w) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? theme.cardColor : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Warning Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? scheme.onSurface : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(context, 'ID', w.id.substring(0, 8)),
            _buildDetailRow(context, 'Hazard', w.hazardType.displayName),
            _buildDetailRow(context, 'Level', w.alertLevel.displayName),
            _buildDetailRow(context, 'Source', w.source),
            _buildDetailRow(context, 'Radius', '${w.radiusKm} km'),
            _buildDetailRow(
              context,
              'Coordinates',
              '${w.location.latitude.toStringAsFixed(4)}, ${w.location.longitude.toStringAsFixed(4)}',
            ),
            _buildDetailRow(
              context,
              'Created',
              w.createdAt.toLocal().toString().substring(0, 19),
            ),
            _buildDetailRow(context, 'Status', w.active ? 'Active' : 'Resolved'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
