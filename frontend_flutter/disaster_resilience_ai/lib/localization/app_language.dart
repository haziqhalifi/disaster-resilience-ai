import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, malay, chinese }

class AppLanguageController extends ChangeNotifier {
  AppLanguageController({required AppLanguage language}) : _language = language;

  static const _prefKey = 'app_language';
  AppLanguage _language;

  AppLanguage get language => _language;

  static Future<AppLanguage> loadInitialLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == 'zh') return AppLanguage.chinese;
    return saved == 'ms' ? AppLanguage.malay : AppLanguage.english;
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, switch (language) {
      AppLanguage.english => 'en',
      AppLanguage.malay => 'ms',
      AppLanguage.chinese => 'zh',
    });
  }

  String get label => switch (_language) {
    AppLanguage.english => 'English',
    AppLanguage.malay => 'Bahasa Melayu',
    AppLanguage.chinese => 'Chinese (Mandarin)',
  };
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope != null, 'AppLanguageScope not found in context');
    return scope!.notifier!;
  }

  static String tr(
    BuildContext context, {
    required String en,
    required String ms,
    String? zh,
  }) {
    return switch (of(context).language) {
      AppLanguage.english => en,
      AppLanguage.malay => ms,
      AppLanguage.chinese => zh ?? en,
    };
  }
}
