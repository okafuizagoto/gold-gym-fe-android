import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../models/refund_model.dart';
import 'text_formatter.dart';

/// STRUK REFUND untuk printer thermal (ESC/POS), sejajar ReceiptEscPos (struk penjualan) dan struk PDF refund.
class RefundEscPos {
  static Future<List<int>> build(RefundDetail d,
      {required int paperWidthMm}) async {
    final profile = await CapabilityProfile.load();
    final paper = paperWidthMm >= 80 ? PaperSize.mm80 : PaperSize.mm58;
    final g = Generator(paper, profile);
    final h = d.header;
    List<int> bytes = [];

    if (d.outletName.isNotEmpty) {
      bytes += g.text(d.outletName,
          styles: const PosStyles(
              align: PosAlign.center, bold: true, height: PosTextSize.size2));
      if (d.outletAddress.isNotEmpty) {
        bytes += g.text(d.outletAddress,
            styles: const PosStyles(align: PosAlign.center));
      }
    }
    bytes += g.hr();
    bytes += g.text(h.isExchange ? 'STRUK TUKAR BARANG' : 'STRUK REFUND',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += g.hr();
    bytes += g.text('No: ${h.refundNumber}');
    bytes += g.text('Tanggal: ${h.date} ${h.time}');
    bytes += g.text('Nota Asal: ${h.saleNumber}');
    bytes += g.text('Petugas: ${h.by}');
    bytes += g.hr();

    List<int> lineRows(String name, int qty, double unit, double amount) => [
          ...g.text(name),
          ...g.row([
            PosColumn(text: '$qty x ${TextFormatter.formatRupiah(unit)}', width: 7),
            PosColumn(
                text: TextFormatter.formatRupiah(amount),
                width: 5,
                styles: const PosStyles(align: PosAlign.right)),
          ]),
        ];
    List<int> kv(String k, String v, {bool bold = false}) => g.row([
          PosColumn(text: k, width: 7, styles: PosStyles(bold: bold)),
          PosColumn(
              text: v,
              width: 5,
              styles: PosStyles(align: PosAlign.right, bold: bold)),
        ]);

    if (h.isExchange) {
      bytes += g.text('BARANG DIKEMBALIKAN', styles: const PosStyles(bold: true));
    }
    for (final l in d.lines) {
      bytes += lineRows(l.stockName, l.qty, l.unitPrice, l.amount);
    }
    if (h.isExchange) {
      bytes += g.hr();
      bytes += g.text('BARANG PENGGANTI', styles: const PosStyles(bold: true));
      for (final l in d.newLines) {
        bytes += lineRows(l.stockName, l.qty, l.unitPrice, l.amount);
      }
      bytes += g.hr();
      bytes += kv('Nilai dikembalikan', TextFormatter.formatRupiah(h.total));
      bytes += kv('Nilai pengganti', TextFormatter.formatRupiah(h.exchangeTotal));
      if (h.net > 0) {
        bytes += kv('PELANGGAN BAYAR', TextFormatter.formatRupiah(h.net), bold: true);
        bytes += g.text('Dibayar via: ${h.method}');
      } else if (h.net < 0) {
        bytes += kv('DIKEMBALIKAN', TextFormatter.formatRupiah(-h.net), bold: true);
        bytes += g.text('Dikembalikan via: ${h.method}');
      } else {
        bytes += g.text('TUKAR SAMA NILAI - tidak ada selisih',
            styles: const PosStyles(align: PosAlign.center, bold: true));
      }
    } else {
      bytes += g.hr();
      bytes += g.row([
        PosColumn(
            text: 'TOTAL REFUND',
            width: 7,
            styles: const PosStyles(bold: true, height: PosTextSize.size2)),
        PosColumn(
            text: TextFormatter.formatRupiah(h.total),
            width: 5,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size2)),
      ]);
      bytes += g.text('Dikembalikan via: ${h.method}');
    }
    bytes += g.hr();
    bytes += g.text('Alasan: ${h.reason}');
    bytes += g.text('Terima kasih',
        styles: const PosStyles(align: PosAlign.center));
    bytes += g.feed(2);
    bytes += g.cut();
    return bytes;
  }
}
