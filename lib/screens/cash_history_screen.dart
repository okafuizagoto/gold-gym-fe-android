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

  String _kind(LanguageProvider lang, String k) => k == 'OPENING'
      ? lang.get('Opening cash', 'Modal awal')
      : k == 'REFUND'
          ? lang.get('Cash refund', 'Refund tunai')
          : lang.get('Cash sale', 'Penjualan tunai');

  Widget _movement(LanguageProvider lang, CashMovement m) {
    final out = m.amount < 0;
    final color = out ? Colors.red.shade700 : Colors.green.shade700;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_kind(lang, m.kind)} · ${m.ref}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${m.time} · ${m.description}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
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
