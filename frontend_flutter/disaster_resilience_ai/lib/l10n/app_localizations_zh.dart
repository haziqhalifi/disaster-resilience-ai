// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get mapFilterFlood => '洪水';

  @override
  String get mapFilterLandslide => '山体滑坡';

  @override
  String get mapLegendTitle => '灾害地图';

  @override
  String get mapLegendFloodRiskZone => '洪水风险区';

  @override
  String get mapLegendLandslideRiskZone => '山体滑坡风险区';

  @override
  String get mapLoadingHazardZones => '正在加载灾害区域...';

  @override
  String get mapRiskScoreLabel => '风险评分: ';

  @override
  String get mapAreaRiskLabel => '区域风险: ';

  @override
  String mapRadiusKm(Object radius) {
    return '半径: $radius 公里';
  }

  @override
  String mapAdminAreaBasis(Object count) {
    return '基于该行政区域内已映射的 $count 个灾害点。';
  }

  @override
  String get mapHazardFlood => '洪水';

  @override
  String get mapHazardLandslide => '山体滑坡';

  @override
  String get mapHazardGeneric => '灾害';

  @override
  String get mapFilterAll => '全部';

  @override
  String get mapLegendCommunityReports => '社区报告';
}
