import 'package:flutter_test/flutter_test.dart';
import 'package:gold_gym_fe_android/utils/password_strength.dart';

void main() {
  // [password, valid, level] -- sama persis dengan kasus tes Next.js.
  final cases = <List<Object>>[
    ['Abcde1', true, 1],
    ['Testing1', true, 2],
    ['TestingZ#', false, 0],
    ['TestingZ#1', true, 2],
    ['Abc12#', true, 2],
    ['MyStr0ng#Pass99', true, 3],
    ['Passw0rd!', true, 0],
    ['Password1', true, 0],
    ['Qwerty123', true, 0],
    ['Okejual1', true, 0],
    ['Aaaaa1', true, 0],
    ['abcdef1', false, 0],
    ['ABCDEF1', false, 0],
    ['Abcdefg', false, 0],
    ['Ab1', false, 0],
    ['', false, 0],
    ['######', false, 0],
    ['Ünï1code', true, 2],
    ['Aa1${'x' * 126}', false, 0],
  ];
  for (final c in cases) {
    final pw = c[0] as String;
    test('"${pw.length > 20 ? pw.substring(0, 20) : pw}"', () {
      final r = evaluatePassword(pw);
      expect(r.valid, c[1]);
      expect(r.level, c[2]);
    });
  }
  test('label sesuai level', () {
    expect(evaluatePassword('Abcde1').label, 'Cukup');
    expect(evaluatePassword('MyStr0ng#Pass99').label, 'Sangat kuat');
  });
}
