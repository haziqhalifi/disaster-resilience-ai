import 'package:disaster_resilience_ai/localization/app_language.dart';
import 'package:disaster_resilience_ai/l10n/app_localizations.dart';
import 'package:disaster_resilience_ai/models/warning_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/services/notification_service.dart';
import 'package:disaster_resilience_ai/theme/app_theme.dart';
import 'package:disaster_resilience_ai/ui/auth_page.dart';
import 'package:disaster_resilience_ai/ui/emergency_alert_page.dart';
import 'package:disaster_resilience_ai/ui/incoming_alert_page.dart';
import 'package:disaster_resilience_ai/utils/accessibility_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Global navigator key so services can push routes from anywhere.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initFromPrefs();
  await NotificationService.instance.init();
  NotificationService.instance.navigatorKey = navigatorKey;
  NotificationService.instance.onEmergencyAlert = (Warning warning) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(builder: (_) => IncomingAlertPage(warning: warning)),
    );
  };
  NotificationService.instance.onWarningTap = (Warning warning) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(builder: (_) => EmergencyAlertPage(warning: warning)),
    );
  };

  final isDarkMode = await AppThemeController.loadInitialDarkMode();
  final initialLanguage = await AppLanguageController.loadInitialLanguage();
  await AccessibilitySettings.load();

  runApp(
    DisasterResilienceApp(
      initialDarkMode: isDarkMode,
      initialLanguage: initialLanguage,
    ),
  );
}

class DisasterResilienceApp extends StatefulWidget {
  const DisasterResilienceApp({
    super.key,
    required this.initialDarkMode,
    required this.initialLanguage,
  });

  final bool initialDarkMode;
  final AppLanguage initialLanguage;

  @override
  State<DisasterResilienceApp> createState() => _DisasterResilienceAppState();
}

class _DisasterResilienceAppState extends State<DisasterResilienceApp> {
  late final AppThemeController _themeController = AppThemeController(
    isDarkMode: widget.initialDarkMode,
  );
  late final AppLanguageController _languageController = AppLanguageController(
    language: widget.initialLanguage,
  );

  @override
  void dispose() {
    _themeController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      controller: _themeController,
      child: AppLanguageScope(
        controller: _languageController,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _themeController,
            _languageController,
            AccessibilitySettings.largeTextEnabledNotifier,
          ]),
          builder: (context, _) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'LANDA',
              debugShowCheckedModeBanner: false,
              theme: AppThemes.lightTheme(),
              darkTheme: AppThemes.darkTheme(),
              themeMode: _themeController.themeMode,
              locale: _languageController.locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                final scale =
                    AccessibilitySettings.largeTextEnabledNotifier.value
                    ? 1.15
                    : 1.0;
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: const AuthPage(),
            );
          },
        ),
      ),
    );
  }
}
