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
import '../widgets/tour_target.dart';
import '../utils/tour_demo.dart';

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
  bool _isSeller = true;

  String get _dateStr =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    Storage.get(AppConstants.userRoleKey).then((r) {
      if (mounted) {
        setState(() => _isSeller = (r ?? AppConstants.roleSeller) == AppConstants.roleSeller);
      }
    });
    _load();
  }

  Future<void> _verify(HandoffNote h) async {
    final noteC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Verifikasi selisih serah-terima'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Verifikasi hanya jika Anda sudah merasa oke. Jika selisih belum ditutup catatan Tarik/Tambah Kas, statusnya "diterima apa adanya"; '
                  'jika sudah ditutup, statusnya "terselesaikan". Catatan wajib diisi pada kedua kasus, dan tidak bisa diubah setelahnya.',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              TextField(
                controller: noteC,
                maxLength: 255,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Catatan verifikasi (wajib)',
                    hintText: 'mis. uang sudah dikembalikan / diterima, dipakai beli perlengkapan'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(dc, true), child: const Text('Verifikasi')),
        ],
      ),
    );
    if (ok != true) return;
    if (noteC.text.trim().length < 3) {
      if (mounted) Toast.error(context, 'Tulis catatan verifikasi terlebih dahulu');
      return;
    }
    try {
      final r = await _api.verifyHandoff(h.shiftId, noteC.text.trim());
      if (r.statusCode == 200) {
        if (mounted) Toast.success(context, 'Selisih diverifikasi');
        await _load();
      } else {
        String msg = 'Gagal memverifikasi';
        try {
          msg = jsonDecode(r.body)['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    }
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

  /// Kartu ringkasan CONTOH (teks saja) untuk panduan.
  Widget _demoStat(String label, String value) => SizedBox(
        width: 150,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),
        ),
      );

  /// Kartu disusun 2 per baris; tiap baris sama tinggi (IntrinsicHeight) dan tingginya mengikuti isi.
  Widget _statRows(List<Widget> cards) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 8));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cards[i]),
            const SizedBox(width: 8),
            Expanded(
                child: i + 1 < cards.length ? cards[i + 1] : const SizedBox()),
          ],
        ),
      ));
    }
    return Column(children: rows);
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

  // Kartu ringkasan selisih serah-terima: minus = merah, plus = hijau, nol/tidak ada = netral.
  String _signed(double v) =>
      '${v > 0 ? '+' : v < 0 ? '-' : ''}${TextFormatter.formatRupiah(v.abs())}';

  Widget _diffStat(LanguageProvider lang, String label, List<HandoffNote> list) {
    final sum = list.fold<double>(0, (a, h) => a + h.diff);
    final color = sum < 0
        ? Colors.red.shade700
        : sum > 0
            ? Colors.green.shade700
            : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 2),
            Text(_signed(sum),
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16, color: color)),
            Text(
                list.isEmpty
                    ? lang.get('No difference', 'Tidak ada selisih')
                    : '${list.length} ${lang.get('difference(s)', 'selisih')}',
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  // Penanda warna Kas History: oranye = Tarik Kas (disengaja, tercatat), biru = Tambah Kas, merah = selisih serah-terima
  // yang PERLU DICEK, kuning = selisih sebagian, hijau = penjualan / serah-terima sesuai, ungu = refund.
  (String, Color) _meta(LanguageProvider lang, String k, String flag) {
    switch (k) {
      case 'OPENING':
        return (lang.get('Opening cash', 'Modal awal'), Colors.blueGrey);
      case 'REFUND':
        return (lang.get('Cash refund', 'Refund tunai'), Colors.purple.shade600);
      case 'EXCHANGE_IN':
        return (lang.get('Exchange (cash in)', 'Tukar barang (bayar selisih)'), Colors.purple.shade600);
      case 'CARRY':
        return (lang.get('Carried over', 'Lanjutan sesi'), Colors.blueGrey);
      case 'CASH_OUT':
        return (lang.get('Withdraw cash', 'Tarik Kas'), Colors.orange.shade800);
      case 'CASH_IN':
        return (lang.get('Add cash', 'Tambah Kas'), Colors.blue.shade700);
      case 'HANDOFF_OK':
        return (lang.get('Handover OK ✓', 'Serah-terima SESUAI ✓'), Colors.green.shade700);
      case 'HANDOFF_DIFF':
        if (flag == 'VERIFIED_RESOLVED') {
          return (lang.get('Handover difference · VERIFIED ✓ resolved', 'Selisih serah-terima · TERVERIFIKASI ✓ terselesaikan'), Colors.green.shade700);
        }
        if (flag == 'VERIFIED_ACCEPTED') {
          return (lang.get('Handover difference · VERIFIED ✓ accepted', 'Selisih serah-terima · TERVERIFIKASI ✓ diterima'), Colors.blue.shade700);
        }
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
                TourDemo.when(
                  demo: () => TourDemoBlock(
                    child: TourTarget(
                      id: 'kas-history-main',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _demoStat(lang.get('Opening cash', 'Modal awal'),
                              'Rp200.000'),
                          _demoStat(lang.get('Cash sales', 'Penjualan tunai'),
                              'Rp40.000'),
                          _demoStat(lang.get('Cash refunds', 'Refund tunai'),
                              'Rp0'),
                          _demoStat(
                              lang.get('Expected cash', 'Kas seharusnya'),
                              'Rp240.000'),
                        ],
                      ),
                    ),
                  ),
                  normal: () => EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: lang.get('Could not load cash history.',
                          'Kas history tidak bisa dimuat.')),
                )
              else ...[
                TourTarget(
                  id: 'kas-history-main',
                  // Baris berpasangan dgn tinggi mengikuti isi (bukan GridView rasio tetap: label yang
                  // membungkus dua baris memotong isi kartu di layar sempit/font besar).
                  child: _statRows([
                    _stat(lang.get('Opening cash', 'Modal awal'), day.opening),
                    _stat(lang.get('Cash sales', 'Penjualan tunai'), day.cashSales,
                        color: Colors.green.shade700),
                    _stat(lang.get('Cash refunds', 'Refund tunai'), day.cashRefunds,
                        color: day.cashRefunds > 0 ? Colors.red.shade700 : null),
                    _stat(lang.get('Expected cash', 'Kas seharusnya'), day.expected),
                    _diffStat(
                        lang,
                        lang.get('Unverified difference', 'Selisih belum terverifikasi'),
                        day.handoffs.where((h) => h.diff != 0 && !h.verified).toList()),
                    _diffStat(
                        lang,
                        lang.get('Verified difference', 'Selisih sudah terverifikasi'),
                        day.handoffs.where((h) => h.diff != 0 && h.verified).toList()),
                  ]),
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
                    _chip(lang.get('Difference verified by owner ✓', 'Selisih terverifikasi penjual ✓'), Colors.green.shade700),
                  ],
                ),
                for (final h in day.handoffs.where((h) => h.diff != 0)) ...[
                  const SizedBox(height: 8),
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            width: 2,
                            color: h.verified
                                ? Colors.green.shade700
                                : (h.gapNet ?? 0) != 0
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
                              h.verified
                                  ? _chip(
                                      h.verifyStatus == 'RESOLVED'
                                          ? lang.get('VERIFIED ✓ resolved', 'TERVERIFIKASI ✓ terselesaikan')
                                          : lang.get('VERIFIED ✓ accepted as is', 'TERVERIFIKASI ✓ diterima apa adanya'),
                                      Colors.green.shade700)
                                  : _chip(
                                      (h.gapNet ?? 0) != 0
                                          ? lang.get('PARTIAL', 'SEBAGIAN')
                                          : lang.get('CHECK', 'PERLU DICEK'),
                                      (h.gapNet ?? 0) != 0
                                          ? Colors.amber.shade800
                                          : Colors.red.shade700),
                              Text(
                                  '${lang.get('Handover difference', 'Selisih serah-terima')}: ${_signed(h.diff)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                          Text(
                              '${lang.get('Previous close', 'Kas akhir sebelumnya')} ${TextFormatter.formatRupiah(h.prevCounted)} → ${lang.get('expected', 'seharusnya')} ${TextFormatter.formatRupiah(h.expected)} → ${lang.get('opened with', 'dibuka dengan')} ${TextFormatter.formatRupiah(h.opening)}'
                              '${(h.gapNet ?? 0) == 0 ? ' · ${h.diff < 0 ? lang.get('no Withdraw Cash record', 'tidak ada catatan Tarik Kas') : lang.get('no Add Cash record', 'tidak ada catatan Tambah Kas')}' : ''}'),
                          Text(
                              '${h.verified ? lang.get("Cashier's explanation", 'Penjelasan kasir') : lang.get("Cashier's explanation (not verified)", 'Penjelasan kasir (belum terverifikasi)')}: “${h.reason}” — ${h.by}',
                              style: const TextStyle(color: AppColors.muted)),
                          if (h.verified)
                            Text(
                                '✓ ${lang.get('Verified by', 'Diverifikasi oleh')} ${h.verifyBy} · ${h.verifyAt.length >= 16 ? h.verifyAt.substring(0, 16).replaceFirst('T', ' ') : h.verifyAt}: “${h.verifyNote}”',
                                style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600)),
                          if (!h.verified && _isSeller)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton(
                                  onPressed: () => _verify(h),
                                  child: Text(lang.get('Verify', 'Verifikasi'))),
                            ),
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
