import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'constants.dart';

class Storage {
  /// Kunci RAHASIA (token sesi) disimpan di penyimpanan aman (Android Keystore lewat
  /// flutter_secure_storage), BUKAN di SharedPreferences yang berupa file XML tanpa enkripsi dan bisa
  /// dibaca di perangkat root/backup (Fase 8 keamanan, 2026-09-25). Kunci lain tetap di SharedPreferences.
  static const Set<String> _secretKeys = {'access_token', 'refresh_token'};

  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static Future<String?> get(String key) async {
    if (_secretKeys.contains(key)) {
      final secure = await _secure.read(key: key);
      if (secure != null) return secure;
      // Migrasi sekali jalan: token lama (versi aplikasi sebelumnya) ada di SharedPreferences.
      // Pindahkan ke penyimpanan aman lalu hapus salinan yang tidak terenkripsi.
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(key);
      if (legacy != null) {
        await _secure.write(key: key, value: legacy);
        await prefs.remove(key);
      }
      return legacy;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> set(String key, String value) async {
    if (_secretKeys.contains(key)) {
      await _secure.write(key: key, value: value);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key); // pastikan tidak ada sisa salinan tak terenkripsi
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<void> delete(String key) async {
    if (_secretKeys.contains(key)) {
      await _secure.delete(key: key);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<void> clear() async {
    await _secure.deleteAll();
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
