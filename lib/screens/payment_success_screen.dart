import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:printing/printing.dart';
import '../services/sales_api.dart';
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
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF22C55E),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: _handleBuatPesananBaru,
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pembayaran Berhasil!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Center(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.25),
                    ),
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: const Icon(Icons.check,
                            color: Color(0xFF22C55E), size: 44),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    TextFormatter.formatRupiah(widget.amount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _handleBagikanStruk,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Bagikan Struk',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _printing ? null : _handleCetakStruk,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _printing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Cetak Struk',
                                style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleBuatPesananBaru,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF22C55E),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Buat Pesanan Baru',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
