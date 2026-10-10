import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Layar scan barcode (2026-10-10, temuan QA POS #4) -- dipakai saat tambah produk di POS untuk
/// mencari item lewat barcode cetak (items.item_barcode) tanpa cari manual. Mengembalikan string
/// barcode via Navigator.pop, atau null kalau dibatalkan.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.pop(context, value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) => Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
              ),
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
      ),
    );
  }
}

/// Buka layar scan & kembalikan barcode yang terdeteksi (null = batal).
Future<String?> scanBarcode(BuildContext context) {
  return Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
  );
}
