import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import '../models/sales_model.dart';
import 'text_formatter.dart';

/// Membangun perintah ESC/POS untuk struk nota (2026-10-10, QA POS #11) dari data yang SAMA
/// dengan nota PDF (SaleDetailResponse) -- tapi dirender sebagai teks mentah untuk printer
/// thermal, bukan halaman PDF. Lebar kertas dipilih kasir sekali di menu "Printer Thermal".
class ReceiptEscPos {
  /// [paperWidthMm] 58 atau 80 (mm) -- ukuran kertas thermal yang umum dipakai.
  static Future<List<int>> build(
      SaleDetailResponse sale, {required int paperWidthMm}) async {
    final profile = await CapabilityProfile.load();
    final paper = paperWidthMm >= 80 ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paper, profile);
    final header = sale.header;
    List<int> bytes = [];

    // ----- kop nota -----
    if (sale.outlet != null && sale.outlet!.outletName.isNotEmpty) {
      bytes += generator.text(
        sale.outlet!.outletName,
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
      );
      if (sale.outlet!.outletAddress.isNotEmpty) {
        bytes += generator.text(
          sale.outlet!.outletAddress,
          styles: const PosStyles(align: PosAlign.center),
        );
      }
    }
    bytes += generator.hr();

    // ----- info transaksi -----
    bytes += generator.text('No: ${header.saleTrancnum}');
    final tanggal = header.saleTransdate != null
        ? DateFormat('dd/MM/yyyy').format(header.saleTransdate!)
        : '-';
    bytes += generator.text('Tanggal: $tanggal ${header.saleTranstime}');
    bytes += generator.text('Kasir: ${header.saleSalesperson}');
    if (header.saleSalescustomer.isNotEmpty) {
      bytes += generator.text('Customer: ${header.saleSalescustomer}');
    }
    if (header.hasMeja) {
      bytes += generator.text('Meja: ${header.saleMejaNames}');
    }
    bytes += generator.hr();

    // ----- daftar item -----
    for (final item in sale.detail) {
      bytes += generator.text(item.saleStockname);
      bytes += generator.row([
        PosColumn(
          text:
              '${item.saleQty} x ${TextFormatter.formatRupiah(item.saleSalesprice)}',
          width: 7,
        ),
        PosColumn(
          text: TextFormatter.formatRupiah(item.saleTotalsalesprice),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      if (item.saleDiscountAmount != null && item.saleDiscountAmount! > 0) {
        bytes += generator.row([
          PosColumn(text: '  Diskon', width: 7),
          PosColumn(
            text: '-${TextFormatter.formatRupiah(item.saleDiscountAmount!)}',
            width: 5,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }
    }
    bytes += generator.hr();

    // ----- total & potongan -----
    final subtotal = sale.detail.fold<double>(
        0, (sum, i) => sum + i.saleTotalsalesprice);
    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 7),
      PosColumn(
        text: TextFormatter.formatRupiah(subtotal),
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    if (header.hasTotalDiscount) {
      bytes += generator.row([
        PosColumn(
            text: 'Diskon Total (${header.saleTotalDiscountPercent?.toStringAsFixed(0)}%)',
            width: 7),
        PosColumn(
          text: '-${TextFormatter.formatRupiah(header.saleTotalDiscountAmount!)}',
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    if (header.hasVoucher) {
      bytes += generator.row([
        PosColumn(text: 'Voucher ${header.saleVoucherCode ?? ''}', width: 7),
        PosColumn(
          text: '-${TextFormatter.formatRupiah(header.saleVoucherAmount!)}',
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    bytes += generator.row([
      PosColumn(
          text: 'TOTAL',
          width: 7,
          styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
        text: TextFormatter.formatRupiah(header.saleTranstotal),
        width: 5,
        styles: const PosStyles(
            align: PosAlign.right, bold: true, height: PosTextSize.size2),
      ),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Bayar (${header.salePayType ?? '-'})', width: 7),
      PosColumn(
        text: TextFormatter.formatRupiah(header.saleTranspayment),
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    if (header.saleTranschange > 0) {
      bytes += generator.row([
        PosColumn(text: 'Kembalian', width: 7),
        PosColumn(
          text: TextFormatter.formatRupiah(header.saleTranschange),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.text(
      'Terima kasih',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(2);
    bytes += generator.cut();
    return bytes;
  }
}
