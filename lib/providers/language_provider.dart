import 'package:flutter/foundation.dart';
import '../utils/storage.dart';

class LanguageProvider with ChangeNotifier {
  String _language = 'ID';  // 'EN' | 'ID'

  String get language => _language;
  bool get isEnglish => _language == 'EN';
  bool get isIndonesian => _language == 'ID';

  Future<void> loadLanguage() async {
    // Setelah logout 'language' terhapus tapi pilihan manual pengguna ('language_pref') tetap ada -- pakai itu.
    final savedLang =
        await Storage.get('language') ?? await Storage.get('language_pref');
    if (savedLang == 'EN' || savedLang == 'ID') {
      _language = savedLang!;
      notifyListeners();
    }
  }

  /// [remember] (default true): pilihan MANUAL pengguna disimpan sebagai preferensi perangkat (tetap setelah
  /// logout, mengalahkan bahasa bawaan negara). Pemanggil otomatis (login/daftar) memakai remember: false.
  Future<void> setLanguage(String lang, {bool remember = true}) async {
    if (lang == 'EN' || lang == 'ID') {
      _language = lang;
      await Storage.set('language', lang);
      if (remember) await Storage.set('language_pref', lang);
      notifyListeners();
    }
  }

  Future<void> toggleLanguage() async {
    await setLanguage(_language == 'EN' ? 'ID' : 'EN');
  }

  // Helper untuk labels bilingual
  String get(String en, String id) {
    return isEnglish ? en : id;
  }
}
