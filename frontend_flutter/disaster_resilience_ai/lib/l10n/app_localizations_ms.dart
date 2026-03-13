// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malay (`ms`).
class AppLocalizationsMs extends AppLocalizations {
  AppLocalizationsMs([String locale = 'ms']) : super(locale);

  @override
  String get mapFilterFlood => 'Banjir';

  @override
  String get mapFilterLandslide => 'Tanah Runtuh';

  @override
  String get mapLegendTitle => 'PETA BAHAYA';

  @override
  String get mapLegendFloodRiskZone => 'Zon Risiko Banjir';

  @override
  String get mapLegendLandslideRiskZone => 'Zon Risiko Tanah Runtuh';

  @override
  String get mapLoadingHazardZones => 'Memuatkan zon bahaya...';

  @override
  String get mapRiskScoreLabel => 'Skor Risiko: ';

  @override
  String get mapAreaRiskLabel => 'Risiko Kawasan: ';

  @override
  String mapRadiusKm(Object radius) {
    return 'Radius: $radius km';
  }

  @override
  String mapAdminAreaBasis(Object count) {
    return 'Berdasarkan $count titik bahaya dipetakan dalam kawasan pentadbiran ini.';
  }

  @override
  String get mapHazardFlood => 'Banjir';

  @override
  String get mapHazardLandslide => 'Tanah Runtuh';

  @override
  String get mapHazardGeneric => 'Bahaya';

  @override
  String get mapFilterAll => 'Semua';

  @override
  String get mapLegendCommunityReports => 'Laporan Komuniti';
}
