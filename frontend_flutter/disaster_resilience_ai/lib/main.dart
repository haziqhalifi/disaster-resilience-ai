import 'package:disaster_resilience_ai/localization/app_language.dart';
import 'package:disaster_resilience_ai/services/notification_service.dart';
import 'package:disaster_resilience_ai/theme/app_theme.dart';
import 'package:disaster_resilience_ai/ui/auth_page.dart';
import 'package:flutter/material.dart';

/// Global navigator key so services can push routes from anywhere.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  NotificationService.instance.navigatorKey = navigatorKey;

  final isDarkMode = await AppThemeController.loadInitialDarkMode();
  final initialLanguage = await AppLanguageController.loadInitialLanguage();

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
          animation: Listenable.merge([_themeController, _languageController]),
          builder: (context, _) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'LANDA',
              debugShowCheckedModeBanner: false,
              theme: AppThemes.lightTheme(),
              darkTheme: AppThemes.darkTheme(),
              themeMode: _themeController.themeMode,
              home: const AuthPage(),
            );
          },
        ),
      ),
    );
  }
}
