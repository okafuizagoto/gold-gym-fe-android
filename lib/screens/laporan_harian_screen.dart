import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/sales_report_model.dart';
import '../services/sales_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/empty_state.dart';

/// Tab laporan PER HARI: pilih tanggal → tabel item terjual.
/// Baris dengan customer sama ditampilkan tanpa garis pemisah di kolom customer
/// (efek sel tergabung). Kolom: Customer, Item, Qty, Total/Item, Sisa, Sales.
class LaporanHarianView extends StatefulWidget {
  const LaporanHarianView({super.key});

  @override
  State<LaporanHarianView> createState() => _LaporanHarianViewState();
}

class _LaporanHarianViewState extends State<LaporanHarianView>
    with AutomaticKeepAliveClientMixin {
  final _salesApi = SalesApi();
  DateTime _date = DateTime.now();
  DayReport? _report;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final outcode = await Storage.get(AppConstants.outcode) ?? '';
      final dateStr = DateFormat('yyyy-MM-dd').format(_date);
      final resp = await _salesApi.getSalesReport('day', dateStr, outcode);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _report = DayReport.fromJson(body['data'] ?? {});
      } else {
        String msg = 'Gagal memuat laporan';
        try {
          msg = jsonDecode(resp.body)['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _dateBar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (_report == null || _report!.items.isEmpty)
                  ? const SingleChildScrollView(
                      child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Tidak ada penjualan',
                      description:
                          'Belum ada transaksi di tanggal ini. Coba pilih tanggal lain.',
                      compact: true,
                    ))
                  : _table(),
        ),
        if (!_loading && _report != null && _report!.items.isNotEmpty)
          _grandTotalBar(),
      ],
    );
  }

  Widget _dateBar() {
    final pad = context.pagePadding;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 8, pad, 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                  isDense: true,
                ),
                child: Text(
                  DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat ulang',
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  // Lebar kolom minimum supaya rapi; tabel bisa digeser horizontal di HP,
  // dan di tablet kolom dilebarkan proporsional memenuhi layar.
  static const _minWidths = [120.0, 130.0, 46.0, 100.0, 56.0, 100.0];

  List<double> _colWidths(double available) {
    final sum = _minWidths.fold(0.0, (a, b) => a + b);
    final total = math.max(sum, available);
    final scale = total / sum;
    return _minWidths.map((w) => w * scale).toList();
  }

  Widget _table() {
    final items = _report!.items;
    final pad = context.pagePadding;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 4, pad, 8),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widths = _colWidths(constraints.maxWidth);
            final total = widths.fold(0.0, (a, b) => a + b);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: total,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerRow(widths),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final it = items[i];
                          // baris pertama dari grup customer (customer berubah dari atas)
                          final firstOfGroup =
                              i == 0 || items[i - 1].customer != it.customer;
                          return _bodyRow(
                              widths, it, firstOfGroup, i == items.length - 1);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _headerRow(List<double> w) {
    final s = Theme.of(context).textTheme.labelSmall;
    return Container(
      color: AppColors.tableHead,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          SizedBox(width: w[0], child: Text('CUSTOMER', style: s)),
          SizedBox(width: w[1], child: Text('ITEM', style: s)),
          SizedBox(
              width: w[2],
              child: Text('QTY', style: s, textAlign: TextAlign.center)),
          SizedBox(
              width: w[3],
              child: Text('TOTAL/ITEM', style: s, textAlign: TextAlign.right)),
          SizedBox(
              width: w[4],
              child: Text('SISA', style: s, textAlign: TextAlign.center)),
          SizedBox(width: w[5], child: Text('SALES', style: s)),
        ],
      ),
    );
  }

  Widget _bodyRow(
      List<double> w, ReportItem it, bool firstOfGroup, bool isLast) {
    const cell = TextStyle(fontSize: 12, color: AppColors.ink);
    return Container(
      decoration: BoxDecoration(
        // garis pemisah hanya di ATAS baris pertama tiap grup customer →
        // baris dengan customer sama tampak menyatu (tanpa garis di dalamnya)
        border: Border(
          top: firstOfGroup
              ? const BorderSide(color: AppColors.border)
              : BorderSide.none,
          bottom: isLast
              ? const BorderSide(color: AppColors.border)
              : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: w[0],
            // tampilkan nama customer hanya di baris pertama grup
            child: firstOfGroup
                ? Text(it.customer.isEmpty ? '-' : it.customer,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink))
                : const SizedBox.shrink(),
          ),
          SizedBox(width: w[1], child: Text(it.itemName, style: cell)),
          SizedBox(
              width: w[2],
              child:
                  Text('${it.qty}', style: cell, textAlign: TextAlign.center)),
          SizedBox(
              width: w[3],
              child: Text(TextFormatter.formatRupiah(it.subtotal),
                  style: cell, textAlign: TextAlign.right)),
          SizedBox(
              width: w[4],
              child: Text('${it.remaining}',
                  style: cell, textAlign: TextAlign.center)),
          SizedBox(
              width: w[5],
              child: Text(it.salesperson.isEmpty ? '-' : it.salesperson,
                  style: cell)),
        ],
      ),
    );
  }

  Widget _grandTotalBar() {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: context.pagePadding, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total Keseluruhan (${_report!.count} nota)',
                  style: textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                TextFormatter.formatRupiah(_report!.grandTotal),
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
