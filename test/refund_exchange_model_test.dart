import 'package:flutter_test/flutter_test.dart';
import 'package:gold_gym_fe_android/models/refund_model.dart';

void main() {
  test('RefundDetail memuat tukar barang: pengganti, selisih bersih, dan mode', () {
    final d = RefundDetail.fromJson({
      'header': {
        'refund_id': 'r1',
        'refund_number': 'RF-TQT001-20261029-0001',
        'refund_mode': 'EXCHANGE',
        'refund_total': '10000',
        'refund_exchange_total': '15000',
        'refund_net': '5000',
        'refund_net_method': 'TUNAI',
        'refund_cash_delta': '5000',
        'refund_method': 'TUNAI',
      },
      'lines': [
        {'td_id': 1, 'stock_name': 'Kopi M', 'qty': 1, 'unit_price': '10000', 'refund_amount': '10000', 'restock_yn': 'Y'}
      ],
      'new_lines': [
        {'stock_id': 'KOPI-L', 'stock_name': 'Kopi L', 'qty': 1, 'unit_price': '15000', 'line_amount': '15000'}
      ],
    });
    expect(d.header.isExchange, true);
    expect(d.header.net, 5000);
    expect(d.header.exchangeTotal, 15000);
    expect(d.header.cashDelta, 5000);
    expect(d.newLines.single.stockName, 'Kopi L');
    expect(refundModeLabel(d.header.mode), 'Tukar barang');
  });

  test('refund Tahap 1 tetap terbaca: bukan tukar barang, tanpa baris pengganti', () {
    final d = RefundDetail.fromJson({
      'header': {'refund_id': 'r2', 'refund_total': '10000', 'refund_method': 'TUNAI'},
      'lines': [],
    });
    expect(d.header.isExchange, false);
    expect(d.newLines, isEmpty);
    expect(refundModeLabel(d.header.mode), 'Refund');
  });
}
