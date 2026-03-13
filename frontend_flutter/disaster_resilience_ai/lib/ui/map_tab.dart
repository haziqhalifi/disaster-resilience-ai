import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:disaster_resilience_ai/l10n/app_localizations.dart';
import 'package:disaster_resilience_ai/models/family_model.dart';
import 'package:disaster_resilience_ai/models/risk_map_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/ui/submit_report_page.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key, this.accessToken = ''});

  final String accessToken;

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

  // Filter ('all', 'flood', 'landslide')
  String _hazardFilter = 'all';

  // ── Search ────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;

  // ── Community reports state ───────────────────────────────────────────────
  List<Map<String, dynamic>> _reports = [];
  Timer? _reportRefreshDebounce;
  int _reportLoadGeneration = 0;

  // ── Family member locations ───────────────────────────────────────────────
  List<FamilyMemberLocation> _familyMembers = [];
  Timer? _familyPollTimer;

  // Default centre: Kuantan, Pahang
  final LatLng _defaultCentre = const LatLng(3.8077, 103.3260);

  @override
  void initState() {
    super.initState();
    _loadMapData();
    _getUserLocation();
    _loadFamilyLocations();
    _familyPollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadFamilyLocations(),
    );
  }

  @override
  void didUpdateWidget(covariant MapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken) {
      _scheduleReportRefresh(force: true);
      _loadFamilyLocations();
    }
  }

  void _scheduleReportRefresh({bool force = false}) {
    _reportRefreshDebounce?.cancel();
    _reportRefreshDebounce = Timer(
      const Duration(milliseconds: 250),
      () => _loadReports(force: force),
    );
  }

  Future<void> _loadReports({bool force = false}) async {
    if (widget.accessToken.isEmpty) {
      if (mounted && _reports.isNotEmpty) {
        setState(() => _reports = []);
      }
      return;
    }
    final loadGeneration = ++_reportLoadGeneration;

    try {
      final payload = await _api.fetchAllMyReports(
        accessToken: widget.accessToken,
      );
      final rows = (payload['reports'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .where(
            (r) =>
                (r['latitude'] as num?) != null &&
                (r['longitude'] as num?) != null,
          )
          .toList();
      if (!mounted || loadGeneration != _reportLoadGeneration) return;
      setState(() => _reports = rows);
    } catch (_) {}
  }

  @override
  void dispose() {
    _reportRefreshDebounce?.cancel();
    _familyPollTimer?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMapData() async {
    setState(() {
      _loadingMap = true;
    });
    try {
      final json = await _api.fetchMapData(
        hazardType: _hazardFilter == 'all' ? null : _hazardFilter,
      );
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

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
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

  Future<void> _loadFamilyLocations() async {
    if (widget.accessToken.isEmpty) {
      if (mounted && _familyMembers.isNotEmpty) {
        setState(() => _familyMembers = []);
      }
      return;
    }
    try {
      final payload = await _api.fetchFamilyLocations(
        accessToken: widget.accessToken,
      );
      final rows = (payload['members'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => FamilyMemberLocation.fromJson(e))
          .toList();
      if (mounted) setState(() => _familyMembers = rows);
    } catch (_) {}
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
        onTap: (_, latLng) => _onMapTapped(latLng),
        onMapReady: () {
          _scheduleReportRefresh(force: true);
        },
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
        // Markers: localized hazard pins + user location
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
      // Risk areas are represented directly as colored polygons.
      final fillAlpha = (20 + (area.riskScore * 40)).round().clamp(20, 60);

      return Polygon(
        points: points,
        color: color.withAlpha(fillAlpha),
        borderColor: color.withAlpha(150),
        borderStrokeWidth: 1.3,
      );
    }).toList();

    return PolygonLayer(polygons: polygons);
  }

  void _onMapTapped(LatLng point) {
    if (_loadingMap || _mapData == null) return;
    final area = _adminAreaAtPoint(point);
    if (area != null) {
      _showAdminAreaInfo(area);
    }
  }

  AdminArea? _adminAreaAtPoint(LatLng point) {
    final matched = _filteredAdminAreas
        .where((area) => _isPointInPolygon(point, area.boundary))
        .toList();
    if (matched.isEmpty) return null;
    matched.sort((a, b) => b.riskScore.compareTo(a.riskScore));
    return matched.first;
  }

  bool _isPointInPolygon(LatLng point, List<RouteWaypoint> polygon) {
    if (polygon.length < 3) return false;

    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].lon;
      final yi = polygon[i].lat;
      final xj = polygon[j].lon;
      final yj = polygon[j].lat;

      final intersects =
          ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) * (point.latitude - yi) / (yj - yi + 1e-12) + xi);

      if (intersects) inside = !inside;
    }
    return inside;
  }

  MarkerLayer _buildMarkers() {
    final markers = <Marker>[];

    if (_mapData != null) {
      for (final disaster in _filteredOfficialDisasters) {
        markers.add(
          Marker(
            point: LatLng(disaster.latitude, disaster.longitude),
            width: 52,
            height: 52,
            child: GestureDetector(
              onTap: () => _showOfficialDisasterInfo(disaster),
              child: Center(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _officialDisasterColor(disaster.hazardType),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(48),
                        blurRadius: 9,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _officialDisasterIcon(disaster.hazardType),
                      size: 20,
                      color: _officialDisasterColor(disaster.hazardType),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    // Evacuation centre markers (PPS)
    if (_mapData != null) {
      for (final centre in _mapData!.evacuationCentres) {
        markers.add(
          Marker(
            point: LatLng(centre.latitude, centre.longitude),
            width: 52,
            height: 52,
            child: GestureDetector(
              onTap: () => _showEvacCentreInfo(centre),
              child: Center(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(48),
                        blurRadius: 9,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.house_siding, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    // Community report markers
    for (final report in _reports) {
      final lat = (report['latitude'] as num).toDouble();
      final lon = (report['longitude'] as num).toDouble();
      final type = (report['report_type'] as String? ?? '').toLowerCase();
      final color = _reportColor(type);
      markers.add(
        Marker(
          point: LatLng(lat, lon),
          width: 48,
          height: 48,
          child: GestureDetector(
            onTap: () => _showReportInfo(report),
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(85),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(35),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _reportMarkerIcon(type),
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Family member markers
    for (final member in _familyMembers) {
      if (!member.hasLocation) continue;
      final zone = _zoneStatusForLatLon(member.latitude!, member.longitude!);
      final pinColor = switch (zone) {
        'danger' => Colors.red,
        'warning' => Colors.orange,
        _ => const Color(0xFF2E7D32),
      };
      markers.add(
        Marker(
          point: LatLng(member.latitude!, member.longitude!),
          width: 90,
          height: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: pinColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  member.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.location_on, color: pinColor, size: 28),
            ],
          ),
        ),
      );
    }

    // User location marker
    if (_userLocation != null) {
      final userZone = _zoneStatusForLatLon(
        _userLocation!.latitude,
        _userLocation!.longitude,
      );
      final dotColor = switch (userZone) {
        'danger' => Colors.red,
        'warning' => Colors.orange,
        _ => Colors.blue,
      };
      markers.add(
        Marker(
          point: _userLocation!,
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: dotColor.withAlpha(50),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(color: dotColor.withAlpha(80), blurRadius: 6),
                ],
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            const SizedBox(height: 8),
            _buildHazardChips(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? theme.cardColor : Colors.white;
    final borderColor = isDark
        ? theme.colorScheme.outline.withAlpha(170)
        : const Color(0xFFE2E8F0);
    final hintColor = isDark ? Colors.grey[400]! : Colors.grey[500]!;
    final shadowColor = isDark
        ? Colors.black.withAlpha(70)
        : Colors.black.withAlpha(20);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 4)],
      ),
      child: TextField(
        controller: _searchController,
        onSubmitted: _searchLocation,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1E293B),
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: _tr(
            en: 'Search location...',
            id: 'Cari lokasi...',
            ms: 'Cari lokasi...',
            zh: '搜索地点...',
          ),
          hintStyle: TextStyle(color: hintColor, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: hintColor, size: 20),
          suffixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : (_searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: hintColor, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildHazardChips() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    final options = [
      ('all', l10n.mapFilterAll, Icons.layers_outlined, Colors.grey.shade600),
      ('flood', l10n.mapFilterFlood, Icons.flood, const Color(0xFF1D4ED8)),
      (
        'landslide',
        l10n.mapFilterLandslide,
        Icons.terrain,
        const Color(0xFFD97706),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((o) {
          final selected = _hazardFilter == o.$1;
          final chipColor = o.$4;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selected,
              showCheckmark: false,
              avatar: Icon(
                o.$3,
                size: 16,
                color: selected ? Colors.white : chipColor,
              ),
              label: Text(
                o.$2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : (isDark ? scheme.onSurface : const Color(0xFF374151)),
                ),
              ),
              backgroundColor: isDark ? theme.cardColor : Colors.white,
              selectedColor: chipColor,
              side: BorderSide(
                color: selected
                    ? chipColor
                    : (isDark
                          ? scheme.outline.withAlpha(170)
                          : const Color(0xFFE2E8F0)),
              ),
              elevation: 2,
              shadowColor: Colors.black.withAlpha(30),
              onSelected: (_) {
                if (_hazardFilter == o.$1) return;
                setState(() => _hazardFilter = o.$1);
                _loadMapData();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _searching = true);
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search')
          .replace(
            queryParameters: {
              'q': query.trim(),
              'format': 'json',
              'limit': '1',
              'countrycodes': 'my',
            },
          );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'DisasterResilienceAI/1.0'},
      );
      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List<dynamic>;
        if (results.isNotEmpty) {
          final lat = double.parse(results[0]['lat'] as String);
          final lon = double.parse(results[0]['lon'] as String);
          if (mounted) {
            _mapController.move(LatLng(lat, lon), 13.0);
            setState(() => _userLocation = LatLng(lat, lon));
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _tr(
                  en: 'Location not found',
                  id: 'Lokasi tidak ditemukan',
                  ms: 'Lokasi tidak ditemui',
                  zh: '未找到地点',
                ),
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  // ── Legend ─────────────────────────────────────────────────────────────────

  Widget _buildLegend() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final panelBg = isDark ? theme.cardColor : Colors.white;
    final panelBorder = isDark
        ? scheme.outline.withAlpha(170)
        : const Color(0xFFE2E8F0);
    final panelTitle = isDark ? scheme.onSurface : const Color(0xFF1E293B);
    final shadowColor = isDark
        ? Colors.black.withAlpha(70)
        : Colors.black.withAlpha(26);

    return Positioned(
      bottom: 16,
      left: 12,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: panelBorder),
          boxShadow: [BoxShadow(color: shadowColor, blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.mapLegendTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
                color: panelTitle,
              ),
            ),
            const SizedBox(height: 8),
            _buildLegendItem(
              _hazardColor('flood'),
              l10n.mapLegendFloodRiskZone,
              textColor: isDark
                  ? scheme.onSurface.withAlpha(220)
                  : const Color(0xFF334155),
            ),
            _buildLegendItem(
              _hazardColor('landslide'),
              l10n.mapLegendLandslideRiskZone,
              textColor: isDark
                  ? scheme.onSurface.withAlpha(220)
                  : const Color(0xFF334155),
            ),
            _buildLegendItem(
              const Color(0xFF374151),
              l10n.mapLegendCommunityReports,
              textColor: isDark
                  ? scheme.onSurface.withAlpha(220)
                  : const Color(0xFF334155),
              icon: Icons.flag_rounded,
              shape: BoxShape.circle,
            ),
            _buildLegendItem(
              const Color(0xFFF59E0B),
              _tr(
                en: 'Official Disasters',
                id: 'Bencana resmi',
                ms: 'Bencana rasmi',
                zh: '官方灾害',
              ),
              textColor: isDark
                  ? scheme.onSurface.withAlpha(220)
                  : const Color(0xFF334155),
              icon: Icons.campaign_rounded,
              swatchFill: const Color(0xFF111827),
            ),
            if (_familyMembers.any((m) => m.hasLocation))
              _buildLegendItem(
                const Color(0xFF2E7D32),
                _tr(
                  en: 'Family Member',
                  id: 'Anggota Keluarga',
                  ms: 'Ahli Keluarga',
                  zh: '家庭成员',
                ),
                textColor: isDark
                    ? scheme.onSurface.withAlpha(220)
                    : const Color(0xFF334155),
                icon: Icons.person_pin_circle,
                shape: BoxShape.circle,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(
    Color color,
    String label, {
    required Color textColor,
    IconData? icon,
    BoxShape shape = BoxShape.circle,
    Color? swatchFill,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: swatchFill ?? color.withAlpha(128),
              shape: shape,
              borderRadius: shape == BoxShape.circle
                  ? null
                  : BorderRadius.circular(3),
              border: Border.all(color: color, width: 1.5),
            ),
            child: icon != null
                ? Icon(icon, size: 7, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading Overlay ───────────────────────────────────────────────────────

  Widget _buildLoadingOverlay() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final overlayTextColor = isDark
        ? scheme.onSurface
        : const Color(0xFF1E293B);
    final overlayBg = isDark
        ? Colors.black.withAlpha(120)
        : Colors.white.withAlpha(153);

    return Container(
      color: overlayBg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.mapLoadingHazardZones,
              style: TextStyle(
                color: overlayTextColor,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final fabBg = isDark ? theme.cardColor : Colors.white;
    final fabFg = isDark ? scheme.primary : const Color(0xFF2E7D32);

    return Positioned(
      bottom: 16,
      right: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'report',
            mini: false,
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            tooltip: _tr(
              en: 'Report incident',
              id: 'Laporkan insiden',
              ms: 'Laporkan insiden',
              zh: '报告事件',
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SubmitReportPage(accessToken: widget.accessToken),
                ),
              );
              _scheduleReportRefresh(force: true);
            },
            child: const Icon(Icons.flag_rounded, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'locate',
            mini: true,
            backgroundColor: fabBg,
            foregroundColor: fabFg,
            tooltip: _tr(
              en: 'Locate me',
              id: 'Temukan saya',
              ms: 'Cari saya',
              zh: '定位我',
            ),
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
                : Icon(Icons.my_location, color: fabFg),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'refresh',
            mini: true,
            backgroundColor: fabBg,
            foregroundColor: fabFg,
            tooltip: _tr(
              en: 'Refresh map',
              id: 'Muat ulang peta',
              ms: 'Muat semula peta',
              zh: '刷新地图',
            ),
            onPressed: () {
              _loadMapData();
              _scheduleReportRefresh(force: true);
            },
            child: Icon(Icons.refresh, color: fabFg),
          ),
        ],
      ),
    );
  }

  // ── Info Bottom Sheets ────────────────────────────────────────────────────

  void _showZoneInfo(RiskZone zone) {
    final l10n = AppLocalizations.of(context);
    final color = _hazardColor(zone.hazardType);
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? scheme.onSurface
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        _hazardLabel(zone.hazardType, l10n).toUpperCase(),
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
                Text(
                  l10n.mapRiskScoreLabel,
                  style: TextStyle(
                    color: isDark ? scheme.onSurface : null,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
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
                backgroundColor: isDark ? Colors.white24 : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              zone.description,
              style: TextStyle(
                color: isDark
                    ? scheme.onSurface.withAlpha(220)
                    : Colors.grey[700],
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.radar,
                  size: 16,
                  color: isDark
                      ? scheme.onSurface.withAlpha(170)
                      : Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.mapRadiusKm(zone.radiusKm.toString()),
                  style: TextStyle(
                    color: isDark
                        ? scheme.onSurface.withAlpha(180)
                        : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: isDark
                      ? scheme.onSurface.withAlpha(170)
                      : Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  '${zone.latitude.toStringAsFixed(4)}, ${zone.longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    color: isDark
                        ? scheme.onSurface.withAlpha(180)
                        : Colors.grey[600],
                    fontSize: 12,
                  ),
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
    final l10n = AppLocalizations.of(context);
    final color = _hazardColor(area.hazardType);
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
            const SizedBox(height: 16),
            Text(
              area.name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? scheme.onSurface : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _hazardLabel(area.hazardType, l10n).toUpperCase(),
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
                Text(
                  l10n.mapAreaRiskLabel,
                  style: TextStyle(
                    color: isDark ? scheme.onSurface : null,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
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
                backgroundColor: isDark ? Colors.white24 : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.mapAdminAreaBasis(area.zoneCount),
              style: TextStyle(
                color: isDark
                    ? scheme.onSurface.withAlpha(220)
                    : Colors.grey[700],
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

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Returns 'danger', 'warning', 'safe', or null if outside all zones.
  String? _zoneStatusForLatLon(double lat, double lon) {
    if (_mapData == null) return null;
    String? worst;
    for (final zone in _mapData!.riskZones) {
      final distKm = _haversineKm(lat, lon, zone.latitude, zone.longitude);
      if (distKm <= zone.radiusKm) {
        if (zone.zoneType == 'danger') return 'danger';
        if (zone.zoneType == 'warning' && worst != 'danger') worst = 'warning';
        if (zone.zoneType == 'safe' && worst == null) worst = 'safe';
      }
    }
    return worst;
  }

  List<RiskZone> get _filteredZones {
    if (_mapData == null) return const [];
    return _mapData!.riskZones
        .where(
          (zone) =>
              zone.hazardType == 'flood' || zone.hazardType == 'landslide',
        )
        .where(
          (zone) => _hazardFilter == 'all' || zone.hazardType == _hazardFilter,
        )
        .toList();
  }

  List<AdminArea> get _filteredAdminAreas {
    if (_mapData == null) return const [];
    return _mapData!.adminAreas
        .where((a) => _hazardFilter == 'all' || a.hazardType == _hazardFilter)
        .toList();
  }

  List<OfficialDisaster> get _filteredOfficialDisasters {
    if (_mapData == null) return const [];
    return _mapData!.officialDisasters
        .where((d) => _hazardFilter == 'all' || d.hazardType == _hazardFilter)
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

  Color _reportColor(String reportType) {
    return switch (reportType) {
      'flood' || 'water_rising' => const Color(0xFF1D4ED8),
      'landslide' => const Color(0xFFD97706),
      'fire' => const Color(0xFFDC2626),
      'blocked_road' => const Color(0xFF7C3AED),
      'injury' || 'medical' => const Color(0xFFDB2777),
      _ => const Color(0xFF374151),
    };
  }

  IconData _reportMarkerIcon(String reportType) {
    return switch (reportType) {
      'flood' || 'water_rising' => Icons.flood_rounded,
      'landslide' => Icons.terrain,
      'fire' => Icons.local_fire_department_rounded,
      'blocked_road' => Icons.block_rounded,
      'injury' || 'medical' => Icons.medical_services_rounded,
      _ => Icons.flag_rounded,
    };
  }

  Color _officialDisasterColor(String hazardType) {
    return switch (hazardType) {
      'flood' => const Color(0xFF38BDF8),
      'landslide' => const Color(0xFFF59E0B),
      'fire' => const Color(0xFFEF4444),
      _ => const Color(0xFFFACC15),
    };
  }

  IconData _officialDisasterIcon(String hazardType) {
    return switch (hazardType) {
      'flood' => Icons.flood_rounded,
      'landslide' => Icons.warning_amber_rounded,
      'fire' => Icons.local_fire_department_rounded,
      _ => Icons.gpp_maybe_rounded,
    };
  }

  Future<Map<String, dynamic>> _toggleReportVouch(
    Map<String, dynamic> report,
  ) async {
    final token = widget.accessToken;
    final reportId = report['id']?.toString();
    if (token.isEmpty || reportId == null || reportId.isEmpty) {
      throw Exception('Sign in required to vouch.');
    }

    final currentlyVouched = report['current_user_vouched'] == true;
    if (currentlyVouched) {
      await _api.unvouchReport(accessToken: token, reportId: reportId);
    } else {
      await _api.vouchReport(accessToken: token, reportId: reportId);
    }

    final currentCount = (report['vouch_count'] as num?)?.toInt() ?? 0;
    final updated = Map<String, dynamic>.from(report)
      ..['current_user_vouched'] = !currentlyVouched
      ..['vouch_count'] = currentlyVouched
          ? (currentCount > 0 ? currentCount - 1 : 0)
          : currentCount + 1;

    if (mounted) {
      setState(() {
        _reports = _reports
            .map((r) => r['id']?.toString() == reportId ? updated : r)
            .toList();
      });
    }
    return updated;
  }

  void _showReportInfo(Map<String, dynamic> report) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final type = (report['report_type'] as String? ?? 'report').toLowerCase();
    final color = _reportColor(type);
    final title = (report['location_name'] as String?)?.trim();
    final description = (report['description'] as String?)?.trim() ?? '';
    final vulnerable = report['vulnerable_person'] == true;
    final confidence = (report['confidence_score'] as num?)?.toDouble();
    final mediaUrls = (report['media_urls'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    Map<String, dynamic> sheetReport = Map<String, dynamic>.from(report);
    bool vouching = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? theme.cardColor : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final vouches = (sheetReport['vouch_count'] as num?)?.toInt() ?? 0;
          final userVouched = sheetReport['current_user_vouched'] == true;

          return Padding(
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.flag, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title?.isNotEmpty == true
                                ? title!
                                : type.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? scheme.onSurface
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            type.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (mediaUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      mediaUrls.first,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 72,
                        alignment: Alignment.center,
                        color: isDark
                            ? const Color(0xFF1A1F1A)
                            : const Color(0xFFF1F5F9),
                        child: Text(
                          _tr(
                            en: 'Photo unavailable',
                            id: 'Foto tidak tersedia',
                            ms: 'Foto tidak tersedia',
                            zh: '图片不可用',
                          ),
                          style: TextStyle(
                            color: isDark ? scheme.onSurface : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(
                      color: isDark
                          ? scheme.onSurface.withAlpha(200)
                          : Colors.grey[700],
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (vulnerable)
                      _reportChip(
                        Icons.warning_amber_rounded,
                        _tr(
                          en: 'Needs help',
                          id: 'Butuh bantuan',
                          ms: 'Perlu bantuan',
                          zh: '需要帮助',
                        ),
                        isDark ? const Color(0xFFFCA5A5) : Colors.red.shade700,
                        isDark ? const Color(0xFF3E1D1D) : Colors.red.shade50,
                      ),
                    if (confidence != null)
                      _reportChip(
                        Icons.smart_toy_outlined,
                        _aiCredLabel(confidence),
                        _aiCredFg(confidence, isDark),
                        _aiCredBg(confidence, isDark),
                      ),
                    if (vouches > 0)
                      _reportChip(
                        Icons.thumb_up_alt_outlined,
                        _vouchLabel(vouches),
                        isDark ? const Color(0xFF93C5FD) : Colors.blue.shade700,
                        isDark ? const Color(0xFF192A3A) : Colors.blue.shade50,
                      ),
                    _reportChip(
                      Icons.verified,
                      _tr(
                        en: 'Verified',
                        id: 'Terverifikasi',
                        ms: 'Disahkan',
                        zh: '已验证',
                      ),
                      isDark ? const Color(0xFF4CAF50) : Colors.green.shade700,
                      isDark ? const Color(0xFF1A2D1A) : Colors.green.shade50,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: vouching
                        ? null
                        : () async {
                            try {
                              setSheetState(() => vouching = true);
                              final updated = await _toggleReportVouch(
                                sheetReport,
                              );
                              if (!ctx.mounted) return;
                              setSheetState(() {
                                sheetReport = updated;
                                vouching = false;
                              });
                            } catch (e) {
                              if (!ctx.mounted) return;
                              setSheetState(() => vouching = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                    icon: vouching
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            userVouched
                                ? Icons.thumb_up
                                : Icons.thumb_up_alt_outlined,
                          ),
                    label: Text(
                      userVouched
                          ? _tr(
                              en: 'Remove Vouch',
                              id: 'Hapus verifikasi',
                              ms: 'Buang sokongan',
                              zh: '取消确认',
                            )
                          : _tr(
                              en: 'Vouch This Report',
                              id: 'Verifikasi laporan ini',
                              ms: 'Sokong laporan ini',
                              zh: '为此报告确认',
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEvacCentreInfo(EvacuationCentre centre) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    const green = Color(0xFF2E7D32);
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
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: green.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.house_siding, color: green, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        centre.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? scheme.onSurface : const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        _tr(
                          en: 'PPS · Evacuation Centre',
                          id: 'PPS · Pusat Evakuasi',
                          ms: 'PPS · Pusat Pemindahan Sementara',
                          zh: '临时疏散中心',
                        ),
                        style: const TextStyle(
                          color: green,
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
            Row(
              children: [
                Text(
                  _tr(en: 'Occupancy: ', id: 'Hunian: ', ms: 'Orang Dalam: ', zh: '入住率：'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? scheme.onSurface : null,
                  ),
                ),
                Text(
                  '${centre.currentOccupancy} / ${centre.capacity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: green,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: centre.occupancyPercent / 100,
                minHeight: 8,
                backgroundColor: isDark ? Colors.white24 : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  centre.occupancyPercent >= 80 ? Colors.orange : green,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (centre.address.isNotEmpty)
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: isDark ? scheme.onSurface.withAlpha(170) : Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      centre.address,
                      style: TextStyle(
                        color: isDark ? scheme.onSurface.withAlpha(180) : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            if (centre.contactPhone != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.phone,
                    size: 14,
                    color: isDark ? scheme.onSurface.withAlpha(170) : Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    centre.contactPhone!,
                    style: TextStyle(
                      color: isDark ? scheme.onSurface.withAlpha(180) : Colors.grey[600],
                      fontSize: 12,
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

  void _showOfficialDisasterInfo(OfficialDisaster disaster) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final color = _officialDisasterColor(disaster.hazardType);

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
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    _officialDisasterIcon(disaster.hazardType),
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        disaster.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? scheme.onSurface
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        _tr(
                          en: 'Official NADMA incident',
                          id: 'Insiden resmi NADMA',
                          ms: 'Insiden rasmi NADMA',
                          zh: 'NADMA 官方事件',
                        ),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              [
                disaster.districtName,
                disaster.stateName,
              ].where((part) => part.isNotEmpty).join(', '),
              style: TextStyle(
                color: isDark
                    ? scheme.onSurface.withAlpha(210)
                    : Colors.grey[700],
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _reportChip(
                  Icons.shield_outlined,
                  disaster.status,
                  color,
                  isDark ? const Color(0xFF1F2937) : color.withAlpha(24),
                ),
                if (disaster.evacuationCentres > 0)
                  _reportChip(
                    Icons.house_siding_outlined,
                    _tr(
                      en: '${disaster.evacuationCentres} PPS',
                      id: '${disaster.evacuationCentres} PPS',
                      ms: '${disaster.evacuationCentres} PPS',
                      zh: '${disaster.evacuationCentres} 个疏散中心',
                    ),
                    isDark ? const Color(0xFFBFDBFE) : Colors.blue.shade700,
                    isDark ? const Color(0xFF192A3A) : Colors.blue.shade50,
                  ),
                if (disaster.affectedFamilies > 0)
                  _reportChip(
                    Icons.groups_2_outlined,
                    _tr(
                      en: '${disaster.affectedFamilies} families',
                      id: '${disaster.affectedFamilies} keluarga',
                      ms: '${disaster.affectedFamilies} keluarga',
                      zh: '${disaster.affectedFamilies} 户家庭',
                    ),
                    isDark ? const Color(0xFFFDE68A) : Colors.amber.shade800,
                    isDark ? const Color(0xFF3A2F19) : Colors.amber.shade50,
                  ),
                if (disaster.affectedPeople > 0)
                  _reportChip(
                    Icons.people_alt_outlined,
                    _tr(
                      en: '${disaster.affectedPeople} people',
                      id: '${disaster.affectedPeople} orang',
                      ms: '${disaster.affectedPeople} orang',
                      zh: '${disaster.affectedPeople} 人',
                    ),
                    isDark ? const Color(0xFFFCA5A5) : Colors.red.shade700,
                    isDark ? const Color(0xFF3E1D1D) : Colors.red.shade50,
                  ),
                if (disaster.specialCase)
                  _reportChip(
                    Icons.priority_high_rounded,
                    _tr(
                      en: 'Special case',
                      id: 'Kasus khusus',
                      ms: 'Kes khas',
                      zh: '特殊事件',
                    ),
                    isDark ? const Color(0xFFE9D5FF) : Colors.purple.shade700,
                    isDark ? const Color(0xFF2E1F3A) : Colors.purple.shade50,
                  ),
              ],
            ),
            if ((disaster.startedAt ?? '').isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                _tr(
                  en: 'Started: ${disaster.startedAt}',
                  id: 'Mulai: ${disaster.startedAt}',
                  ms: 'Bermula: ${disaster.startedAt}',
                  zh: '开始时间：${disaster.startedAt}',
                ),
                style: TextStyle(
                  color: isDark
                      ? scheme.onSurface.withAlpha(180)
                      : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _aiCredLabel(double score) {
    if (score >= 0.75) return 'AI: High';
    if (score >= 0.50) return 'AI: Medium';
    return 'AI: Low';
  }

  Color _aiCredFg(double score, bool isDark) {
    if (score >= 0.75) return isDark ? const Color(0xFF86EFAC) : Colors.green.shade700;
    if (score >= 0.50) return isDark ? const Color(0xFFFCD34D) : Colors.amber.shade700;
    return isDark ? const Color(0xFFFCA5A5) : Colors.red.shade700;
  }

  Color _aiCredBg(double score, bool isDark) {
    if (score >= 0.75) return isDark ? const Color(0xFF14532D) : Colors.green.shade50;
    if (score >= 0.50) return isDark ? const Color(0xFF373018) : Colors.amber.shade50;
    return isDark ? const Color(0xFF3E1D1D) : Colors.red.shade50;
  }

  Widget _reportChip(IconData icon, String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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

  String _hazardLabel(String hazardType, AppLocalizations l10n) {
    return switch (hazardType) {
      'flood' => l10n.mapHazardFlood,
      'landslide' => l10n.mapHazardLandslide,
      _ => l10n.mapHazardGeneric,
    };
  }

  String _vouchLabel(int count) {
    return _tr(
      en: '$count vouch${count == 1 ? '' : 'es'}',
      id: '$count verifikasi',
      ms: '$count sokongan',
      zh: '$count 条确认',
    );
  }

  String _tr({
    required String en,
    String? id,
    required String ms,
    required String zh,
  }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'ms':
        return ms;
      case 'zh':
        return zh;
      case 'id':
        return id ?? ms;
      default:
        return en;
    }
  }
}
