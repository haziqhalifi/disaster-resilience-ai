import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:disaster_resilience_ai/models/risk_map_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';

class SafeRoutesPage extends StatefulWidget {
  const SafeRoutesPage({super.key});

  @override
  State<SafeRoutesPage> createState() => _SafeRoutesPageState();
}

class _CentreRoute {
  final EvacuationCentre centre;
  final double distanceKm;
  final List<LatLng> polyline;
  final double durationMin;

  _CentreRoute({
    required this.centre,
    required this.distanceKm,
    required this.polyline,
    required this.durationMin,
  });
}

class _SafeRoutesPageState extends State<SafeRoutesPage> {
  final ApiService _api = ApiService();
  final MapController _mapCtrl = MapController();

  bool _loading = true;
  String? _error;
  LatLng? _userLoc;
  List<_CentreRoute> _routes = [];
  int _selectedIdx = 0;

  static const _routeColors = [
    Color(0xFF2E7D32),
    Color(0xFF1565C0),
    Color(0xFFE65100),
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Get user location
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Location permission is required to show nearby routes.';
          });
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final userLoc = LatLng(pos.latitude, pos.longitude);

      // Fetch evacuation centres
      final json = await _api.fetchMapData();
      final mapData = MapData.fromJson(json);

      // Compute distance and sort, take nearest 3
      final withDist =
          mapData.evacuationCentres
              .where((c) => c.active)
              .map(
                (c) => MapEntry(
                  c,
                  _haversineKm(
                    userLoc.latitude,
                    userLoc.longitude,
                    c.latitude,
                    c.longitude,
                  ),
                ),
              )
              .toList()
            ..sort((a, b) => a.value.compareTo(b.value));

      final nearest = withDist.take(3).toList();

      // Fetch routes in parallel
      final routeFutures = nearest.map((entry) async {
        final c = entry.key;
        final routePoints = await _api.fetchRoute(
          startLat: userLoc.latitude,
          startLon: userLoc.longitude,
          endLat: c.latitude,
          endLon: c.longitude,
        );
        final polyline = routePoints
            .map((p) => LatLng(p['lat']!, p['lng']!))
            .toList();

        // Estimate duration: avg walking speed ~5 km/h
        final distKm = entry.value;
        final walkMin = (distKm / 5.0 * 60).round().toDouble();

        return _CentreRoute(
          centre: c,
          distanceKm: distKm,
          polyline: polyline,
          durationMin: walkMin,
        );
      });

      final routes = await Future.wait(routeFutures);

      if (mounted) {
        setState(() {
          _userLoc = userLoc;
          _routes = routes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load routes. Please try again.';
        });
      }
    }
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double d) => d * math.pi / 180;

  void _openInMaps(_CentreRoute cr) async {
    final c = cr.centre;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${_userLoc!.latitude},${_userLoc!.longitude}'
      '&destination=${c.latitude},${c.longitude}'
      '&travelmode=walking',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F140F) : const Color(0xFFF0F2F5);
    final barBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final divColor = isDark
        ? const Color(0xFF334236)
        : const Color(0xFF2D5927).withAlpha(26);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: barBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Safe Routes',
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: divColor),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
            )
          : _error != null
          ? _buildErrorView(isDark)
          : _buildContent(isDark),
    );
  }

  Widget _buildErrorView(bool isDark) {
    final textColor = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF64748B);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 48, color: textColor),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _init,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final subtitleColor = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF64748B);

    return Column(
      children: [
        // Map
        SizedBox(
          height: 280,
          child: FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(initialCenter: _userLoc!, initialZoom: 13.5),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.disasterai.disaster_resilience_ai',
              ),
              // Route polylines (show all, highlight selected)
              PolylineLayer(
                polylines: _routes.asMap().entries.map((entry) {
                  final i = entry.key;
                  final cr = entry.value;
                  final isSelected = i == _selectedIdx;
                  return Polyline(
                    points: cr.polyline,
                    strokeWidth: isSelected ? 5.0 : 3.0,
                    color: _routeColors[i % _routeColors.length].withAlpha(
                      isSelected ? 230 : 100,
                    ),
                  );
                }).toList(),
              ),
              // Markers
              MarkerLayer(
                markers: [
                  // User location
                  Marker(
                    point: _userLoc!,
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withAlpha(80),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  // Centre markers
                  ..._routes.asMap().entries.map((entry) {
                    final i = entry.key;
                    final cr = entry.value;
                    final color = _routeColors[i % _routeColors.length];
                    return Marker(
                      point: LatLng(cr.centre.latitude, cr.centre.longitude),
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedIdx = i),
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),

        // Centre cards
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _routes.length,
            itemBuilder: (ctx, i) {
              final cr = _routes[i];
              final isSelected = i == _selectedIdx;
              final color = _routeColors[i % _routeColors.length];
              final occupancy = cr.centre.occupancyPercent;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedIdx = i);
                  _mapCtrl.move(
                    LatLng(cr.centre.latitude, cr.centre.longitude),
                    14,
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected
                        ? Border.all(color: color, width: 2)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color.withAlpha(isDark ? 50 : 25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cr.centre.name,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (cr.centre.address.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    cr.centre.address,
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (i == 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32).withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'NEAREST',
                                style: TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Stats row
                      Row(
                        children: [
                          _buildStat(
                            Icons.straighten,
                            '${cr.distanceKm.toStringAsFixed(1)} km',
                            subtitleColor,
                          ),
                          const SizedBox(width: 16),
                          _buildStat(
                            Icons.directions_walk,
                            '~${cr.durationMin.round()} min',
                            subtitleColor,
                          ),
                          const SizedBox(width: 16),
                          _buildStat(
                            Icons.people,
                            '${cr.centre.currentOccupancy}/${cr.centre.capacity}',
                            subtitleColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Occupancy bar
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: occupancy / 100,
                                minHeight: 6,
                                backgroundColor: isDark
                                    ? Colors.white.withAlpha(20)
                                    : Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  occupancy > 80
                                      ? Colors.red
                                      : occupancy > 50
                                      ? Colors.orange
                                      : const Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${occupancy.round()}% full',
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      // Contact & navigate
                      if (cr.centre.contactPhone != null &&
                          cr.centre.contactPhone!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.phone, size: 14, color: subtitleColor),
                            const SizedBox(width: 6),
                            Text(
                              cr.centre.contactPhone!,
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Navigate button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openInMaps(cr),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.navigation, size: 18),
                          label: const Text(
                            'Navigate',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStat(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
