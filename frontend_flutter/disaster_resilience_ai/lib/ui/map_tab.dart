import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:disaster_resilience_ai/models/risk_map_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final MapController _mapController = MapController();
  final ApiService _api = ApiService();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _loadingMap = true;
  MapData? _mapData;

  LatLng? _userLocation;
  bool _locatingUser = false;

  // Filter (only two supported hazard types)
  String _hazardFilter = 'flood';

  // Default centre: Kuantan, Pahang
  final LatLng _defaultCentre = const LatLng(3.8077, 103.3260);

  @override
  void initState() {
    super.initState();
    _loadMapData();
    _getUserLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadMapData() async {
    setState(() {
      _loadingMap = true;
    });
    try {
      final json = await _api.fetchMapData(hazardType: _hazardFilter);
      if (mounted) {
        setState(() {
          _mapData = MapData.fromJson(json);
          _loadingMap = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingMap = false;
        });
      }
    }
  }

  Future<void> _getUserLocation() async {
    setState(() => _locatingUser = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
          _locatingUser = false;
        });
        _mapController.move(_userLocation!, 13.0);
      }
    } catch (_) {
      // Fallback to default
      if (mounted) {
        setState(() {
          _userLocation = _defaultCentre;
          _locatingUser = false;
        });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Map
        _buildMap(),
        // Top filter chips
        _buildTopControls(),
        // Legend panel
        _buildLegend(),
        // Loading overlay
        if (_loadingMap) _buildLoadingOverlay(),
        // Locate me button
        _buildLocateButton(),
      ],
    );
  }

  Widget _buildMap() {
    final centre = _userLocation ?? _defaultCentre;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: centre,
        initialZoom: 13.0,
        minZoom: 5.0,
        maxZoom: 18.0,
      ),
      children: [
        // OpenStreetMap tiles
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.disasterai.disaster_resilience_ai',
        ),
        if (_filteredAdminAreas.isNotEmpty) _buildAdminAreaPolygons(),
        // Markers: location-based hazard pins + user location
        _buildMarkers(),
      ],
    );
  }

  // ── Evacuation Route Lines ────────────────────────────────────────────────

  // ── Markers ───────────────────────────────────────────────────────────────

  PolygonLayer _buildAdminAreaPolygons() {
    final polygons = _filteredAdminAreas.map((area) {
      final points = area.boundary.map((p) => LatLng(p.lat, p.lon)).toList();
      final color = _hazardColor(area.hazardType);
      final fillAlpha = (35 + (area.riskScore * 90)).round().clamp(35, 125);

      return Polygon(
        points: points,
        color: color.withAlpha(fillAlpha),
        borderColor: color.withAlpha(220),
        borderStrokeWidth: 2,
      );
    }).toList();

    return PolygonLayer(polygons: polygons);
  }

  MarkerLayer _buildMarkers() {
    final markers = <Marker>[];

    // Area labels for administrative polygons
    if (_filteredAdminAreas.isNotEmpty) {
      for (final area in _filteredAdminAreas) {
        final centre = _areaCentroid(area);
        markers.add(
          Marker(
            point: centre,
            width: 18,
            height: 18,
            child: GestureDetector(
              onTap: () => _showAdminAreaInfo(area),
              child: Container(
                decoration: BoxDecoration(
                  color: _hazardColor(area.hazardType),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(45),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } else if (_mapData != null) {
      // Fallback to zone points if administrative polygons are not available.
      for (final zone in _filteredZones) {
        markers.add(
          Marker(
            point: LatLng(zone.latitude, zone.longitude),
            width: 14,
            height: 14,
            child: GestureDetector(
              onTap: () => _showZoneInfo(zone),
              child: Container(
                decoration: BoxDecoration(
                  color: _hazardColor(zone.hazardType),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    // User location marker
    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.8),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return MarkerLayer(markers: markers);
  }

  // ── Top Controls ──────────────────────────────────────────────────────────

  Widget _buildTopControls() {
    return Positioned(
      top: 8,
      left: 12,
      right: 12,
      child: SafeArea(
        child: Row(
          children: [
            _buildFilterChip('Flood', 'flood'),
            _buildFilterChip('Landslide', 'landslide'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String type) {
    final isSelected = _hazardFilter == type;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          onTap: () {
            if (_hazardFilter == type) return;
            setState(() => _hazardFilter = type);
            _loadMapData();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? _hazardColor(type) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4),
              ],
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Legend ─────────────────────────────────────────────────────────────────

  Widget _buildLegend() {
    return Positioned(
      bottom: 16,
      left: 12,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 6),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'HAZARD MAP',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            _buildLegendItem(_hazardColor('flood'), 'Flood Risk Zone'),
            _buildLegendItem(_hazardColor('landslide'), 'Landslide Risk Zone'),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color.withAlpha(128),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: color, width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── Loading Overlay ───────────────────────────────────────────────────────

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white.withAlpha(153),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading hazard zones...',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Locate Me Button ──────────────────────────────────────────────────────

  Widget _buildLocateButton() {
    return Positioned(
      bottom: 16,
      right: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'locate',
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () async {
              await _getUserLocation();
              if (_userLocation != null) {
                _mapController.move(_userLocation!, 15);
              }
            },
            child: _locatingUser
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'refresh',
            mini: true,
            backgroundColor: Colors.white,
            onPressed: _loadMapData,
            child: const Icon(Icons.refresh, color: Color(0xFF2E7D32)),
          ),
        ],
      ),
    );
  }

  // ── Info Bottom Sheets ────────────────────────────────────────────────────

  void _showZoneInfo(RiskZone zone) {
    final color = _hazardColor(zone.hazardType);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _hazardIcon(zone.hazardType),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        zone.hazardType.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Risk Score Bar
            Row(
              children: [
                const Text(
                  'Risk Score: ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '${(zone.riskScore * 100).toInt()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: zone.riskScore,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              zone.description,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.radar, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Radius: ${zone.radiusKm} km',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${zone.latitude.toStringAsFixed(4)}, ${zone.longitude.toStringAsFixed(4)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showAdminAreaInfo(AdminArea area) {
    final color = _hazardColor(area.hazardType);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              area.name,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              area.hazardType.toUpperCase(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'Area Risk: ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '${(area.riskScore * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: area.riskScore,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Based on ${area.zoneCount} mapped hazard point(s) inside this administrative area.',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<RiskZone> get _filteredZones {
    if (_mapData == null) return const [];
    return _mapData!.riskZones
        .where(
          (zone) =>
              zone.hazardType == 'flood' || zone.hazardType == 'landslide',
        )
        .where((zone) => zone.hazardType == _hazardFilter)
        .toList();
  }

  List<AdminArea> get _filteredAdminAreas {
    if (_mapData == null) return const [];
    return _mapData!.adminAreas
        .where((a) => a.hazardType == _hazardFilter)
        .toList();
  }

  LatLng _areaCentroid(AdminArea area) {
    if (area.boundary.isEmpty) return _defaultCentre;
    final lat =
        area.boundary.map((p) => p.lat).reduce((a, b) => a + b) /
        area.boundary.length;
    final lon =
        area.boundary.map((p) => p.lon).reduce((a, b) => a + b) /
        area.boundary.length;
    return LatLng(lat, lon);
  }

  Color _hazardColor(String hazardType) {
    return switch (hazardType) {
      'flood' => const Color(0xFF1D4ED8),
      'landslide' => const Color(0xFFD97706),
      _ => Colors.grey,
    };
  }

  IconData _hazardIcon(String hazardType) {
    return switch (hazardType) {
      'flood' => Icons.flood,
      'landslide' => Icons.terrain,
      _ => Icons.help_outline,
    };
  }
}
