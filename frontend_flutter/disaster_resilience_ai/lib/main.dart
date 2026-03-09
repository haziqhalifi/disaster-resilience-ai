import 'package:flutter/material.dart';
import 'package:disaster_resilience_ai/ui/auth_page.dart';

void main() {
  runApp(const DisasterResilienceApp());
}

class DisasterResilienceApp extends StatelessWidget {
  const DisasterResilienceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1B5E20),
      primary: const Color(0xFF1B5E20),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Disaster Resilience AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1B5E20),
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withAlpha(204),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
      ),
      home: const AuthPage(),
    );
  }
}
