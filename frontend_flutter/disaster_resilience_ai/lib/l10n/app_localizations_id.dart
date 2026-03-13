// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get mapFilterFlood => 'Banjir';

  @override
  String get mapFilterLandslide => 'Tanah Longsor';

  @override
  String get mapLegendTitle => 'PETA BAHAYA';

  @override
  String get mapLegendFloodRiskZone => 'Zona Risiko Banjir';

  @override
  String get mapLegendLandslideRiskZone => 'Zona Risiko Tanah Longsor';

  @override
  String get mapLoadingHazardZones => 'Memuat zona bahaya...';

  @override
  String get mapRiskScoreLabel => 'Skor Risiko: ';

  @override
  String get mapAreaRiskLabel => 'Risiko Area: ';

  @override
  String mapRadiusKm(Object radius) {
    return 'Radius: $radius km';
  }

  @override
  String mapAdminAreaBasis(Object count) {
    return 'Berdasarkan $count titik bahaya yang dipetakan di dalam area administrasi ini.';
  }

  @override
  String get mapHazardFlood => 'Banjir';

  @override
  String get mapHazardLandslide => 'Tanah Longsor';

  @override
  String get mapHazardGeneric => 'Bahaya';

  @override
  String get mapFilterAll => 'Semua';

  @override
  String get mapLegendCommunityReports => 'Laporan Komunitas';
}
