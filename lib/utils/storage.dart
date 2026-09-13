import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'constants.dart';

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

  // Cache menu_key yang tidak boleh diakses akun STAFF -- diisi saat login
  // (lihat login_screen.dart), dibaca app_drawer.dart untuk filter menu.
  static Future<void> setStaffDeniedMenuKeys(List<String> keys) async {
    await set(AppConstants.staffDeniedMenusKey, jsonEncode(keys));
  }

  static Future<List<String>> getStaffDeniedMenuKeys() async {
    final raw = await get(AppConstants.staffDeniedMenusKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }
}
