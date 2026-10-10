import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/cashier_shift_api.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../utils/subscription_state.dart' show formatRupiah;
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// Layar "Sesi Kasir" (2026-10-10, temuan QA POS #2) -- buka/tutup shift dengan rekonsiliasi kas:
/// modal awal saat buka, hasil hitung fisik uang di laci saat tutup, selisih dicatat apa adanya
/// untuk audit (TIDAK memblokir penutupan). Satu shift OPEN per outlet dijaga backend.
class CashierShiftScreen extends StatefulWidget {
  const CashierShiftScreen({super.key});

  @override
  State<CashierShiftScreen> createState() => _CashierShiftScreenState();
}

class _CashierShiftScreenState extends State<CashierShiftScreen> {
  final _api = CashierShiftApi();
  bool _loading = true;
  String _outcode = '';
  Map<String, dynamic>? _current; // null = belum ada shift terbuka
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _outcode = await Storage.get(AppConstants.outcode) ?? '';
    if (_outcode.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final cur = await _api.current(_outcode);
      if (cur.statusCode == 200) {
        final data = jsonDecode(cur.body)['data'];
        _current = data == null ? null : Map<String, dynamic>.from(data);
      }
      final hist = await _api.history(_outcode);
      if (hist.statusCode == 200) {
        final rows = (jsonDecode(hist.body)['data'] ?? []) as List;
        _history = rows.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memuat data sesi kasir');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openShift() async {
    final ctl = TextEditingController(text: '0');
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buka Sesi Kasir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Masukkan jumlah uang tunai yang sudah ada di laci sebelum mulai jualan.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Modal awal (Rp)'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
                dialogContext, double.tryParse(ctl.text.trim()) ?? 0),
            child: const Text('BUKA SESI'),
          ),
        ],
      ),
    );
    if (value == null) return;
    if (value < 0) {
      if (mounted) Toast.error(context, 'Modal awal tidak boleh negatif');
      return;
    }
    try {
      final resp = await _api.open(_outcode, value);
      if (resp.statusCode == 200) {
        if (mounted) Toast.success(context, 'Sesi kasir dibuka');
        await _load();
      } else {
        String msg = 'Gagal membuka sesi';
        try {
          msg = jsonDecode(resp.body)['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    }
  }

  Future<void> _closeShift() async {
    if (_current == null) return;
    final shiftId = _current!['shift_id'] as int;

    Map<String, dynamic>? preview;
    try {
      final resp = await _api.preview(_outcode);
      if (resp.statusCode == 200) {
        preview = Map<String, dynamic>.from(jsonDecode(resp.body)['data']);
      }
    } catch (_) {}

    final expected =
        preview == null ? 0.0 : _toDouble(preview['shift']['shift_expected_cash']);
    final cashSales = preview == null ? 0.0 : _toDouble(preview['cash_sales']);
    final salesCount = preview == null ? 0 : (preview['sales_count'] as num? ?? 0).toInt();

    final countedCtl = TextEditingController();
    final noteCtl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tutup Sesi Kasir'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nota selama sesi ini: $salesCount'),
              Text('Penjualan tunai: ${formatRupiah(cashSales.round())}'),
              Text('Ekspektasi kas di laci: ${formatRupiah(expected.round())}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text('Hitung uang fisik di laci sekarang, lalu masukkan jumlahnya:'),
              const SizedBox(height: 8),
              TextField(
                controller: countedCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Uang hasil hitung (Rp)'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtl,
                maxLength: 255,
                decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    hintText: 'mis. ada kembalian salah'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('TUTUP SESI'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final counted = double.tryParse(countedCtl.text.trim());
    if (counted == null || counted < 0) {
      if (mounted) Toast.error(context, 'Isi jumlah uang hasil hitung yang valid');
      return;
    }

    try {
      final resp = await _api.close(shiftId, counted, noteCtl.text.trim());
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body)['data'];
        final diff = _toDouble(data?['shift']?['shift_difference']);
        if (mounted) {
          Toast.success(
            context,
            diff == 0
                ? 'Sesi ditutup, kas pas'
                : 'Sesi ditutup, selisih ${diff > 0 ? '+' : ''}${formatRupiah(diff.round())}',
          );
        }
        await _load();
      } else {
        String msg = 'Gagal menutup sesi';
        try {
          msg = jsonDecode(resp.body)['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    }
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Sesi Kasir'),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _outcode.isEmpty
                ? const EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Pilih outlet terlebih dahulu')
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        SectionCard(
                          title: _current == null
                              ? 'Belum ada sesi berjalan'
                              : 'Sesi sedang berjalan',
                          icon: Icons.point_of_sale_outlined,
                          child: _current == null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                        'Buka sesi kasir untuk mulai mencatat modal awal & rekonsiliasi kas harian.'),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.lock_open_rounded),
                                      onPressed: _openShift,
                                      label: const Text('BUKA SESI KASIR'),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                        'Dibuka oleh ${_current!['shift_opened_by']}'),
                                    Text(
                                        'Modal awal: ${formatRupiah(_toDouble(_current!['shift_opening_cash']).round())}'),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.lock_outline_rounded),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.error),
                                      onPressed: _closeShift,
                                      label: const Text('TUTUP SESI KASIR'),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Riwayat sesi',
                          icon: Icons.history_rounded,
                          child: _history.isEmpty
                              ? const Text('Belum ada riwayat sesi kasir')
                              : Column(
                                  children: _history.map((h) {
                                    final closed = h['shift_status'] == 'CLOSED';
                                    final diff = closed
                                        ? _toDouble(h['shift_difference'])
                                        : null;
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                          '${h['shift_opened_by']} • ${closed ? 'Selesai' : 'Berjalan'}'),
                                      subtitle: Text(
                                          'Modal: ${formatRupiah(_toDouble(h['shift_opening_cash']).round())}'
                                          '${closed ? ' • Selisih: ${diff! >= 0 ? '+' : ''}${formatRupiah(diff.round())}' : ''}'),
                                      trailing: closed && diff != 0
                                          ? Icon(Icons.warning_amber_rounded,
                                              color: AppColors.warningDark,
                                              size: 18)
                                          : null,
                                    );
                                  }).toList(),
                                ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
