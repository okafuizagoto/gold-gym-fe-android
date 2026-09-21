import 'package:flutter_test/flutter_test.dart';
import 'package:gold_gym_fe_android/utils/friendly_error.dart';

void main() {
  String f(String s) => friendlyErrorMessage(s, production: true);

  test('login gagal -> satu pesan yang sama', () {
    expect(f('[Service][LoginUser]: Password did not match'), msgLoginFailed);
    expect(f('[Service][LoginUser]: record not found'), msgLoginFailed);
    expect(f('Exception: invalid password'), msgLoginFailed);
  });
  test('masalah server saat login bukan "salah password"', () {
    expect(
        f('[Service][LoginUser]: dial tcp 10.0.0.1:6379: connection refused'),
        msgServer);
    expect(
        f('[Service][LoginUser]: redis: connection pool timeout'), msgServer);
  });
  test('pesan bisnis & kode dibiarkan', () {
    expect(f('email sudah terdaftar'), 'email sudah terdaftar');
    expect(f('khusus admin'), 'khusus admin');
    expect(f('TOKEN_EXPIRED'), 'TOKEN_EXPIRED');
    expect(f('Stok tidak cukup untuk item ini'),
        'Stok tidak cukup untuk item ini');
  });
  test('detail teknis disamarkan', () {
    expect(f('[Service][GetItems]: Error 1054: Unknown column x'), msgServer);
    expect(f('[Data][GetX]: record not found'), msgNotFound);
    expect(
        f("Key: 'X.Name' Error:Field validation for 'Name' failed"), msgServer);
    expect(f('Backup gagal: [Service][Backup]: Error 1045 access denied'),
        msgServer);
    expect(f('Network Error'), msgNetwork);
    expect(f('ClientException: Failed host lookup: x'), msgNetwork);
    expect(f(''), msgServer);
  });
  test('kode langganan/batas/sesi -> pesan jelas di semua environment', () {
    for (final prod in [true, false]) {
      String g(String s) => friendlyErrorMessage(s, production: prod);
      expect(g('SUBSCRIPTION_EXPIRED'), contains('mode baca saja'));
      expect(g('PLAN_UPGRADE_REQUIRED'), contains('belum termasuk di paket'));
      expect(g('PLAN_LIMIT_OUTLETS'), contains('jumlah outlet'));
      expect(g('PLAN_LIMIT_USERS'), contains('jumlah pengguna'));
      expect(g('[Service][Sales]: outlet service: OUTLET_LOCKED'),
          contains('terkunci'));
      expect(g('SESSION_REPLACED'), contains('perangkat lain'));
      expect(g('PLAY_TOKEN_IN_USE'), contains('akun lain'));
      expect(g('PLAY_PAYMENT_PENDING'), contains('diproses'));
    }
  });
  test('staging apa adanya', () {
    expect(
        friendlyErrorMessage('[Service][LoginUser]: Password did not match',
            production: false),
        '[Service][LoginUser]: Password did not match');
  });
}
