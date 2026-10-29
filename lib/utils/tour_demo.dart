import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Penanda "panduan penggunaan sedang berjalan" (2026-10-29) -- padanan utils/tourDemo.ts di web. Layar yang
/// disorot panduan menggambar baris CONTOH (tampilan saja, tanpa API dan tanpa menyimpan apa pun ke database)
/// HANYA bila layar itu belum punya data asli. Begitu panduan selesai/ditutup, baris contoh hilang sendiri --
/// tidak ada yang perlu dihapus. Kalau data asli sudah ada, layar memakai data aslinya dan panduan menyorot itu.
class TourDemo {
  TourDemo._();

  static final ValueNotifier<bool> running = ValueNotifier<bool>(false);

  /// Pilih [demo] saat panduan berjalan, selain itu [normal].
  static Widget when({
    required Widget Function() demo,
    required Widget Function() normal,
  }) =>
      ValueListenableBuilder<bool>(
        valueListenable: running,
        builder: (_, on, __) => on ? demo() : normal(),
      );
}

/// Bingkai putus-putus berlabel "CONTOH" untuk baris tampilan-saja.
class TourDemoBlock extends StatelessWidget {
  final Widget child;
  final String? note;
  const TourDemoBlock({super.key, required this.child, this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x0FFFC107),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade700, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.amber.shade800),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('CONTOH',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.amber.shade900)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    note ??
                        'Tampilan contoh untuk panduan. Hilang setelah panduan selesai, tidak tersimpan.',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.muted)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
