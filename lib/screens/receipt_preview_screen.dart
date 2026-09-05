import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

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
      ),
    );
  }
}
