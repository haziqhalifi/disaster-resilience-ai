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
  String? _mapError;
  MapData? _mapData;

  LatLng? _userLocation;
  bool _locatingUser = false;

  // Layer toggle state
  bool _showDangerZones = true;
  bool _showWarningZones = true;
  bool _showSafeZones = true;
  bool _showEvacRoutes = true;
  bool _showEvacCentres = true;

  // Filter
  String? _hazardFilter; // null = all

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
      _mapError = null;
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
          _mapError = e.toString().replaceFirst('Exception: ', '');
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
        // Top search bar + filter chips
        _buildTopControls(),
        // Legend panel
        _buildLegend(),
        // Layer toggle panel
        _buildLayerPanel(),
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
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.disaster.resilience.ai',
        ),
        // Risk zone circles
        if (_mapData != null) _buildZoneCircles(),
        // Evacuation routes
        if (_mapData != null && _showEvacRoutes) _buildRouteLines(),
        // Markers: Evacuation centres + user location
        _buildMarkers(),
      ],
    );
  }

  // ── Risk Zone Circles ─────────────────────────────────────────────────────

  CircleLayer _buildZoneCircles() {
    final circles = <CircleMarker>[];

    for (final zone in _mapData!.riskZones) {
      final show = switch (zone.zoneType) {
        'danger' => _showDangerZones,
        'warning' => _showWarningZones,
        'safe' => _showSafeZones,
        _ => true,
      };
      if (!show) continue;

      final color = _zoneColor(zone.zoneType);
      circles.add(
        CircleMarker(
          point: LatLng(zone.latitude, zone.longitude),
          radius: zone.radiusKm * 1000, // Convert km to meters
          useRadiusInMeter: true,
          color: color.withAlpha(51),
          borderColor: color.withAlpha(153),
          borderStrokeWidth: 2,
        ),
      );
    }

    return CircleLayer(circles: circles);
  }

  // ── Evacuation Route Lines ────────────────────────────────────────────────

  PolylineLayer _buildRouteLines() {
    final polylines = <Polyline>[];

    for (final route in _mapData!.evacuationRoutes) {
      final routeColor = _routeStatusColor(route.status);
      final points = <LatLng>[
        LatLng(route.startLat, route.startLon),
        ...route.waypoints.map((w) => LatLng(w.lat, w.lon)),
        LatLng(route.endLat, route.endLon),
      ];

      polylines.add(
        Polyline(
          points: points,
          color: routeColor,
          strokeWidth: 4,
          pattern: route.status == 'blocked'
              ? const StrokePattern.dotted()
              : const StrokePattern.solid(),
        ),
      );
    }

    return PolylineLayer(polylines: polylines);
  }

  // ── Markers ───────────────────────────────────────────────────────────────

  MarkerLayer _buildMarkers() {
    final markers = <Marker>[];

    // Evacuation centre markers
    if (_mapData != null && _showEvacCentres) {
      for (final centre in _mapData!.evacuationCentres) {
        markers.add(
          Marker(
            point: LatLng(centre.latitude, centre.longitude),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _showCentreInfo(centre),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(64),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.local_hospital, color: Colors.white, size: 22),
              ),
            ),
          ),
        );
      }
    }

    // Risk zone label markers (center of each zone)
    if (_mapData != null) {
      for (final zone in _mapData!.riskZones) {
        final show = switch (zone.zoneType) {
          'danger' => _showDangerZones,
          'warning' => _showWarningZones,
          'safe' => _showSafeZones,
          _ => true,
        };
        if (!show) continue;

        markers.add(
          Marker(
            point: LatLng(zone.latitude, zone.longitude),
            width: 120,
            height: 40,
            child: GestureDetector(
              onTap: () => _showZoneInfo(zone),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _zoneColor(zone.zoneType), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_zoneIcon(zone.zoneType), size: 14, color: _zoneColor(zone.zoneType)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${(zone.riskScore * 100).toInt()}%',
                        style: TextStyle(
                          color: _zoneColor(zone.zoneType),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
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

    // User location marker
    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 36,
          height: 36,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
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
        child: Column(
          children: [
            // Search bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search location...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Hazard filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', null),
                  _buildFilterChip('Flood', 'flood'),
                  _buildFilterChip('Landslide', 'landslide'),
                  _buildFilterChip('Typhoon', 'typhoon'),
                  _buildFilterChip('Earthquake', 'earthquake'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? type) {
    final isSelected = _hazardFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          setState(() => _hazardFilter = type);
          _loadMapData();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.w600,
              fontSize: 12,
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
              'AI RISK MAP',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            _buildLegendItem(Colors.red, 'Danger Zone'),
            _buildLegendItem(Colors.orange, 'Warning Zone'),
            _buildLegendItem(const Color(0xFF2E7D32), 'Safe Zone'),
            _buildLegendItem(Colors.blue, 'Evacuation Route'),
            _buildLegendItem(Colors.green[800]!, 'Evacuation Centre'),
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

  // ── Layer Toggle Panel ────────────────────────────────────────────────────

  Widget _buildLayerPanel() {
    return Positioned(
      top: 120,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 6),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLayerToggle(Icons.dangerous, Colors.red, _showDangerZones,
                (v) => setState(() => _showDangerZones = v)),
            _buildLayerToggle(Icons.warning_amber, Colors.orange, _showWarningZones,
                (v) => setState(() => _showWarningZones = v)),
            _buildLayerToggle(Icons.check_circle, const Color(0xFF2E7D32), _showSafeZones,
                (v) => setState(() => _showSafeZones = v)),
            _buildLayerToggle(Icons.route, Colors.blue, _showEvacRoutes,
                (v) => setState(() => _showEvacRoutes = v)),
            _buildLayerToggle(Icons.local_hospital, Colors.teal, _showEvacCentres,
                (v) => setState(() => _showEvacCentres = v)),
          ],
        ),
      ),
    );
  }

  Widget _buildLayerToggle(
    IconData icon,
    Color color,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: value ? color.withAlpha(26) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: value ? color : Colors.grey[400],
          size: 22,
        ),
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
              'Loading risk zones...',
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
    final color = _zoneColor(zone.zoneType);
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
                  child: Icon(_zoneIcon(zone.zoneType), color: color, size: 24),
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
                        '${zone.zoneType.toUpperCase()} • ${zone.hazardType.toUpperCase()}',
                        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
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
                const Text('Risk Score: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  '${(zone.riskScore * 100).toInt()}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
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
              style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5),
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

  void _showCentreInfo(EvacuationCentre centre) {
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
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_hospital, color: Color(0xFF2E7D32), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        centre.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const Text(
                        'EVACUATION CENTRE',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Occupancy bar
            Row(
              children: [
                const Text('Occupancy: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  '${centre.currentOccupancy} / ${centre.capacity}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  ' (${centre.occupancyPercent.toStringAsFixed(0)}%)',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: centre.occupancyPercent / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  centre.occupancyPercent > 80
                      ? Colors.red
                      : centre.occupancyPercent > 50
                          ? Colors.orange
                          : const Color(0xFF2E7D32),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (centre.address.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      centre.address,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (centre.contactPhone != null) ...[
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    centre.contactPhone!,
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _zoneColor(String zoneType) {
    return switch (zoneType) {
      'danger' => Colors.red,
      'warning' => Colors.orange,
      'safe' => const Color(0xFF2E7D32),
      _ => Colors.grey,
    };
  }

  IconData _zoneIcon(String zoneType) {
    return switch (zoneType) {
      'danger' => Icons.dangerous,
      'warning' => Icons.warning_amber_rounded,
      'safe' => Icons.check_circle,
      _ => Icons.help_outline,
    };
  }

  Color _routeStatusColor(String status) {
    return switch (status) {
      'clear' => Colors.blue[700]!,
      'partial' => Colors.orange,
      'blocked' => Colors.red,
      _ => Colors.blue,
    };
  }
}
