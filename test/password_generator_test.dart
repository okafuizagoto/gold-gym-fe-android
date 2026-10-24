import 'package:flutter_test/flutter_test.dart';
import 'package:gold_gym_fe_android/utils/password_generator.dart';
import 'package:gold_gym_fe_android/utils/password_strength.dart';

void main() {
  test('password acak selalu memenuhi kebijakan dan level Sangat kuat', () {
    for (var i = 0; i < 300; i++) {
      final pw = generatePassword(12);
      final e = evaluatePassword(pw);
      expect(pw.length, 12);
      expect(e.valid, isTrue, reason: pw);
      expect(e.level, 3, reason: pw);
      expect(RegExp(r'[0O1lI]').hasMatch(pw), isFalse, reason: pw);
    }
  });

  test('panjang minimal 8 dan hasil berbeda tiap panggilan', () {
    expect(generatePassword(3).length, 8);
    expect(generatePassword(12) == generatePassword(12), isFalse);
  });
}
