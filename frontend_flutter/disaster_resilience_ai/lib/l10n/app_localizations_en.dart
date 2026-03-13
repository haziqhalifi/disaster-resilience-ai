// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get mapFilterFlood => 'Flood';

  @override
  String get mapFilterLandslide => 'Landslide';

  @override
  String get mapLegendTitle => 'HAZARD MAP';

  @override
  String get mapLegendFloodRiskZone => 'Flood Risk Zone';

  @override
  String get mapLegendLandslideRiskZone => 'Landslide Risk Zone';

  @override
  String get mapLoadingHazardZones => 'Loading hazard zones...';

  @override
  String get mapRiskScoreLabel => 'Risk Score: ';

  @override
  String get mapAreaRiskLabel => 'Area Risk: ';

  @override
  String mapRadiusKm(Object radius) {
    return 'Radius: $radius km';
  }

  @override
  String mapAdminAreaBasis(Object count) {
    return 'Based on $count mapped hazard point(s) inside this administrative area.';
  }

  @override
  String get mapHazardFlood => 'Flood';

  @override
  String get mapHazardLandslide => 'Landslide';

  @override
  String get mapHazardGeneric => 'Hazard';

  @override
  String get mapFilterAll => 'All';

  @override
  String get mapLegendCommunityReports => 'Community Reports';
}
