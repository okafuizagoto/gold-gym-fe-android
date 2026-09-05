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

/// Tab laporan PER BULAN: pilih bulan → total penjualan per blok minggu
/// (1–7, 8–14, dst) + total keseluruhan bulan.
class LaporanBulananView extends StatefulWidget {
  const LaporanBulananView({super.key});

  @override
  State<LaporanBulananView> createState() => _LaporanBulananViewState();
}

class _LaporanBulananViewState extends State<LaporanBulananView>
    with AutomaticKeepAliveClientMixin {
  final _salesApi = SalesApi();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  MonthReport? _report;
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
      final monthStr = DateFormat('yyyy-MM').format(_month);
      final resp = await _salesApi.getSalesReport('month', monthStr, outcode);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _report = MonthReport.fromJson(body['data'] ?? {});
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

  Future<void> _pickMonth() async {
    // pakai date picker mode tahun→bulan; hari diabaikan (dipakai awal bulan)
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Pilih bulan',
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month, 1));
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
                  onTap: _pickMonth,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Bulan',
                      prefixIcon: Icon(Icons.calendar_month),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(_report?.label ??
                        DateFormat('MMMM yyyy', 'id_ID').format(_month)),
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
              : (_report == null || _report!.weeks.isEmpty)
                  ? Center(
                      child: Text('Tidak ada data',
                          style: TextStyle(color: Colors.grey[600])))
                  : _list(),
        ),
        if (!_loading && _report != null) _grandTotalBar(),
      ],
    );
  }

  Widget _list() {
    final weeks = _report!.weeks;
    return Column(
      children: [
        _headerRow(),
        Expanded(
          child: ListView.separated(
            itemCount: weeks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final w = weeks[i];
              return _dataRow(w);
            },
          ),
        ),
      ],
    );
  }

  Widget _headerRow() {
    const s = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
    return Container(
      color: AppTheme.primaryTeal.withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: const [
          Expanded(flex: 4, child: Text('Minggu (tgl)', style: s)),
          Expanded(
              flex: 2,
              child: Text('Nota', style: s, textAlign: TextAlign.center)),
          Expanded(
              flex: 4,
              child:
                  Text('Total Penjualan', style: s, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _dataRow(WeeklyTotal w) {
    final hasSale = w.total > 0;
    final style = TextStyle(
        fontSize: 13, color: hasSale ? Colors.black87 : Colors.grey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text('Minggu ${w.weekNo}  (${w.label})', style: style),
          ),
          Expanded(
              flex: 2,
              child:
                  Text('${w.count}', style: style, textAlign: TextAlign.center)),
          Expanded(
              flex: 4,
              child: Text(TextFormatter.formatRupiah(w.total),
                  style: style.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right)),
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
            const Text('Total Keseluruhan',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
