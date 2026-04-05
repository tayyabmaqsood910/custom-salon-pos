import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import 'auth_service.dart';
import 'sign_up_screen.dart';

class LoginGateScreen extends StatefulWidget {
  const LoginGateScreen({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<LoginGateScreen> createState() => _LoginGateScreenState();
}

class _LoginGateScreenState extends State<LoginGateScreen> {
  final _auth = AuthService();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _checkingSession = true;
  bool _loggedIn = false;
  Object? _sessionError;
  bool _busy = false;
  String? _error;
  bool _showSignUp = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final ok = await _auth.isLoggedIn();
      if (!mounted) return;
      setState(() {
        _loggedIn = ok;
        _checkingSession = false;
        _sessionError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sessionError = e;
        _checkingSession = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Username and password are required.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final settings = context.read<AppProvider>().settings;
    final adminUser = settings['adminUsername'] ?? 'admin';
    final adminPass = settings['adminPassword'] ?? 'Admin123!';
    final managerUser = settings['managerUsername'] ?? 'manager';
    final managerPass = settings['managerPassword'] ?? 'Manager123!';

    final adminOk = username.toLowerCase() == adminUser.toLowerCase() &&
        password == adminPass;
    final managerOk = username.toLowerCase() == managerUser.toLowerCase() &&
        password == managerPass;
    final registeredOk = await _auth.matchesRegisteredUser(username, password);
    final ok = adminOk || managerOk || registeredOk;

    if (!ok) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Invalid username or password.';
      });
      return;
    }

    await _auth.saveLogin(username);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _loggedIn = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_sessionError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not restore session: $_sessionError'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _checkingSession = true;
                      _sessionError = null;
                    });
                    _restoreSession();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_loggedIn) return widget.child;

    if (_showSignUp) {
      final settings = context.watch<AppProvider>().settings;
      final reserved = <String>{
        (settings['adminUsername'] ?? 'admin').trim().toLowerCase(),
        (settings['managerUsername'] ?? 'manager').trim().toLowerCase(),
      };
      return SignUpScreen(
        onRegister: (u, p) => _auth.registerUser(
          username: u,
          password: p,
          reservedLowercase: reserved,
        ),
        onLeave: ({required bool created}) {
          setState(() => _showSignUp = false);
          if (created && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created. You can log in now.'),
              ),
            );
          }
        },
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            color: Theme.of(context).cardColor,
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Login to ATA-Styles-POS',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter username and password to continue.',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    onSubmitted: (_) => _doLogin(),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _doLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sage,
                      ),
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Login'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _showSignUp = true),
                      child: const Text("Don't have an account? Sign up"),
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
