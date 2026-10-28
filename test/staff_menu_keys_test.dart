import 'package:flutter_test/flutter_test.dart';
import 'package:gold_gym_fe_android/utils/staff_menu_keys.dart';

void main() {
  // Padanan backend entity.AllStaffMenuKeys / entity.MenuKeyLokasiKantor.
  test('Akses Staff memuat izin Lokasi Kantor dan tanpa key ganda', () {
    final keys = StaffMenuKeys.options.map((o) => o.key).toList();
    expect(keys, contains('/lokasi-kantor'));
    expect(keys.toSet().length, keys.length);
  });
}
