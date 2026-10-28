import 'constants.dart';
import 'storage.dart';

/// Bahasa awal menurut negara akun: Indonesia -> Indonesia, negara lain -> Inggris.
String languageForCountry(String iso2) =>
    iso2.trim().toUpperCase() == 'ID' ? 'ID' : 'EN';

/// Pilihan bahasa manual pengguna di perangkat ini (tombol ID/EN), atau null kalau belum pernah memilih.
Future<String?> readLanguagePref() async {
  final v = await Storage.get(AppConstants.languagePrefKey);
  return (v == 'ID' || v == 'EN') ? v : null;
}

/// Bahasa setelah login: pilihan manual di perangkat > bahasa bawaan negara akun > bawaan lama (akun tanpa
/// negara). Jadi pengguna Indonesia yang memilih Inggris tetap Inggris setelah logout dan login lagi.
Future<String> languageAfterLogin(String countryIso2) async {
  final pref = await readLanguagePref();
  if (pref != null) return pref;
  if (countryIso2.isNotEmpty) return languageForCountry(countryIso2);
  return AppConstants.defaultLanguage == 'ID' ? 'ID' : 'EN';
}
