import 'dart:convert';
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
    final pad = context.pagePadding;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Pilih tanggal (menentukan minggu)',
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                      isDense: true,
                    ),
                    child: Text(
                      _report == null
                          ? DateFormat('d MMMM yyyy', 'id_ID').format(_date)
                          : 'Minggu ${_report!.label}',
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
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (_report == null || _report!.days.isEmpty)
                  ? const SingleChildScrollView(
                      child: EmptyState(
                      icon: Icons.date_range_outlined,
                      title: 'Tidak ada data',
                      description:
                          'Belum ada penjualan di minggu ini. Coba pilih tanggal lain.',
                      compact: true,
                    ))
                  : _list(),
        ),
        if (!_loading && _report != null)
          _grandTotalBar(_report!.grandTotal, 'Total Minggu Ini'),
      ],
    );
  }

  Widget _list() {
    final days = _report!.days;
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
        child: Column(
          children: [
            _headerRow('TANGGAL', 'NOTA', 'TOTAL PENJUALAN'),
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
        ),
      ),
    );
  }

  Widget _headerRow(String a, String b, String c) {
    final s = Theme.of(context).textTheme.labelSmall;
    return Container(
      color: AppColors.tableHead,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(a, style: s)),
          Expanded(
              flex: 2, child: Text(b, style: s, textAlign: TextAlign.center)),
          Expanded(
              flex: 4, child: Text(c, style: s, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _dataRow(String a, String b, String c, bool hasSale) {
    final style = TextStyle(
        fontSize: 13, color: hasSale ? AppColors.ink : AppColors.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Row(
        children: [
          Expanded(
              flex: 4,
              child: Text(a,
                  style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(
              flex: 2,
              child: Text(b, style: style, textAlign: TextAlign.center)),
          Expanded(
              flex: 4,
              child: Text(c,
                  style: style.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _grandTotalBar(double total, String label) {
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
                child: Text(label,
                    style: textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              Text(
                TextFormatter.formatRupiah(total),
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
