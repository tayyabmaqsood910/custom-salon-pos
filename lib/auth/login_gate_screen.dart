import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import 'auth_service.dart';

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
  late Future<bool> _loggedInFuture;
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loggedInFuture = _auth.isLoggedIn();
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

    final ok = (username.toLowerCase() == adminUser.toLowerCase() &&
            password == adminPass) ||
        (username.toLowerCase() == managerUser.toLowerCase() &&
            password == managerPass);

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
      _loggedInFuture = Future<bool>.value(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loggedInFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == true) return widget.child;

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
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
