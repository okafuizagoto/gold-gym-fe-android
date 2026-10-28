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
    bytes += g.text('STRUK REFUND',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += g.hr();
    bytes += g.text('No: ${h.refundNumber}');
    bytes += g.text('Tanggal: ${h.date} ${h.time}');
    bytes += g.text('Nota Asal: ${h.saleNumber}');
    bytes += g.text('Petugas: ${h.by}');
    bytes += g.hr();

    for (final l in d.lines) {
      bytes += g.text(l.stockName);
      bytes += g.row([
        PosColumn(
            text: '${l.qty} x ${TextFormatter.formatRupiah(l.unitPrice)}',
            width: 7),
        PosColumn(
            text: TextFormatter.formatRupiah(l.amount),
            width: 5,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
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
    bytes += g.hr();
    bytes += g.text('Alasan: ${h.reason}');
    bytes += g.text('Terima kasih',
        styles: const PosStyles(align: PosAlign.center));
    bytes += g.feed(2);
    bytes += g.cut();
    return bytes;
  }
}
