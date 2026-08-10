import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the logged-in scanner user's raw JSON locally so the app can
/// skip the login page on subsequent launches.
class AuthLocalDatasource {
  static const _sessionKey = 'scanner_auth_session';

  Future<void> saveSession(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(json));
  }

  Future<Map<String, dynamic>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
