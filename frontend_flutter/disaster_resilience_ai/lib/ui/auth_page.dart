import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/ui/home_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static const _tokenKey = 'auth_access_token';
  static const _emailKey = 'auth_email';
  static const _usernameKey = 'auth_username';

  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignIn = true;
  bool _acceptedTerms = false;
  bool _loading = false;
  bool _restoring = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final result = _isSignIn
          ? await _api.signIn(email: email, password: password)
          : await _api.signUp(
              username: _usernameController.text.trim(),
              email: email,
              password: password,
            );

      await _saveSession(
        accessToken: result.accessToken,
        email: result.email,
        username: result.username,
      );
      await ApiService.initTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomePage(
            accessToken: result.accessToken,
            email: result.email,
            username: result.username,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isSignIn = !_isSignIn;
      _error = null;
      _acceptedTerms = false;
    });
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var token = prefs.getString(_tokenKey);
      final email = prefs.getString(_emailKey);
      final username = prefs.getString(_usernameKey);

      if (token == null || email == null || username == null) {
        if (mounted) setState(() => _restoring = false);
        return;
      }

      // Seed static token so tryRefreshSession can use the stored refresh token.
      await ApiService.initTokens(accessToken: token);

      // Try the stored token; if expired (401), attempt a silent refresh.
      try {
        await _api.me(token);
      } catch (_) {
        final refreshed = await ApiService.tryRefreshSession();
        if (refreshed == null) {
          // Refresh also failed — clear session and show login.
          await prefs.remove(_tokenKey);
          await prefs.remove(_emailKey);
          await prefs.remove(_usernameKey);
          if (mounted) setState(() => _restoring = false);
          return;
        }
        // Refresh succeeded — persist the new access token.
        token = refreshed.accessToken;
        await prefs.setString(_tokenKey, token);
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              HomePage(accessToken: token!, email: email, username: username),
        ),
      );
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_emailKey);
      await prefs.remove(_usernameKey);
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _saveSession({
    required String accessToken,
    required String email,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_emailKey, email);
    await prefs.setString(_usernameKey, username);
  }

  void _openTermsOfService() {
    _showLegalPopup(
      title: 'Terms of Service',
      sections: const [
        _LegalSection(
          heading: '1. Use of Service',
          body:
              'LANDA provides disaster preparedness information and tools for community support. You agree to use the app lawfully and responsibly.',
        ),
        _LegalSection(
          heading: '2. User Content',
          body:
              'Reports you submit may be reviewed by administrators and relevant teams. Do not submit false, harmful, or unlawful content.',
        ),
        _LegalSection(
          heading: '3. Availability',
          body:
              'We strive to keep the app available and accurate, but we do not guarantee uninterrupted service or complete accuracy at all times.',
        ),
      ],
    );
  }

  void _openPrivacyPolicy() {
    _showLegalPopup(
      title: 'Privacy Policy',
      sections: const [
        _LegalSection(
          heading: '1. Data Collected',
          body:
              'We may collect account details, submitted reports, and location data (when permitted) to provide warnings and app features.',
        ),
        _LegalSection(
          heading: '2. Data Usage',
          body:
              'Your information is used to operate the app, improve safety insights, and support emergency-related functions.',
        ),
        _LegalSection(
          heading: '3. Data Protection',
          body:
              'We apply reasonable safeguards to protect your information. You can contact support for account and data-related requests.',
        ),
      ],
    );
  }

  void _showLegalPopup({
    required String title,
    required List<_LegalSection> sections,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF202427) : const Color(0xFFF7F8FA);
    final heading = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B);
    final text = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    final borderColor = isDark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogBg,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor),
          ),
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < sections.length; i++) ...[
                    Text(
                      sections[i].heading,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: heading,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sections[i].body,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: text,
                      ),
                    ),
                    if (i != sections.length - 1) const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    final muted = isDark ? const Color(0xFFA7B5A8) : Colors.grey;
    final heading = isDark ? const Color(0xFFE8F5E9) : const Color(0xFF1E293B);

    if (_restoring) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: const CircularProgressIndicator(color: Color(0xFF2E7D32)),
        ),
      );
    }

    final title = _isSignIn ? 'Welcome' : 'Create Account';

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF233124)
                          : const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isSignIn
                          ? Icons.lock_outline
                          : Icons.person_add_outlined,
                      size: 64,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: heading,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignIn
                        ? 'Sign in to your account'
                        : 'Join us to stay disaster-resilient',
                    style: TextStyle(fontSize: 14, color: muted),
                  ),
                  const SizedBox(height: 32),
                  if (!_isSignIn)
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: TextStyle(color: muted),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E2720)
                            : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                        prefixIcon: Icon(Icons.person_outline, color: muted),
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                  if (!_isSignIn) const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: muted),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E2720)
                          : Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                      ),
                      prefixIcon: Icon(Icons.email_outlined, color: muted),
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (!text.contains('@')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: muted),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E2720)
                          : Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                      ),
                      prefixIcon: Icon(Icons.lock_outline, color: muted),
                    ),
                    validator: (value) {
                      final text = value ?? '';
                      if (text.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  if (!_isSignIn) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptedTerms,
                          activeColor: const Color(0xFF2E7D32),
                          onChanged: _loading
                              ? null
                              : (value) => setState(
                                  () => _acceptedTerms = value ?? false,
                                ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'I agree to the ',
                                  style: TextStyle(fontSize: 14, color: muted),
                                ),
                                GestureDetector(
                                  onTap: _openTermsOfService,
                                  child: const Text(
                                    'Terms of Service',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                Text(
                                  ' and ',
                                  style: TextStyle(fontSize: 14, color: muted),
                                ),
                                GestureDetector(
                                  onTap: _openPrivacyPolicy,
                                  child: const Text(
                                    'Privacy Policy',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                Text(
                                  '.',
                                  style: TextStyle(fontSize: 14, color: muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF3A2020)
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red[700], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () {
                              if (!_isSignIn && !_acceptedTerms) {
                                setState(
                                  () => _error =
                                      'Please accept the Terms of Service and Privacy Policy.',
                                );
                                return;
                              }
                              _submit();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              _isSignIn ? 'SIGN IN' : 'CREATE ACCOUNT',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _loading ? null : _toggleMode,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4CAF50),
                    ),
                    child: Text(
                      _isSignIn
                          ? 'Don\'t have an account? Sign up'
                          : 'Already have an account? Sign in',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}
