import 'package:flutter/material.dart';
import 'package:disaster_resilience_ai/ui/auth_page.dart';

void main() {
  runApp(const DisasterResilienceApp());
}

class DisasterResilienceApp extends StatelessWidget {
  const DisasterResilienceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Disaster Resilience AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: const AuthPage(),
    );
  }
}
