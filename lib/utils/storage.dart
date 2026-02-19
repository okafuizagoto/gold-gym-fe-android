import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Storage {
  static Future<String?> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> set(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Custom menu management
  static Future<List<dynamic>> getUserMenus() async {
    final menusJson = await get('user_custom_menus');
    if (menusJson == null) return [];
    return jsonDecode(menusJson);
  }

  static Future<void> addUserMenu(Map<String, dynamic> newMenu) async {
    final currentMenus = await getUserMenus();
    currentMenus.add(newMenu);
    await set('user_custom_menus', jsonEncode(currentMenus));
  }
}
