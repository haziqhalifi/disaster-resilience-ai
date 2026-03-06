/// Data models for the Hyper-Local Early Warning system.
library warning_model;

class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint({required this.latitude, required this.longitude});

  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    return GeoPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };
}

/// Hazard types matching the backend enum.
enum HazardType {
  flood,
  landslide,
  typhoon,
  earthquake,
  forecast,
  aid,
  infrastructure;

  String get displayName {
    switch (this) {
      case HazardType.flood:
        return 'Flood';
      case HazardType.landslide:
        return 'Landslide';
      case HazardType.typhoon:
        return 'Typhoon';
      case HazardType.earthquake:
        return 'Earthquake';
      case HazardType.forecast:
        return 'Forecast';
      case HazardType.aid:
        return 'Aid Distribution';
      case HazardType.infrastructure:
        return 'Infrastructure';
    }
  }
}

/// Alert levels matching the backend enum (increasing severity).
enum AlertLevel {
  advisory,
  observe,
  warning,
  evacuate;

  String get displayName {
    switch (this) {
      case AlertLevel.advisory:
        return 'ADVISORY';
      case AlertLevel.observe:
        return 'OBSERVE';
      case AlertLevel.warning:
        return 'WARNING';
      case AlertLevel.evacuate:
        return 'EVACUATE';
    }
  }

  /// Returns a severity index (0 = lowest, 3 = highest).
  int get severityIndex => index;
}

/// A warning record from the backend.
class Warning {
  final String id;
  final String title;
  final String description;
  final HazardType hazardType;
  final AlertLevel alertLevel;
  final GeoPoint location;
  final double radiusKm;
  final String source;
  final DateTime createdAt;
  final bool active;

  const Warning({
    required this.id,
    required this.title,
    required this.description,
    required this.hazardType,
    required this.alertLevel,
    required this.location,
    required this.radiusKm,
    required this.source,
    required this.createdAt,
    required this.active,
  });

  factory Warning.fromJson(Map<String, dynamic> json) {
    return Warning(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      hazardType: HazardType.values.firstWhere(
        (e) => e.name == json['hazard_type'],
        orElse: () => HazardType.flood,
      ),
      alertLevel: AlertLevel.values.firstWhere(
        (e) => e.name == json['alert_level'],
        orElse: () => AlertLevel.advisory,
      ),
      location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
      radiusKm: (json['radius_km'] as num).toDouble(),
      source: json['source'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      active: json['active'] as bool? ?? true,
    );
  }
}

/// A list of warnings returned by the API.
class WarningList {
  final int count;
  final List<Warning> warnings;

  const WarningList({required this.count, required this.warnings});

  factory WarningList.fromJson(Map<String, dynamic> json) {
    final list = (json['warnings'] as List<dynamic>)
        .map((e) => Warning.fromJson(e as Map<String, dynamic>))
        .toList();
    return WarningList(
      count: json['count'] as int,
      warnings: list,
    );
  }
}
