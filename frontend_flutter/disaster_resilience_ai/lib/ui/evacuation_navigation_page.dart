import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:disaster_resilience_ai/models/risk_map_model.dart';

class EvacuationNavigationPage extends StatefulWidget {
  final List<LatLng> routePoints;
  final LatLng userLocation;
  final EvacuationCentre destination;

  const EvacuationNavigationPage({
    super.key,
    required this.routePoints,
    required this.userLocation,
    required this.destination,
  });

  @override
  State<EvacuationNavigationPage> createState() =>
      _EvacuationNavigationPageState();
}

class _EvacuationNavigationPageState extends State<EvacuationNavigationPage> {
  final MapController _mapController = MapController();

  /// Haversine distance in km between user and destination
  double get _distanceKm {
    const p = 0.017453292519943295;
    final lat1 = widget.userLocation.latitude;
    final lon1 = widget.userLocation.longitude;
    final lat2 = widget.destination.latitude;
    final lon2 = widget.destination.longitude;
    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  /// Conservative estimate: 40 km/h in urban/rural
  String get _estimatedTime {
    final minutes = (_distanceKm / 40 * 60).round();
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h hr${m > 0 ? " $m min" : ""}';
  }

  /// Midpoint between user and destination (for no-route case)
  LatLng get _midPoint => LatLng(
    (widget.userLocation.latitude + widget.destination.latitude) / 2,
    (widget.userLocation.longitude + widget.destination.longitude) / 2,
  );

  @override
  Widget build(BuildContext context) {
    final hasRoute = widget.routePoints.isNotEmpty;
    final destLatLng = LatLng(
      widget.destination.latitude,
      widget.destination.longitude,
    );

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-Screen Map ──────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: hasRoute ? widget.userLocation : _midPoint,
              initialZoom: hasRoute ? 16.0 : 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.disasterai.disaster_resilience_ai',
              ),

              // Blue polyline when road route is available
              if (hasRoute)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.routePoints,
                      color: Colors.blue[700]!,
                      strokeWidth: 6,
                    ),
                  ],
                ),

              // Orange straight-line when no road route
              if (!hasRoute)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [widget.userLocation, destLatLng],
                      color: Colors.orange,
                      strokeWidth: 3,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  // User location
                  Marker(
                    point: widget.userLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.navigation,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),
                  // Destination (PPS)
                  Marker(
                    point: destLatLng,
                    width: 50,
                    height: 60,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_hospital,
                          color: Colors.green,
                          size: 32,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 2),
                            ],
                          ),
                          child: Text(
                            widget.destination.name,
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Top Navigation Banner ────────────────────────────────────────
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.arrow_upward,
                        color: Colors.white,
                        size: 36,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Head to evacuation centre',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.destination.name,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            if (widget.destination.address.isNotEmpty)
                              Text(
                                widget.destination.address,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!hasRoute) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(80),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Colors.orangeAccent,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'No road route available — straight-line direction shown. Follow road signs towards the PPS.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Bottom Stats Bar ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estimated Time',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Text(
                            _estimatedTime,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Distance',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Text(
                            '${_distanceKm.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'EXIT NAVIGATION',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Re-center FAB ────────────────────────────────────────────────
          Positioned(
            bottom: 180,
            right: 20,
            child: FloatingActionButton(
              onPressed: () => _mapController.move(widget.userLocation, 16),
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}
