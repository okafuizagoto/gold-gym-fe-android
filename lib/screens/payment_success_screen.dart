import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:printing/printing.dart';
import '../config/theme.dart';
import '../services/sales_api.dart';
import '../utils/responsive.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../config/routes.dart';
import 'share_receipt_screen.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String saleId;
  final double amount;
  const PaymentSuccessScreen(
      {super.key, required this.saleId, required this.amount});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  final _salesApi = SalesApi();
  bool _printing = false;

  /// Pastikan Bluetooth aktif sebelum lanjut ke dialog print native --
  /// bukan raw ESC/POS, printer Bluetooth muncul sebagai pilihan di dialog
  /// print Android biasa (package printing) setelah Bluetooth menyala.
  Future<bool> _ensureBluetoothOn() async {
    try {
      final current = await FlutterBluePlus.adapterState.first;
      if (current == BluetoothAdapterState.on) return true;
      await FlutterBluePlus.turnOn();
      return true;
    } catch (_) {
      if (mounted) {
        Toast.error(context, 'Aktifkan Bluetooth untuk mencetak struk');
      }
      return false;
    }
  }

  Future<void> _handleCetakStruk() async {
    setState(() => _printing = true);
    try {
      final btOn = await _ensureBluetoothOn();
      if (!btOn) return;
      final pdfBytes = await _salesApi.getReceiptPdfWithRetry(widget.saleId);
      if (pdfBytes == null) {
        if (mounted) Toast.error(context, 'Nota belum siap, coba lagi');
        return;
      }
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal mencetak struk');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  void _handleBagikanStruk() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShareReceiptScreen(saleId: widget.saleId),
      ),
    );
  }

  void _handleBuatPesananBaru() {
    Navigator.pushNamedAndRemoveUntil(
        context, AppRoutes.penjualan, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final short = context.isShort;
    final whiteOutline = OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.transparent,
      side: const BorderSide(color: Colors.white),
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 10),
    );

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.success,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Konten selalu bisa di-scroll (HP landscape) tapi tetap
              // memenuhi tinggi layar saat muat (tombol menempel bawah).
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: context.pagePadding, vertical: 12),
                child: Center(
                  // ConstrainedBox memaksa Column setinggi layar (tombol
                  // menempel bawah) tapi tetap boleh lebih tinggi & di-scroll
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 24,
                      maxWidth: 560,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                onPressed: _handleBuatPesananBaru,
                                tooltip: 'Tutup',
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.white, size: 28),
                              ),
                            ),
                            SizedBox(height: short ? 4 : 12),
                            Text(
                              'Pembayaran Berhasil!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: short ? 22 : 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: short ? 16 : 40),
                            Center(
                              child: Container(
                                width: short ? 84 : 110,
                                height: short ? 84 : 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                                child: Center(
                                  child: Container(
                                    width: short ? 60 : 80,
                                    height: short ? 60 : 80,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                    child: Icon(Icons.check_rounded,
                                        color: AppColors.success,
                                        size: short ? 34 : 44),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: short ? 12 : 24),
                            Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  TextFormatter.formatRupiah(widget.amount),
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: short ? 28 : 34,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: short ? 20 : 40),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _handleBagikanStruk,
                                    style: whiteOutline,
                                    icon: const Icon(Icons.ios_share_rounded,
                                        size: 18),
                                    label: const Text('Bagikan Struk',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _printing ? null : _handleCetakStruk,
                                    style: whiteOutline,
                                    icon: _printing
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Icon(Icons.print_outlined,
                                            size: 18),
                                    label: const Text('Cetak Struk',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _handleBuatPesananBaru,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.successDark,
                                ),
                                icon: const Icon(
                                    Icons.add_shopping_cart_rounded,
                                    size: 20),
                                label: const Text('Buat Pesanan Baru',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
