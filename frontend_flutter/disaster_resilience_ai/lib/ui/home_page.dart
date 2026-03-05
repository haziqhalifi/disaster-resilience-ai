import 'package:flutter/material.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/ui/auth_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.accessToken,
    required this.email,
    required this.username,
  });

  final String accessToken;
  final String email;
  final String username;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _api = ApiService();
  String _status = 'Tap the button to check backend status';
  bool _loading = false;
  String _authStatus = 'Token not checked yet';

  Future<void> _verifySession() async {
    setState(() => _loading = true);
    try {
      final me = await _api.me(widget.accessToken);
      setState(() => _authStatus = 'Authenticated as ${me['email']}');
    } catch (e) {
      setState(() => _authStatus = 'Auth check failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_access_token');
    await prefs.remove('auth_email');
    await prefs.remove('auth_username');
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthPage()));
  }

  Future<void> _pingBackend() async {
    setState(() => _loading = true);
    try {
      final result = await _api.ping();
      setState(() => _status = 'Backend says: ${result['message']}');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Disaster Resilience AI')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 80,
                color: Colors.deepOrange,
              ),
              const SizedBox(height: 24),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 10),
              Text(
                'Signed in as ${widget.username} (${widget.email})',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _authStatus,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              _loading
                  ? const CircularProgressIndicator()
                  : Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pingBackend,
                          icon: const Icon(Icons.wifi_tethering),
                          label: const Text('Ping Backend'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _verifySession,
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('Check Token'),
                        ),
                        TextButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
