import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/refund_model.dart';
import '../providers/language_provider.dart';
import '../services/refund_api.dart';
import '../services/thermal_printer.dart';
import '../utils/constants.dart';
import '../utils/debouncer.dart';
import '../utils/refund_escpos.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import '../widgets/search_field.dart';

/// Riwayat Refund (2026-10-28) -- padanan pages/riwayat-refund/index.tsx di web. Daftar refund outlet aktif
/// (nomor refund, nota asal, total, metode), detail per barang, cetak struk (PDF / thermal), plus panduan singkat
/// "Cara refund". Hanya penjual dan staff yang diizinkan penjual (menu_key "/riwayat-refund").
class RefundHistoryScreen extends StatefulWidget {
  const RefundHistoryScreen({super.key});

  @override
  State<RefundHistoryScreen> createState() => _RefundHistoryScreenState();
}

class _RefundHistoryScreenState extends State<RefundHistoryScreen> {
  final _api = RefundApi();
  final _debouncer = Debouncer(milliseconds: 400);
  final _searchController = TextEditingController();
  List<RefundHeader> _rows = [];
  bool _loading = true;
  bool _hasMore = false;
  int _page = 1;
  String _search = '';
  String? _printingId;
  static const _length = 20;

  @override
  void initState() {
    super.initState();
    _load(1, false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load(int target, bool append) async {
    setState(() => _loading = true);
    try {
      final outcode = await Storage.get(AppConstants.outcode) ?? '';
      final resp = await _api.list(
          outcode: outcode, search: _search, page: target, length: _length);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final list = ((body['data'] ?? []) as List)
            .map((e) => RefundHeader.fromJson(e as Map<String, dynamic>))
            .toList();
        final total = int.tryParse('${body['metadata']?['total_data']}') ?? list.length;
        setState(() {
          _rows = append ? [..._rows, ...list] : list;
          _page = target;
          _hasMore = target * _length < total;
        });
      } else {
        Toast.error(context, 'Gagal memuat riwayat refund');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memuat riwayat refund');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<RefundDetail?> _detail(String id) async {
    try {
      final resp = await _api.detail(id);
      if (resp.statusCode == 200) {
        return RefundDetail.fromJson(jsonDecode(resp.body)['data']);
      }
    } catch (_) {}
    if (mounted) Toast.error(context, 'Gagal memuat detail');
    return null;
  }

  Future<void> _showDetail(String id) async {
    final d = await _detail(id);
    if (d == null || !mounted) return;
    final lang = context.read<LanguageProvider>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(d.header.refundNumber),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${lang.get('Sale', 'Nota')} ${d.header.saleNumber} · ${d.header.date} ${d.header.time}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              const SizedBox(height: 8),
              for (final l in d.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text(
                              '${l.qty} × ${l.stockName}${l.restock ? '' : ' (${lang.get('not restocked', 'tidak masuk stok')})'}')),
                      Text(TextFormatter.formatRupiah(l.amount)),
                    ],
                  ),
                ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total refund', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(TextFormatter.formatRupiah(d.header.total),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 6),
              Text('${d.header.method} · ${d.header.reason} · ${d.header.by}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.get('Close', 'Tutup'))),
        ],
      ),
    );
  }

  Future<void> _printPdf(RefundHeader r) async {
    setState(() => _printingId = r.refundId);
    try {
      final pdf = await _api.getReceiptPdf(r.refundId);
      if (pdf == null) {
        if (mounted) Toast.error(context, 'Struk tidak ditemukan');
        return;
      }
      await Printing.layoutPdf(onLayout: (format) async => pdf);
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal cetak struk');
    } finally {
      if (mounted) setState(() => _printingId = null);
    }
  }

  Future<void> _printThermal(RefundHeader r) async {
    setState(() => _printingId = r.refundId);
    try {
      final d = await _detail(r.refundId);
      if (d == null) return;
      final paper = await ThermalPrinter.paperWidthMm;
      final bytes = await RefundEscPos.build(d, paperWidthMm: paper);
      final err = await ThermalPrinter.printBytes(bytes);
      if (!mounted) return;
      err != null
          ? Toast.error(context, err)
          : Toast.success(context, 'Struk terkirim ke printer');
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal cetak struk thermal');
    } finally {
      if (mounted) setState(() => _printingId = null);
    }
  }

  Widget _help(LanguageProvider lang) {
    final steps = [
      lang.get('Open Sales History and find the sale to refund (it must be paid and not voided).',
          'Buka Sales History dan cari nota yang akan di-refund (harus sudah lunas dan belum dibatalkan).'),
      lang.get('Tap the Refund button (the round arrow icon) on that sale.',
          'Tekan tombol Refund (ikon panah melingkar) pada nota itu.'),
      lang.get(
          'Set the quantity of each item being returned. You can refund only some items or some quantities; the same sale can be refunded again until nothing is left.',
          'Atur jumlah tiap barang yang dikembalikan. Boleh sebagian barang atau sebagian jumlah; nota yang sama boleh di-refund lagi sampai tidak ada sisa.'),
      lang.get("Keep 'Return to stock' ticked for items that can be resold; untick it for damaged items.",
          "Biarkan 'Kembalikan ke stok' tercentang untuk barang yang bisa dijual lagi; hilangkan centang untuk barang rusak."),
      lang.get('Choose how the money is returned, write the reason, then press Process refund.',
          'Pilih cara uang dikembalikan, tulis alasannya, lalu tekan Proses refund.'),
      lang.get(
          'Print the refund receipt and give it to the customer together with the money. The amount already accounts for discounts and vouchers on the sale.',
          'Cetak struk refund dan berikan ke pelanggan bersama uangnya. Nilainya sudah memperhitungkan diskon dan voucher di nota.'),
    ];
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.help_outline_rounded, color: AppColors.blue),
        title: Text(lang.get('How to refund', 'Cara refund'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${i + 1}. ${steps[i]}', style: const TextStyle(fontSize: 13.5)),
            ),
          Text(
              lang.get(
                  "Refunds reduce the sales total in reports (on the day of the refund) and, for CASH refunds, the expected cash of the open cashier session. To cancel a whole sale use 'Void sale' instead.",
                  "Refund mengurangi omzet di laporan (pada hari refund dilakukan) dan, untuk refund TUNAI, kas yang diharapkan di sesi kasir yang terbuka. Untuk membatalkan seluruh nota pakai 'Batalkan nota'."),
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _card(LanguageProvider lang, RefundHeader r) {
    final printing = _printingId == r.refundId;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(r.refundNumber,
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                Text(TextFormatter.formatRupiah(r.total),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 2),
            Text('${lang.get('Sale', 'Nota')} ${r.saleNumber} · ${r.date} ${r.time} · ${r.by}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            Text(r.reason, style: const TextStyle(fontSize: 12.5)),
            Row(
              children: [
                Chip(label: Text(r.method), visualDensity: VisualDensity.compact),
                const Spacer(),
                IconButton(
                  tooltip: lang.get('Detail', 'Detail'),
                  icon: const Icon(Icons.info_outline_rounded, color: AppColors.blue),
                  onPressed: () => _showDetail(r.refundId),
                ),
                printing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.print_outlined, color: AppColors.ink),
                        tooltip: lang.get('Print receipt', 'Cetak struk'),
                        onSelected: (v) => v == 'pdf' ? _printPdf(r) : _printThermal(r),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'pdf', child: Text(lang.get('Print PDF', 'Cetak PDF'))),
                          PopupMenuItem(
                              value: 'thermal',
                              child: Text(lang.get('Print thermal (Bluetooth)', 'Cetak Thermal (Bluetooth)'))),
                        ],
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final pad = context.pagePadding;
    return PrivateRoute(
      staffMenuKey: '/riwayat-refund',
      child: Scaffold(
        appBar: AppBarCustom(title: lang.get('Refund History', 'Riwayat Refund')),
        drawer: const AppDrawer(),
        body: RefreshIndicator(
          onRefresh: () => _load(1, false),
          child: ListView(
            padding: EdgeInsets.all(pad),
            children: [
              _help(lang),
              const SizedBox(height: 10),
              SearchField(
                controller: _searchController,
                hintText: lang.get('Search refund or sale number', 'Cari nomor refund atau nomor nota'),
                onChanged: (v) {
                  _search = v;
                  _debouncer.run(() => _load(1, false));
                },
              ),
              const SizedBox(height: 12),
              if (_loading && _rows.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()))
              else if (_rows.isEmpty)
                EmptyState(
                    icon: Icons.replay_rounded,
                    title: lang.get('No refunds yet.', 'Belum ada refund.'))
              else ...[
                for (final r in _rows) _card(lang, r),
                if (_hasMore)
                  Center(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => _load(_page + 1, true),
                      child: Text(lang.get('Load more', 'Muat lagi')),
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
