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

/// Tab laporan PER MINGGU: pilih tanggal → sistem menentukan blok minggu
/// (1–7, 8–14, dst) yang memuat tanggal itu, lalu menampilkan total penjualan
/// per hari dalam minggu tsb + total keseluruhan.
class LaporanMingguanView extends StatefulWidget {
  const LaporanMingguanView({super.key});

  @override
  State<LaporanMingguanView> createState() => _LaporanMingguanViewState();
}

class _LaporanMingguanViewState extends State<LaporanMingguanView>
    with AutomaticKeepAliveClientMixin {
  final _salesApi = SalesApi();
  DateTime _date = DateTime.now();
  WeekReport? _report;
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
      final resp = await _salesApi.getSalesReport('week', dateStr, outcode);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _report = WeekReport.fromJson(body['data'] ?? {});
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
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Pilih tanggal (menentukan minggu)',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(_report == null
                        ? DateFormat('d MMMM yyyy', 'id_ID').format(_date)
                        : 'Minggu ${_report!.label}'),
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
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (_report == null || _report!.days.isEmpty)
                  ? Center(
                      child: Text('Tidak ada data',
                          style: TextStyle(color: Colors.grey[600])))
                  : _list(),
        ),
        if (!_loading && _report != null)
          _grandTotalBar(_report!.grandTotal, 'Total Minggu Ini'),
      ],
    );
  }

  Widget _list() {
    final days = _report!.days;
    return Column(
      children: [
        _headerRow('Tanggal', 'Nota', 'Total Penjualan'),
        Expanded(
          child: ListView.separated(
            itemCount: days.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = days[i];
              final dt = DateTime.tryParse(d.date);
              final label = dt == null
                  ? d.date
                  : DateFormat('EEE, d MMM', 'id_ID').format(dt);
              return _dataRow(label, '${d.count}',
                  TextFormatter.formatRupiah(d.total), d.total > 0);
            },
          ),
        ),
      ],
    );
  }

  Widget _headerRow(String a, String b, String c) {
    const s = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
    return Container(
      color: AppTheme.primaryTeal.withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(a, style: s)),
          Expanded(
              flex: 2,
              child: Text(b, style: s, textAlign: TextAlign.center)),
          Expanded(
              flex: 4,
              child: Text(c, style: s, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _dataRow(String a, String b, String c, bool hasSale) {
    final style = TextStyle(
        fontSize: 13, color: hasSale ? Colors.black87 : Colors.grey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(a, style: style)),
          Expanded(
              flex: 2,
              child: Text(b, style: style, textAlign: TextAlign.center)),
          Expanded(
              flex: 4,
              child: Text(c,
                  style: style.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _grandTotalBar(double total, String label) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        color: AppTheme.primaryTeal.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(TextFormatter.formatRupiah(total),
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
