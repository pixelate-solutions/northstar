import 'package:shared_preferences/shared_preferences.dart';

class OfflineAuthRepository {
  static const _hadClerkSessionKey = 'northstar_had_clerk_session';

  static Future<void> markClerkSessionAvailable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hadClerkSessionKey, true);
  }

  static Future<bool> hadClerkSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hadClerkSessionKey) ?? false;
  }

  static Future<void> clearClerkSessionMarker() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hadClerkSessionKey);
  }
}
