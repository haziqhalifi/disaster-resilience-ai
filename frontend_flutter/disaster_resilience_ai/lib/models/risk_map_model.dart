/// Data models for the AI Risk Mapping system.
library;

/// A risk zone (danger, warning, or safe area).
class RiskZone {
  final String id;
  final String name;
  final String zoneType; // "danger", "warning", "safe"
  final String hazardType;
  final double latitude;
  final double longitude;
  final double radiusKm;
  final double riskScore;
  final String description;
  final bool active;

  const RiskZone({
    required this.id,
    required this.name,
    required this.zoneType,
    required this.hazardType,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.riskScore,
    required this.description,
    required this.active,
  });

  factory RiskZone.fromJson(Map<String, dynamic> json) {
    return RiskZone(
      id: json['id'] as String,
      name: json['name'] as String,
      zoneType: json['zone_type'] as String,
      hazardType: json['hazard_type'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusKm: (json['radius_km'] as num).toDouble(),
      riskScore: (json['risk_score'] as num).toDouble(),
      description: json['description'] as String,
      active: json['active'] as bool? ?? true,
    );
  }
}

/// An evacuation centre.
class EvacuationCentre {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int capacity;
  final int currentOccupancy;
  final String? contactPhone;
  final String address;
  final bool active;

  const EvacuationCentre({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.capacity,
    required this.currentOccupancy,
    this.contactPhone,
    required this.address,
    required this.active,
  });

  double get occupancyPercent =>
      capacity > 0 ? (currentOccupancy / capacity * 100).clamp(0, 100) : 0;

  factory EvacuationCentre.fromJson(Map<String, dynamic> json) {
    return EvacuationCentre(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      capacity: json['capacity'] as int,
      currentOccupancy: json['current_occupancy'] as int? ?? 0,
      contactPhone: json['contact_phone'] as String?,
      address: json['address'] as String? ?? '',
      active: json['active'] as bool? ?? true,
    );
  }
}

/// A waypoint along a route.
class RouteWaypoint {
  final double lat;
  final double lon;

  const RouteWaypoint({required this.lat, required this.lon});

  factory RouteWaypoint.fromJson(Map<String, dynamic> json) {
    return RouteWaypoint(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
    );
  }
}

/// An evacuation route.
class EvacuationRoute {
  final String id;
  final String name;
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final List<RouteWaypoint> waypoints;
  final double distanceKm;
  final int estimatedMinutes;
  final double elevationGainM;
  final String status; // "clear", "partial", "blocked"
  final bool active;

  const EvacuationRoute({
    required this.id,
    required this.name,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.waypoints,
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.elevationGainM,
    required this.status,
    required this.active,
  });

  factory EvacuationRoute.fromJson(Map<String, dynamic> json) {
    return EvacuationRoute(
      id: json['id'] as String,
      name: json['name'] as String,
      startLat: (json['start_lat'] as num).toDouble(),
      startLon: (json['start_lon'] as num).toDouble(),
      endLat: (json['end_lat'] as num).toDouble(),
      endLon: (json['end_lon'] as num).toDouble(),
      waypoints: (json['waypoints'] as List<dynamic>)
          .map((w) => RouteWaypoint.fromJson(w as Map<String, dynamic>))
          .toList(),
      distanceKm: (json['distance_km'] as num).toDouble(),
      estimatedMinutes: json['estimated_minutes'] as int,
      elevationGainM: (json['elevation_gain_m'] as num).toDouble(),
      status: json['status'] as String? ?? 'clear',
      active: json['active'] as bool? ?? true,
    );
  }
}

/// A hazard-scored administrative area polygon.
class AdminArea {
  final String id;
  final String name;
  final String hazardType;
  final double riskScore;
  final int zoneCount;
  final List<RouteWaypoint> boundary;

  const AdminArea({
    required this.id,
    required this.name,
    required this.hazardType,
    required this.riskScore,
    required this.zoneCount,
    required this.boundary,
  });

  factory AdminArea.fromJson(Map<String, dynamic> json) {
    return AdminArea(
      id: json['id'] as String,
      name: json['name'] as String,
      hazardType: json['hazard_type'] as String,
      riskScore: (json['risk_score'] as num).toDouble(),
      zoneCount: json['zone_count'] as int? ?? 0,
      boundary: (json['boundary'] as List<dynamic>)
          .map((p) => RouteWaypoint.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Combined map data response.
class MapData {
  final List<RiskZone> riskZones;
  final List<EvacuationCentre> evacuationCentres;
  final List<EvacuationRoute> evacuationRoutes;
  final List<AdminArea> adminAreas;

  const MapData({
    required this.riskZones,
    required this.evacuationCentres,
    required this.evacuationRoutes,
    required this.adminAreas,
  });

  factory MapData.fromJson(Map<String, dynamic> json) {
    return MapData(
      riskZones: (json['risk_zones'] as List<dynamic>)
          .map((e) => RiskZone.fromJson(e as Map<String, dynamic>))
          .toList(),
      evacuationCentres: (json['evacuation_centres'] as List<dynamic>)
          .map((e) => EvacuationCentre.fromJson(e as Map<String, dynamic>))
          .toList(),
      evacuationRoutes: (json['evacuation_routes'] as List<dynamic>)
          .map((e) => EvacuationRoute.fromJson(e as Map<String, dynamic>))
          .toList(),
      adminAreas: ((json['admin_areas'] as List<dynamic>?) ?? const [])
          .map((e) => AdminArea.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
