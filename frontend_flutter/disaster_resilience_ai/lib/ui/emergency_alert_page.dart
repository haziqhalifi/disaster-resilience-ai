import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

import 'package:disaster_resilience_ai/models/warning_model.dart';
import 'package:disaster_resilience_ai/models/risk_map_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/ui/evacuation_navigation_page.dart';

class EmergencyAlertPage extends StatefulWidget {
  const EmergencyAlertPage({super.key, this.warning});

  final Warning? warning;

  @override
  State<EmergencyAlertPage> createState() => _EmergencyAlertPageState();
}

class _EmergencyAlertPageState extends State<EmergencyAlertPage> {
  final ApiService _api = ApiService();
  final MapController _mapController = MapController();

  MapData? _mapData;
  LatLng? _userLocation;
  bool _loading = true;
  EvacuationCentre? _nearestCentre;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _loading = true);
    try {
      // 1. Get location
      final pos = await Geolocator.getCurrentPosition();
      final userLatLng = LatLng(pos.latitude, pos.longitude);

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

      // 4. Fetch real road route to nearest centre
      List<LatLng> route = [];
      if (nearest != null) {
        final routeData = await _api.fetchRoute(
          startLat: userLatLng.latitude,
          startLon: userLatLng.longitude,
          endLat: nearest.latitude,
          endLon: nearest.longitude,
        );
        route = routeData.map((p) => LatLng(p['lat']!, p['lng']!)).toList();
      }

      if (mounted) {
        setState(() {
          _userLocation = userLatLng;
          _mapData = mapData;
          _nearestCentre = nearest;
          _routePoints = route;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  String _getDirection(LatLng from, LatLng to) {
    final latDiff = to.latitude - from.latitude;
    final lonDiff = to.longitude - from.longitude;

    if (latDiff.abs() > lonDiff.abs()) {
      return latDiff > 0 ? 'North' : 'South';
    } else {
      return lonDiff > 0 ? 'East' : 'West';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.warning == null) {
      return _buildNoWarningState(context);
    }
    return _buildWarningState(context, widget.warning!);
  }

  Widget _buildNoWarningState(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Warning Details',
          style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 16),
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
                decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 72),
              ),
              const SizedBox(height: 32),
              const Text(
                'All Clear',
                style: TextStyle(color: Color(0xFF2E7D32), fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'No active warnings near your location.\nStay safe and prepared.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('BACK TO DASHBOARD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningState(BuildContext context, Warning w) {
    final bgColor = _alertColor(w.alertLevel);
    final timeAgo = _timeAgo(w.createdAt);

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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
                decoration: BoxDecoration(color: Colors.white.withAlpha(51), shape: BoxShape.circle),
                child: Icon(_alertIcon(w), color: Colors.white, size: 60),
              ),
              const SizedBox(height: 16),
              Text(
                '${w.alertLevel.displayName} • ${w.hazardType.displayName.toUpperCase()}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                w.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.2),
              ),
              const SizedBox(height: 12),
              Text(
                w.description,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withAlpha(230), fontSize: 14, fontWeight: FontWeight.w500, height: 1.5),
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
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: _loading 
                  ? const Center(child: CircularProgressIndicator())
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _userLocation ?? LatLng(w.location.latitude, w.location.longitude),
                        initialZoom: 13.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.disaster.resilience.ai',
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
                              point: LatLng(w.location.latitude, w.location.longitude),
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
                                point: LatLng(_nearestCentre!.latitude, _nearestCentre!.longitude),
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.local_hospital, color: Color(0xFF2E7D32), size: 30),
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
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 24),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.record_voice_over, color: Color(0xFF2E7D32), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'RURAL EVACUATION GUIDE',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      'BAHASA MALAYSIA:',
                      style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sila bergerak ke arah ${_getDirection(_userLocation!, LatLng(_nearestCentre!.latitude, _nearestCentre!.longitude))} menuju ke ${_nearestCentre!.name}. '
                      'Jarak adalah lebih kurang ${_calculateDistance(_userLocation!.latitude, _userLocation!.longitude, _nearestCentre!.latitude, _nearestCentre!.longitude).toStringAsFixed(1)} KM dari sini.',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ENGLISH:',
                      style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please head ${_getDirection(_userLocation!, LatLng(_nearestCentre!.latitude, _nearestCentre!.longitude))} towards ${_nearestCentre!.name}. '
                      'It is about ${_calculateDistance(_userLocation!.latitude, _userLocation!.longitude, _nearestCentre!.latitude, _nearestCentre!.longitude).toStringAsFixed(1)} KM away.',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          Icon(Icons.tips_and_updates, color: Colors.amber[800], size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Safe Tip: Avoid low-lying river paths even if they seem shorter.',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_userLocation != null && _nearestCentre != null && _routePoints.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EvacuationNavigationPage(
                            routePoints: _routePoints,
                            userLocation: _userLocation!,
                            destination: _nearestCentre!,
                          ),
                        ),
                      );
                    } else if (_userLocation != null) {
                      _mapController.move(_userLocation!, 15);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: bgColor,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: Icon(w.alertLevel == AlertLevel.evacuate ? Icons.directions_run : Icons.navigation, size: 28),
                  label: Text(
                    w.alertLevel == AlertLevel.evacuate ? 'EVACUATE NOW' : 'VIEW SAFE ROUTES',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                w.alertLevel == AlertLevel.evacuate ? 'TAP FOR TURN-BY-TURN NAVIGATION' : 'TAP TO VIEW RECOMMENDED SAFE ROUTES',
                style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withAlpha(38), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Color _alertColor(AlertLevel level) {
    switch (level) {
      case AlertLevel.advisory: return Colors.blue[700]!;
      case AlertLevel.observe: return Colors.amber[700]!;
      case AlertLevel.warning: return Colors.deepOrange[700]!;
      case AlertLevel.evacuate: return const Color(0xFFD32F2F);
    }
  }

  IconData _alertIcon(Warning w) {
    // Priority icons for non-standard hazard types
    if (w.hazardType == HazardType.aid) return Icons.volunteer_activism;
    if (w.hazardType == HazardType.forecast) return Icons.wb_cloudy_outlined;
    if (w.hazardType == HazardType.infrastructure) return Icons.construction;

    switch (w.alertLevel) {
      case AlertLevel.advisory: return Icons.info_outline;
      case AlertLevel.observe: return Icons.visibility_outlined;
      case AlertLevel.warning: return Icons.warning_amber_rounded;
      case AlertLevel.evacuate: return Icons.directions_run;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showWarningDetails(BuildContext context, Warning w) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Warning Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            _buildDetailRow('ID', w.id.substring(0, 8)),
            _buildDetailRow('Hazard', w.hazardType.displayName),
            _buildDetailRow('Level', w.alertLevel.displayName),
            _buildDetailRow('Source', w.source),
            _buildDetailRow('Radius', '${w.radiusKm} km'),
            _buildDetailRow('Coordinates', '${w.location.latitude.toStringAsFixed(4)}, ${w.location.longitude.toStringAsFixed(4)}'),
            _buildDetailRow('Created', w.createdAt.toLocal().toString().substring(0, 19)),
            _buildDetailRow('Status', w.active ? 'Active' : 'Resolved'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13))),
        ],
      ),
    );
  }
}
