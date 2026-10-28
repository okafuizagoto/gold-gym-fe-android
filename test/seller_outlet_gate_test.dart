import 'package:flutter_test/flutter_test.dart';
import 'package:gold_gym_fe_android/models/outlet_model.dart';
import 'package:gold_gym_fe_android/utils/seller_outlet_gate.dart';

OutletResponse _o(String code, {bool deleted = false}) => OutletResponse(
      outlet_id: code,
      outlet_gold_id: 1,
      outlet_code: code,
      outlet_name: code,
      outlet_address: '-',
      outlet_status: 'ACTIVE',
      created_at: DateTime(2026),
      deleted: deleted,
    );

void main() {
  test('kode dummy dikenali; kode asli tidak', () {
    expect(isDummyOutletCode('ADM-ABCDEFGHJK'), isTrue);
    for (final c in ['TQT001', 'ADM001', 'ADM-001', 'ADM-', '', 'ADM-ABCDEFGHJ', 'ADM-ABCDEFGHJKM', 'XDM-ABCDEFGHJK']) {
      expect(isDummyOutletCode(c), isFalse, reason: c);
    }
  });

  test('countRealOutlets mengabaikan dummy dan outlet terhapus', () {
    expect(countRealOutlets([]), 0);
    expect(countRealOutlets([_o('ADM-ABCDEFGHJK')]), 0);
    expect(countRealOutlets([_o('TQT001', deleted: true)]), 0);
    expect(countRealOutlets([_o('ADM-ABCDEFGHJK'), _o('TQT001')]), 1);
  });
}
