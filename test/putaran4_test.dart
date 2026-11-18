import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_gym_fe_android/models/manual_pay_model.dart';
import 'package:gold_gym_fe_android/models/owner_today_model.dart';
import 'package:gold_gym_fe_android/utils/support.dart';
import 'package:gold_gym_fe_android/widgets/support_whatsapp_button.dart';

void main() {
  group('Kartu Hari ini: status kas (sama dengan web)', () {
    OutletToday o({double? diff, int need = 0, int unc = 0, bool open = false, int closed = 0}) => OutletToday(
        outcode: 'OUF001', difference: diff, needsCheck: need, uncountedShifts: unc, openShift: open, closedShifts: closed);
    test('urutan prioritas: PERLU DICEK > tidak dihitung > selisih', () {
      expect(o(diff: -980, need: 1, unc: 1).cashStatus, ('1 PERLU DICEK', 'error'));
      expect(o(diff: 0, unc: 1).cashStatus, ('Kas tidak dihitung', 'warning'));
      expect(o(diff: 0).cashStatus, ('Kas cocok', 'success'));
      expect(o(diff: -1980).cashStatus, ('Selisih -Rp1.980', 'error'));
      expect(o(diff: 3000).cashStatus, ('Selisih +Rp3.000', 'warning'));
      expect(o(open: true).cashStatus, ('Sesi berjalan', 'neutral'));
      expect(o().cashStatus, ('Belum ada sesi', 'neutral'));
    });
    test('parse respons server (angka desimal sebagai string)', () {
      final d = OwnerToday.fromJson({
        'date': '2026-11-18',
        'sales': '50000',
        'sales_count': 2,
        'needs_check': 1,
        'uncounted_shifts': 0,
        'outlets': [
          {'outcode': 'OUF001', 'name': 'Toko', 'sales': '50000', 'sales_count': 2, 'difference': null, 'needs_check': 1}
        ],
      });
      expect(d.sales, 50000);
      expect(d.outlets.single.difference, isNull);
      expect(d.outlets.single.needsCheck, 1);
    });
  });

  group('Bantuan WhatsApp', () {
    test('tautan wa.me memuat pesan yang di-encode', () {
      final u = Support.whatsappUri('6281234567890', 'Halo Okejual\nNota: 2');
      expect(u.toString(), 'https://wa.me/6281234567890?text=Halo%20Okejual%0ANota%3A%202');
    });
    testWidgets('tombol tersembunyi bila nomor belum diisi admin', (t) async {
      Support.setCachedForTest(const SupportContact(whatsapp: '6281234567890'));
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: SupportWhatsAppButton())));
      expect(find.text('Bantuan via WhatsApp'), findsOneWidget);
      Support.setCachedForTest(const SupportContact());
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: SupportWhatsAppButton(key: ValueKey(2)))));
      expect(find.text('Bantuan via WhatsApp'), findsNothing);
    });
  });

  test('PayRequest dari JSON server', () {
    final r = PayRequest.fromJson({
      'id': 3,
      'reference': 'OKJ-000003',
      'plan': 'growth',
      'cycle': 'YEARLY',
      'amount': '2990000',
      'status': 'PENDING',
      'created_at': '2026-11-18T10:00:00+07:00',
    });
    expect(r.yearly, true);
    expect(r.amount, 2990000);
    expect(r.createdAt, isNotNull);
  });
}
