import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/theme.dart';
import '../services/sales_api.dart';
import '../utils/toast.dart';

/// Tombol export PDF/Excel untuk laporan (GET .../sales?type=exportreport),
/// dipakai bersama oleh ketiga tab Laporan (Harian/Mingguan/Bulanan) --
/// respons endpoint ini bytes file mentah (bukan JSON), jadi ditangani beda
/// dari _load() laporan yang lain. Simpan sementara ke file lalu dibagikan
/// lewat share sheet, sama pola dengan ShareReceiptScreen._shareGeneric.
class ExportReportButtons extends StatefulWidget {
  final String mode; // day/week/month
  final String date; // sesuai format yang dipakai mode itu
  final String outcode;

  const ExportReportButtons({
    super.key,
    required this.mode,
    required this.date,
    required this.outcode,
  });

  @override
  State<ExportReportButtons> createState() => _ExportReportButtonsState();
}

class _ExportReportButtonsState extends State<ExportReportButtons> {
  final _salesApi = SalesApi();
  bool _busy = false;

  Future<void> _export(String format) async {
    if (widget.outcode.isEmpty) {
      Toast.error(context, 'Outlet belum dipilih');
      return;
    }
    setState(() => _busy = true);
    try {
      final resp = await _salesApi.exportReport(
          widget.mode, widget.date, widget.outcode, format);
      if (resp.statusCode != 200) {
        // KOREKSI 2026-09-18 (QA audit #1.9): backend selalu balas JSON
        // {"error": "..."} saat export gagal (dicek di
        // gold-gym-be-v2/internal/delivery/http/sales/get_gold_gym_sales_gin.go)
        // -- baca pesan itu, sama pola dengan layar lain, bukan generik.
        String msg = 'Gagal membuat file export';
        try {
          msg = jsonDecode(utf8.decode(resp.bodyBytes))['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
        return;
      }
      final ext = format == 'xlsx' ? 'xlsx' : 'pdf';
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/laporan-${widget.mode}-${widget.date}.$ext');
      await file.writeAsBytes(resp.bodyBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Laporan Penjualan');
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal export laporan');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          tooltip: 'Export PDF',
          color: AppColors.error,
          onPressed: () => _export('pdf'),
        ),
        IconButton(
          icon: const Icon(Icons.grid_on_rounded),
          tooltip: 'Export Excel',
          color: AppColors.successDark,
          onPressed: () => _export('xlsx'),
        ),
      ],
    );
  }
}
