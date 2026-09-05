import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../config/theme.dart';

/// Menampilkan nota PDF langsung di layar (setelah user memilih cetak struk).
/// Dari sini user bisa lihat, print, atau share PDF-nya.
class ReceiptPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;

  const ReceiptPreviewScreen({
    super.key,
    required this.pdfBytes,
    this.title = 'Nota',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        build: (format) async => pdfBytes,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: '$title.pdf',
        scrollViewDecoration: const BoxDecoration(color: AppColors.background),
        pdfPreviewPageDecoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
      ),
    );
  }
}
