import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/routes.dart';
import '../config/theme.dart';
import '../models/owner_today_model.dart';
import '../providers/language_provider.dart';
import '../services/cashier_shift_api.dart';
import '../services/offline/sales_outbox.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../utils/text_formatter.dart';

/// Kartu "Hari ini" di beranda PEMILIK (2026-11-18, putaran 4 founder): penjualan dan status kas tiap outlet dalam
/// satu layar, tanpa berganti outlet. Angka dari server (sama dengan Kas History). Padanan web: OwnerTodayCard.tsx.
class OwnerTodayCard extends StatefulWidget {
  const OwnerTodayCard({super.key});

  @override
  State<OwnerTodayCard> createState() => _OwnerTodayCardState();
}

class _OwnerTodayCardState extends State<OwnerTodayCard> {
  final _api = CashierShiftApi();
  OwnerToday? _data;
  bool _loading = true;
  bool _failed = false;
  String _active = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final active = await Storage.get(AppConstants.outcode) ?? '';
    try {
      final r = await _api.ownerToday();
      if (!mounted) return;
      if (r.statusCode == 200) {
        final d = (jsonDecode(r.body) as Map)['data'];
        setState(() {
          _data = d is Map ? OwnerToday.fromJson(d.cast<String, dynamic>()) : null;
          _failed = _data == null;
          _active = active;
        });
      } else {
        setState(() => _failed = true);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _tone(String level) => switch (level) {
        'error' => Colors.red.shade700,
        'warning' => Colors.orange.shade800,
        'success' => Colors.green.shade700,
        _ => AppColors.muted,
      };

  Widget _chip(String text, Color c, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(text, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lang = context.watch<LanguageProvider>();
    final d = _data;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.today_rounded, color: AppColors.blue),
            const SizedBox(width: 6),
            Text(lang.get('Today', 'Hari ini'), style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (d != null) ...[
              const SizedBox(width: 6),
              Text(d.date, style: textTheme.bodySmall?.copyWith(color: AppColors.muted)),
            ],
            const Spacer(),
            TextButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(lang.get('Reload', 'Muat ulang')),
            ),
          ]),
          if (_loading && d == null)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          else if (_failed && d == null)
            Text(lang.get('Today\'s summary could not be loaded. Try reloading.', 'Ringkasan hari ini belum bisa dimuat. Coba muat ulang.'),
                style: textTheme.bodyMedium?.copyWith(color: AppColors.muted))
          else if (d != null) ...[
            Text(lang.get('Sales, all outlets', 'Penjualan semua outlet'), style: textTheme.bodySmall?.copyWith(color: AppColors.muted)),
            Text(TextFormatter.formatRupiah(d.sales),
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text('${d.salesCount} ${lang.get('receipts', 'nota')}', style: textTheme.bodySmall?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: SalesOutbox.instance,
              builder: (context, _) {
                final ob = SalesOutbox.instance;
                final unsent = ob.pendingCount + ob.failedCount;
                return Wrap(spacing: 6, runSpacing: 6, children: [
                  if (d.needsCheck > 0) _chip('${d.needsCheck} ${lang.get('TO CHECK', 'PERLU DICEK')}', Colors.red.shade700),
                  if (d.uncountedShifts > 0) _chip('${d.uncountedShifts} ${lang.get('shifts not counted', 'sesi tidak dihitung')}', Colors.orange.shade800),
                  if (unsent > 0)
                    _chip('$unsent ${lang.get('receipts on this device not sent yet', 'nota di perangkat ini belum terkirim')}',
                        ob.failedCount > 0 ? Colors.red.shade700 : AppColors.muted,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.antreanTransaksi)),
                ]);
              },
            ),
            const SizedBox(height: 8),
            for (final o in d.outlets) _outletRow(o, textTheme, lang),
            if (d.outlets.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(lang.get('Tap the active outlet to open Cash History. Other outlets: choose them first in the Outlet menu.', 'Ketuk outlet yang sedang aktif untuk membuka Kas History. Outlet lain: pilih dulu di menu Outlet.'),
                    style: textTheme.bodySmall?.copyWith(color: AppColors.muted)),
              ),
          ],
        ]),
      ),
    );
  }

  Widget _outletRow(OutletToday o, TextTheme textTheme, LanguageProvider lang) {
    final (status, level) = o.cashStatusFor(lang.get);
    final isActive = o.outcode == _active;
    return Card(
      margin: const EdgeInsets.only(top: 6),
      color: AppColors.background,
      elevation: 0,
      child: InkWell(
        onTap: isActive ? () => Navigator.pushNamed(context, AppRoutes.kasHistory) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: o.name.isNotEmpty ? o.name : o.outcode, style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: '  ${o.outcode}', style: textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                  ]),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  o.error.isNotEmpty
                      ? lang.get('Could not be read', 'Gagal dibaca')
                      : '${TextFormatter.formatRupiah(o.sales)} · ${o.salesCount} ${lang.get('receipts', 'nota')}${o.openShift ? ' · ${lang.get('shift running', 'sesi berjalan')}' : ''}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ]),
            ),
            if (o.error.isEmpty) _chip(status, _tone(level)),
          ]),
        ),
      ),
    );
  }
}
