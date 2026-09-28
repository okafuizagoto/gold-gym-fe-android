import 'package:flutter_test/flutter_test.dart';
import 'package:gold_gym_fe_android/services/offline/sales_outbox.dart';

void main() {
  test('newSaleId: UUID v4 valid & unik', () {
    final re = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final ids = {for (var i = 0; i < 500; i++) newSaleId()};
    expect(ids.length, 500);
    expect(ids.every(re.hasMatch), isTrue);
  });

  test('OutboxSale: round-trip JSON & ringkasan', () {
    final e = OutboxSale(
      saleId: newSaleId(),
      userKey: '7',
      payload: {
        'data': {
          'header': {'sale_outcode': 'TES001', 'sale_transtotal': '25000'},
          'detail': [{}, {}],
        }
      },
      createdAt: DateTime(2026, 9, 29, 10, 0),
      attempts: 2,
      status: OutboxStatus.failed,
      error: 'stok kurang',
    );
    final back = OutboxSale.fromJson(e.toJson());
    expect(back.saleId, e.saleId);
    expect(back.status, OutboxStatus.failed);
    expect(back.error, 'stok kurang');
    expect(back.outcode, 'TES001');
    expect(back.total, 25000);
    expect(back.itemCount, 2);
    expect(back.attempts, 2);
  });
}
