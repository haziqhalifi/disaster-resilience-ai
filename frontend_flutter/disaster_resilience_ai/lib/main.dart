import 'package:flutter/material.dart';
import 'package:disaster_resilience_ai/services/notification_service.dart';
import 'package:disaster_resilience_ai/ui/auth_page.dart';

/// Global navigator key so services can push routes from anywhere.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  NotificationService.instance.navigatorKey = navigatorKey;
  runApp(const DisasterResilienceApp());
}

class DisasterResilienceApp extends StatelessWidget {
  const DisasterResilienceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Disaster Resilience AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: const AuthPage(),
    );
  }
}
