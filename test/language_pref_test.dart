import 'package:flutter_test/flutter_test.dart';
import 'package:gold_gym_fe_android/utils/language_pref.dart';
import 'package:gold_gym_fe_android/widgets/country_autocomplete.dart';

void main() {
  test('bahasa bawaan negara: Indonesia -> ID, selain itu EN', () {
    expect(languageForCountry('ID'), 'ID');
    expect(languageForCountry(' id '), 'ID');
    for (final c in ['US', 'SG', 'MY', 'JP', '', 'IDN']) {
      expect(languageForCountry(c), 'EN', reason: c);
    }
  });

  test('flagEmoji dari kode ISO2', () {
    expect(flagEmoji('ID'), '🇮🇩');
    expect(flagEmoji('us'), '🇺🇸');
    expect(flagEmoji(''), '');
    expect(flagEmoji('IDN'), '');
  });
}
