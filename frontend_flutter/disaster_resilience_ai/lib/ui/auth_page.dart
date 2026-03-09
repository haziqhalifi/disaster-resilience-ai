import 'dart:ui' as ui;

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
    });
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final email = prefs.getString(_emailKey);
      final username = prefs.getString(_usernameKey);

      if (token == null || email == null || username == null) {
        if (mounted) {
          setState(() => _restoring = false);
        }
        return;
      }

      await _api.me(token);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              HomePage(accessToken: token, email: email, username: username),
        ),
      );
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_emailKey);
      await prefs.remove(_usernameKey);
      if (mounted) {
        setState(() => _restoring = false);
      }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_restoring) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    final title = _isSignIn ? 'Welcome Back' : 'Create Account';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white.withAlpha(175),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Resilience AI',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -160,
            right: -90,
            child: _softOrb(colorScheme.primary.withAlpha(18), 280),
          ),
          Positioned(
            bottom: -120,
            left: -70,
            child: _softOrb(colorScheme.tertiary.withAlpha(14), 220),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: _glassPanel(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withAlpha(180),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isSignIn
                                ? Icons.lock_outline
                                : Icons.person_add_outlined,
                            size: 54,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isSignIn
                              ? 'Sign in to monitor your community'
                              : 'Join us to stay resilient',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        if (!_isSignIn)
                          TextFormField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            decoration: _buildInputDecoration(
                              context: context,
                              label: 'Username',
                              icon: Icons.person_outline,
                            ),
                            validator: (value) {
                              final text = (value ?? '').trim();
                              if (text.length < 3) {
                                return 'Username must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                        if (!_isSignIn) const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _buildInputDecoration(
                            context: context,
                            label: 'Email',
                            icon: Icons.email_outlined,
                          ),
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (!text.contains('@')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: _buildInputDecoration(
                            context: context,
                            label: 'Password',
                            icon: Icons.lock_outline,
                          ),
                          validator: (value) {
                            final text = value ?? '';
                            if (text.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(26),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withAlpha(80),
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Colors.red[800],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _loading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _loading
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        colorScheme.onPrimary,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _isSignIn ? 'SIGN IN' : 'CREATE ACCOUNT',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loading ? null : _toggleMode,
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                          ),
                          child: Text(
                            _isSignIn
                                ? 'Don\'t have an account? Sign up'
                                : 'Already have an account? Sign in',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required BuildContext context,
    required String label,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      filled: true,
      fillColor: Colors.white.withAlpha(165),
      prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withAlpha(120),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withAlpha(120),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.3),
      ),
    );
  }

  Widget _glassPanel({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(122),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withAlpha(170)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _softOrb(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withAlpha(0)],
            stops: const [0.05, 1],
          ),
        ),
      ),
    );
  }
}
