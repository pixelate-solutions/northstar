import 'package:shared_preferences/shared_preferences.dart';

class HomePreferenceRepository {
  static const _homeTabKey = 'northstar_home_tab';
  static const _offlineModeKey = 'northstar_offline_mode';

  Future<int> getHomeTab() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_homeTabKey) ?? 0;
  }

  Future<void> setHomeTab(int tab) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_homeTabKey, tab);
  }

  Future<bool> getOfflineMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_offlineModeKey) ?? false;
  }

  Future<void> setOfflineMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_offlineModeKey, enabled);
  }
}
