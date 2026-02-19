import 'package:flutter/foundation.dart';
import '../utils/storage.dart';

class LanguageProvider with ChangeNotifier {
  String _language = 'EN';  // 'EN' | 'ID'

  String get language => _language;
  bool get isEnglish => _language == 'EN';
  bool get isIndonesian => _language == 'ID';

  Future<void> loadLanguage() async {
    final savedLang = await Storage.get('language');
    if (savedLang != null) {
      _language = savedLang;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String lang) async {
    if (lang == 'EN' || lang == 'ID') {
      _language = lang;
      await Storage.set('language', lang);
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
