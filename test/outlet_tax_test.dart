import 'package:flutter_test/flutter_test.dart';
import 'package:gold_gym_fe_android/models/outlet_tax_model.dart';
import 'package:gold_gym_fe_android/models/sales_model.dart';
import 'package:gold_gym_fe_android/providers/cart_provider.dart';
import 'package:gold_gym_fe_android/utils/subscription_state.dart' as sub;
import 'package:gold_gym_fe_android/utils/text_formatter.dart';

void main() {
  formatTests();
  group('payload nota memuat pajak yang dipakai (nota offline, 2026-11-18)', () {
    test('sale_tax_client dikirim apa adanya; pajak mati -> persen 0', () {
      final cart = CartProvider()
        ..setTaxSettings(const TaxSettings(enabled: true, name: 'PB1', percent: 10, inclusive: false));
      var h = (cart.buildInsertPayload(outcode: 'OUF001', salesPerson: 'x')['data'] as Map)['header'] as Map;
      expect(h['sale_tax_client'], {'enabled': true, 'name': 'PB1', 'percent': 10.0, 'inclusive': false});
      expect(h['sale_tax_applied'], true);
      expect(h.containsKey('sale_offline'), false, reason: 'tanda offline hanya dipasang antrean saat mengirim ulang');
      cart.setTaxSettings(const TaxSettings(enabled: false, percent: 11));
      h = (cart.buildInsertPayload(outcode: 'OUF001', salesPerson: 'x')['data'] as Map)['header'] as Map;
      expect((h['sale_tax_client'] as Map)['enabled'], false);
      expect((h['sale_tax_client'] as Map)['percent'], 0);
      cart.setTaxSettings(null);
      h = (cart.buildInsertPayload(outcode: 'OUF001', salesPerson: 'x')['data'] as Map)['header'] as Map;
      expect(h.containsKey('sale_tax_client'), false, reason: 'pengaturan pajak tidak diketahui -> tidak dikirim');
    });
  });
  group('computeTax (sama dengan outlettax.Compute di server)', () {
    test('mati / persen 0 / net 0 -> tanpa pajak', () {
      expect(computeTax(null, 10000).tax, 0);
      expect(computeTax(const TaxSettings(), 10000).tax, 0);
      expect(computeTax(const TaxSettings(enabled: true, percent: 0), 10000).tax, 0);
      expect(computeTax(const TaxSettings(enabled: true, percent: 11), 0).tax, 0);
    });
    test('sudah termasuk: total tetap, pajak dibulatkan', () {
      final r = computeTax(const TaxSettings(enabled: true, percent: 11), 111000);
      expect(r.tax, 11000);
      expect(r.due, 111000);
      expect(computeTax(const TaxSettings(enabled: true, percent: 11), 9990).tax, 990);
    });
    test('belum termasuk: pajak ditambahkan', () {
      final r = computeTax(
          const TaxSettings(enabled: true, percent: 11, inclusive: false), 9990);
      expect(r.tax, 1099); // 1098.9 dibulatkan
      expect(r.due, 11089);
    });
  });

  group('SaleHistoryModel total', () {
    Map<String, dynamic> base() => {
          'sale_id': 'S1',
          'sale_transtotal': '9000',
          'sale_transpayment': '9000',
          'sale_transchange': '0',
        };
    test('diskon total tidak dikurangkan dua kali', () {
      final m = SaleHistoryModel.fromJson({
        ...base(),
        'sale_total_discount_percent': '10',
        'sale_total_discount_amount': '1000',
      });
      expect(m.subtotalBeforeTotalDiscount, 10000);
      expect(m.payableTotal, 9000);
    });
    test('voucher dikurangkan dari transtotal', () {
      final m = SaleHistoryModel.fromJson({
        ...base(),
        'sale_voucher_amount': '9',
      });
      expect(m.payableTotal, 8991);
    });
    test('pajak belum termasuk ditambahkan, sudah termasuk tidak', () {
      final ex = SaleHistoryModel.fromJson({
        ...base(),
        'sale_tax_amount': '990',
        'sale_tax_inclusive': false,
      });
      expect(ex.payableTotal, 9990);
      final inc = SaleHistoryModel.fromJson({
        ...base(),
        'sale_tax_amount': '892',
        'sale_tax_inclusive': true,
      });
      expect(inc.payableTotal, 9000);
    });
  });
}

// Format rupiah negatif harus sama dengan web: "-Rp980" (dulu "Rp-.980" / "Rp-980").
void formatTests() {
  group('formatRupiah negatif', () {
    test('subscription_state', () {
      expect(sub.formatRupiah(-980), '-Rp980');
      expect(sub.formatRupiah(-8990), '-Rp8.990');
      expect(sub.formatRupiah(1234567), 'Rp1.234.567');
      expect(sub.formatRupiah(0), 'Rp0');
    });
    test('TextFormatter', () {
      expect(TextFormatter.formatRupiah(-980), '-Rp980');
      expect(TextFormatter.formatRupiah(-8990.4), '-Rp8.990');
      expect(TextFormatter.formatRupiah(1234567), 'Rp1.234.567');
    });
  });
}
