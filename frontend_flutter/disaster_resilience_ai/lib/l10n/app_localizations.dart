import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';
import 'app_localizations_ms.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
    Locale('ms'),
    Locale('zh'),
  ];

  /// No description provided for @mapFilterFlood.
  ///
  /// In en, this message translates to:
  /// **'Flood'**
  String get mapFilterFlood;

  /// No description provided for @mapFilterLandslide.
  ///
  /// In en, this message translates to:
  /// **'Landslide'**
  String get mapFilterLandslide;

  /// No description provided for @mapLegendTitle.
  ///
  /// In en, this message translates to:
  /// **'HAZARD MAP'**
  String get mapLegendTitle;

  /// No description provided for @mapLegendFloodRiskZone.
  ///
  /// In en, this message translates to:
  /// **'Flood Risk Zone'**
  String get mapLegendFloodRiskZone;

  /// No description provided for @mapLegendLandslideRiskZone.
  ///
  /// In en, this message translates to:
  /// **'Landslide Risk Zone'**
  String get mapLegendLandslideRiskZone;

  /// No description provided for @mapLoadingHazardZones.
  ///
  /// In en, this message translates to:
  /// **'Loading hazard zones...'**
  String get mapLoadingHazardZones;

  /// No description provided for @mapRiskScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Risk Score: '**
  String get mapRiskScoreLabel;

  /// No description provided for @mapAreaRiskLabel.
  ///
  /// In en, this message translates to:
  /// **'Area Risk: '**
  String get mapAreaRiskLabel;

  /// No description provided for @mapRadiusKm.
  ///
  /// In en, this message translates to:
  /// **'Radius: {radius} km'**
  String mapRadiusKm(Object radius);

  /// No description provided for @mapAdminAreaBasis.
  ///
  /// In en, this message translates to:
  /// **'Based on {count} mapped hazard point(s) inside this administrative area.'**
  String mapAdminAreaBasis(Object count);

  /// No description provided for @mapHazardFlood.
  ///
  /// In en, this message translates to:
  /// **'Flood'**
  String get mapHazardFlood;

  /// No description provided for @mapHazardLandslide.
  ///
  /// In en, this message translates to:
  /// **'Landslide'**
  String get mapHazardLandslide;

  /// No description provided for @mapHazardGeneric.
  ///
  /// In en, this message translates to:
  /// **'Hazard'**
  String get mapHazardGeneric;

  /// No description provided for @mapFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get mapFilterAll;

  /// No description provided for @mapLegendCommunityReports.
  ///
  /// In en, this message translates to:
  /// **'Community Reports'**
  String get mapLegendCommunityReports;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id', 'ms', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
    case 'ms':
      return AppLocalizationsMs();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
