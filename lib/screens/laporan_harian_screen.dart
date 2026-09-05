import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/sales_report_model.dart';
import '../services/sales_api.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';

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
                  ? Center(
                      child: Text('Tidak ada penjualan di tanggal ini',
                          style: TextStyle(color: Colors.grey[600])))
                  : _table(),
        ),
        if (!_loading && _report != null && _report!.items.isNotEmpty)
          _grandTotalBar(),
      ],
    );
  }

  Widget _dateBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: Text(
                    DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_date)),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  // Lebar kolom tetap supaya rapi; tabel bisa digeser horizontal di HP.
  static const _wCust = 120.0;
  static const _wItem = 130.0;
  static const _wQty = 46.0;
  static const _wTotal = 100.0;
  static const _wSisa = 56.0;
  static const _wSales = 100.0;

  Widget _table() {
    final items = _report!.items;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _wCust + _wItem + _wQty + _wTotal + _wSisa + _wSales,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerRow(),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final it = items[i];
                  // baris pertama dari grup customer (customer berubah dari atas)
                  final firstOfGroup =
                      i == 0 || items[i - 1].customer != it.customer;
                  return _bodyRow(it, firstOfGroup, i == items.length - 1);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerRow() {
    TextStyle s = const TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
    return Container(
      color: AppTheme.primaryTeal.withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          SizedBox(width: _wCust, child: Text('Customer', style: s)),
          SizedBox(width: _wItem, child: Text('Item', style: s)),
          SizedBox(
              width: _wQty,
              child: Text('Qty', style: s, textAlign: TextAlign.center)),
          SizedBox(
              width: _wTotal,
              child: Text('Total/Item', style: s, textAlign: TextAlign.right)),
          SizedBox(
              width: _wSisa,
              child: Text('Sisa', style: s, textAlign: TextAlign.center)),
          SizedBox(width: _wSales, child: Text('Sales', style: s)),
        ],
      ),
    );
  }

  Widget _bodyRow(ReportItem it, bool firstOfGroup, bool isLast) {
    const cell = TextStyle(fontSize: 12);
    return Container(
      decoration: BoxDecoration(
        // garis pemisah hanya di ATAS baris pertama tiap grup customer →
        // baris dengan customer sama tampak menyatu (tanpa garis di dalamnya)
        border: Border(
          top: firstOfGroup
              ? BorderSide(color: Colors.grey.shade400)
              : BorderSide.none,
          bottom: isLast
              ? BorderSide(color: Colors.grey.shade400)
              : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _wCust,
            // tampilkan nama customer hanya di baris pertama grup
            child: firstOfGroup
                ? Text(it.customer.isEmpty ? '-' : it.customer,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600))
                : const SizedBox.shrink(),
          ),
          SizedBox(width: _wItem, child: Text(it.itemName, style: cell)),
          SizedBox(
              width: _wQty,
              child: Text('${it.qty}',
                  style: cell, textAlign: TextAlign.center)),
          SizedBox(
              width: _wTotal,
              child: Text(TextFormatter.formatRupiah(it.subtotal),
                  style: cell, textAlign: TextAlign.right)),
          SizedBox(
              width: _wSisa,
              child: Text('${it.remaining}',
                  style: cell, textAlign: TextAlign.center)),
          SizedBox(
              width: _wSales,
              child: Text(it.salesperson.isEmpty ? '-' : it.salesperson,
                  style: cell)),
        ],
      ),
    );
  }

  Widget _grandTotalBar() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        color: AppTheme.primaryTeal.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total Keseluruhan (${_report!.count} nota)',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(TextFormatter.formatRupiah(_report!.grandTotal),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryBlue)),
          ],
        ),
      ),
    );
  }
}
