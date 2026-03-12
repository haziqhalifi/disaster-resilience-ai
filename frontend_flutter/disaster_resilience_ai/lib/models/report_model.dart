/// Model for community reports from the API.

class Report {
  Report({
    required this.id,
    required this.reportType,
    required this.locationName,
    required this.status,
    required this.createdAt,
    this.description,
    this.distanceKm,
    this.typeLabel,
    this.vouchCount = 0,
    this.vulnerablePerson = false,
  });

  final String id;
  final String reportType;
  final String locationName;
  final String status;
  final DateTime createdAt;
  final String? description;
  final double? distanceKm;
  final String? typeLabel;
  final int vouchCount;
  final bool vulnerablePerson;

  static String _typeLabel(String type) {
    switch (type) {
      case 'flood':
      case 'water_rising':
        return 'Water Rising';
      case 'blocked_road':
        return 'Road Blocked';
      case 'medical_emergency':
        return 'Medical Emergency';
      case 'landslide':
        return 'Landslide';
      default:
        return type.replaceAll('_', ' ').split(' ').map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}').join(' ');
    }
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    final type = json['report_type']?.toString() ?? 'unknown';
    final createdAtRaw = json['created_at']?.toString();
    return Report(
      id: json['id']?.toString() ?? '',
      reportType: type,
      locationName: json['location_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: createdAtRaw != null ? DateTime.tryParse(createdAtRaw) ?? DateTime.now() : DateTime.now(),
      description: json['description']?.toString(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      typeLabel: _typeLabel(type),
      vouchCount: (json['vouch_count'] as num?)?.toInt() ?? 0,
      vulnerablePerson: json['vulnerable_person'] == true,
    );
  }
}

class ReportList {
  ReportList({required this.reports, this.total = 0});

  final List<Report> reports;
  final int total;

  factory ReportList.fromJson(Map<String, dynamic> json) {
    final list = json['reports'] as List<dynamic>? ?? [];
    return ReportList(
      reports: list
          .whereType<Map<String, dynamic>>()
          .map((e) => Report.fromJson(e))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? list.length,
    );
  }
}
