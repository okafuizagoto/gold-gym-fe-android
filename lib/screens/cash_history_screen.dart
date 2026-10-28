import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/cash_day_model.dart';
import '../providers/language_provider.dart';
import '../services/cashier_shift_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';

/// Kas History (2026-10-28) -- padanan pages/kas-history/index.tsx di web. Buku kas harian outlet aktif:
/// modal awal, uang tunai dari penjualan (bagian tunai nota campur sudah dipotong kembalian), refund tunai dan
/// saldo berjalan. Angka dihitung backend dengan rumus yang SAMA dengan tutup shift.
class CashHistoryScreen extends StatefulWidget {
  const CashHistoryScreen({super.key});

  @override
  State<CashHistoryScreen> createState() => _CashHistoryScreenState();
}

class _CashHistoryScreenState extends State<CashHistoryScreen> {
  final _api = CashierShiftApi();
  DateTime _date = DateTime.now();
  CashDay? _day;
  bool _loading = true;

  String get _dateStr =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final outcode = await Storage.get(AppConstants.outcode) ?? '';
      final resp = await _api.ledger(outcode, _dateStr);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() => _day = CashDay.fromJson(jsonDecode(resp.body)['data']));
      } else {
        setState(() => _day = null);
        Toast.error(context, 'Gagal memuat kas history');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _day = null);
        Toast.error(context, 'Gagal memuat kas history');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _load();
    }
  }

  Widget _stat(String label, double value, {Color? color}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 2),
              Text(TextFormatter.formatRupiah(value),
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16, color: color)),
            ],
          ),
        ),
      );

  // Penanda warna Kas History: oranye = Tarik Kas (disengaja, tercatat), biru = Tambah Kas, merah = selisih serah-terima
  // yang PERLU DICEK, kuning = selisih sebagian, hijau = penjualan / serah-terima sesuai, ungu = refund.
  (String, Color) _meta(LanguageProvider lang, String k, String flag) {
    switch (k) {
      case 'OPENING':
        return (lang.get('Opening cash', 'Modal awal'), Colors.blueGrey);
      case 'REFUND':
        return (lang.get('Cash refund', 'Refund tunai'), Colors.purple.shade600);
      case 'CASH_OUT':
        return (lang.get('Withdraw cash', 'Tarik Kas'), Colors.orange.shade800);
      case 'CASH_IN':
        return (lang.get('Add cash', 'Tambah Kas'), Colors.blue.shade700);
      case 'HANDOFF_OK':
        return (lang.get('Handover OK ✓', 'Serah-terima SESUAI ✓'), Colors.green.shade700);
      case 'HANDOFF_DIFF':
        return flag == 'PARTIAL'
            ? (lang.get('Handover difference (partial)', 'Selisih serah-terima (sebagian)'), Colors.amber.shade800)
            : (lang.get('Handover difference', 'Selisih serah-terima'), Colors.red.shade700);
      default:
        return (lang.get('Cash sale', 'Penjualan tunai'), Colors.green.shade700);
    }
  }

  Widget _chip(String label, Color c, {bool outlined = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : c.withValues(alpha: 0.14),
          border: Border.all(color: c.withValues(alpha: outlined ? 0.8 : 0.0)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
      );

  Widget _movement(LanguageProvider lang, CashMovement m) {
    final out = m.amount < 0;
    final color = out ? Colors.red.shade700 : Colors.green.shade700;
    final isHandoff = m.kind == 'HANDOFF_OK' || m.kind == 'HANDOFF_DIFF';
    final (label, c) = _meta(lang, m.kind, m.flag);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _chip(label, c, outlined: m.kind == 'HANDOFF_OK'),
                    if (m.kind == 'HANDOFF_DIFF' && m.flag == 'REVIEW')
                      _chip(lang.get('CHECK', 'PERLU DICEK'), Colors.red.shade700,
                          outlined: true),
                    Text(m.ref, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                Text('${m.time} · ${m.description}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          if (!isHandoff)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    '${out ? '-' : '+'}${TextFormatter.formatRupiah(m.amount.abs())}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                Text(
                    '${lang.get('Balance', 'Saldo')} ${TextFormatter.formatRupiah(m.balance)}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final pad = context.pagePadding;
    final day = _day;
    return PrivateRoute(
      staffMenuKey: '/kas-history',
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Kas History'),
        drawer: const AppDrawer(),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.all(pad),
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_rounded),
                label: Text('${lang.get('Date', 'Tanggal')}: $_dateStr'),
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()))
              else if (day == null)
                EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: lang.get('Could not load cash history.',
                        'Kas history tidak bisa dimuat.'))
              else ...[
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    _stat(lang.get('Opening cash', 'Modal awal'), day.opening),
                    _stat(lang.get('Cash sales', 'Penjualan tunai'), day.cashSales,
                        color: Colors.green.shade700),
                    _stat(lang.get('Cash refunds', 'Refund tunai'), day.cashRefunds,
                        color: day.cashRefunds > 0 ? Colors.red.shade700 : null),
                    _stat(lang.get('Expected cash', 'Kas seharusnya'), day.expected),
                  ],
                ),
                if (day.cashIn > 0 || day.cashOut > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                      '${lang.get('Withdraw/Add Cash records', 'Catatan Tarik/Tambah Kas')}: +${TextFormatter.formatRupiah(day.cashIn)} / -${TextFormatter.formatRupiah(day.cashOut)} · ${lang.get('End-of-day balance', 'Saldo akhir hari')} ${TextFormatter.formatRupiah(day.endBalance)}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${lang.get('Legend', 'Keterangan')}:',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    _chip(lang.get('Withdraw cash (recorded, deliberate)', 'Tarik Kas (tercatat, disengaja)'), Colors.orange.shade800),
                    _chip(lang.get('Add cash (recorded)', 'Tambah Kas (tercatat)'), Colors.blue.shade700),
                    _chip(lang.get('Handover difference: CHECK', 'Selisih serah-terima: PERLU DICEK'), Colors.red.shade700),
                    _chip(lang.get('Handover OK', 'Serah-terima sesuai'), Colors.green.shade700, outlined: true),
                  ],
                ),
                for (final h in day.handoffs.where((h) => h.diff != 0)) ...[
                  const SizedBox(height: 8),
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            width: 2,
                            color: (h.gapNet ?? 0) != 0
                                ? Colors.amber.shade800
                                : Colors.red.shade700)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _chip(
                                  (h.gapNet ?? 0) != 0
                                      ? lang.get('PARTIAL', 'SEBAGIAN')
                                      : lang.get('CHECK', 'PERLU DICEK'),
                                  (h.gapNet ?? 0) != 0
                                      ? Colors.amber.shade800
                                      : Colors.red.shade700),
                              Text(
                                  '${lang.get('Handover difference', 'Selisih serah-terima')}: ${h.diff > 0 ? '+' : ''}${TextFormatter.formatRupiah(h.diff)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                          Text(
                              '${lang.get('Previous close', 'Kas akhir sebelumnya')} ${TextFormatter.formatRupiah(h.prevCounted)} → ${lang.get('expected', 'seharusnya')} ${TextFormatter.formatRupiah(h.expected)} → ${lang.get('opened with', 'dibuka dengan')} ${TextFormatter.formatRupiah(h.opening)}'
                              '${(h.gapNet ?? 0) == 0 ? ' · ${h.diff < 0 ? lang.get('no Withdraw Cash record', 'tidak ada catatan Tarik Kas') : lang.get('no Add Cash record', 'tidak ada catatan Tambah Kas')}' : ''}'),
                          Text(
                              '${lang.get("Cashier's explanation (not verified)", 'Penjelasan kasir (belum terverifikasi)')}: “${h.reason}” — ${h.by}',
                              style: const TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                    '${lang.get('Non-cash sales (transfer, QRIS, etc.) are not in the drawer', 'Penjualan non-tunai (transfer, QRIS, dll) tidak masuk laci')}: ${TextFormatter.formatRupiah(day.nonCash)} · ${day.salesCount} ${lang.get('receipts', 'nota')}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                if (day.counted != null) ...[
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${lang.get('Counted at closing', 'Hasil hitung saat tutup sesi')}: ${TextFormatter.formatRupiah(day.counted!)}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (day.difference != null)
                            Text(
                                '${lang.get('Difference', 'Selisih')}: ${day.difference! > 0 ? '+' : ''}${TextFormatter.formatRupiah(day.difference!)}${day.difference == 0 ? ' ✓' : ''}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: day.difference == 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade700)),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.get('Cash movements', 'Pergerakan kas'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        if (day.movements.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(lang.get('No cash movement on this date.',
                                'Tidak ada pergerakan kas pada tanggal ini.')),
                          )
                        else
                          for (final m in day.movements) ...[
                            const Divider(height: 1),
                            _movement(lang, m),
                          ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
