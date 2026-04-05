import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _kLoggedIn = 'auth_logged_in';
  static const _kUsername = 'auth_username';
  static const _kRegisteredUsers = 'auth_registered_users_json';

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<Map<String, String>> _loadRegisteredMap(SharedPreferences prefs) async {
    final raw = prefs.getString(_kRegisteredUsers);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  /// Returns `null` on success, or an error message.
  Future<String?> registerUser({
    required String username,
    required String password,
    required Set<String> reservedLowercase,
  }) async {
    final u = username.trim();
    if (u.length < 3) {
      return 'Username must be at least 3 characters.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    final key = u.toLowerCase();
    if (reservedLowercase.contains(key)) {
      return 'That username is reserved. Choose a different one.';
    }
    final prefs = await SharedPreferences.getInstance();
    final users = await _loadRegisteredMap(prefs);
    if (users.containsKey(key)) {
      return 'An account with this username already exists.';
    }
    users[key] = _hashPassword(password);
    await prefs.setString(_kRegisteredUsers, jsonEncode(users));
    return null;
  }

  Future<bool> matchesRegisteredUser(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final users = await _loadRegisteredMap(prefs);
    final hash = users[username.trim().toLowerCase()];
    if (hash == null) return false;
    return hash == _hashPassword(password);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kLoggedIn) ?? false;
  }

  Future<void> saveLogin(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLoggedIn, true);
    await prefs.setString(_kUsername, username);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLoggedIn, false);
    await prefs.remove(_kUsername);
  }
}
