import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
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
import '../widgets/section_card.dart';

/// Tab laporan "Tren": rentang tanggal bebas (default 30 hari terakhir),
/// KPI ringkas (revenue/transaksi/AOV + persen perubahan vs periode
/// sebelumnya), grafik garis revenue harian, dan top 5 item terlaris.
class LaporanTrenView extends StatefulWidget {
  const LaporanTrenView({super.key});

  @override
  State<LaporanTrenView> createState() => _LaporanTrenViewState();
}

class _LaporanTrenViewState extends State<LaporanTrenView>
    with AutomaticKeepAliveClientMixin {
  final _salesApi = SalesApi();
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 29)),
    end: DateTime.now(),
  );
  SalesTrend? _trend;
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
      final from = DateFormat('yyyy-MM-dd').format(_range.start);
      final to = DateFormat('yyyy-MM-dd').format(_range.end);
      final resp = await _salesApi.getSalesTrend(outcode, from, to);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _trend = SalesTrend.fromJson(body['data'] ?? {});
      } else {
        String msg = 'Gagal memuat tren';
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

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _range = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pad = context.pagePadding;
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
              children: [
                _rangeBar(),
                const SizedBox(height: 12),
                // KOREKSI 2026-09-18 (QA audit #1.6): guard lama cuma cek
                // totalTransactions, bukan days.isEmpty -- kalau backend
                // pernah kirim totalTransactions!=0 tapi days kosong,
                // _chartCard()'s `(0/6).ceil().clamp(1,0)` melempar
                // ArgumentError (lower>upper) -> crash tab Tren.
                if (_trend == null ||
                    _trend!.totalTransactions == 0 ||
                    _trend!.days.isEmpty)
                  const EmptyState(
                    icon: Icons.show_chart_rounded,
                    title: 'Belum ada penjualan',
                    description:
                        'Tidak ada transaksi pada rentang tanggal ini.',
                    compact: true,
                  )
                else ...[
                  _kpiRow(),
                  const SizedBox(height: 16),
                  _chartCard(),
                  const SizedBox(height: 16),
                  _topItemsCard(),
                ],
              ],
            ),
          );
  }

  Widget _rangeBar() {
    final f = DateFormat('d MMM yyyy', 'id_ID');
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _pickRange,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Rentang tanggal',
                prefixIcon: Icon(Icons.date_range_rounded),
                isDense: true,
              ),
              child: Text(
                '${f.format(_range.start)} - ${f.format(_range.end)}',
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
    );
  }

  Widget _kpiRow() {
    final t = _trend!;
    final up = t.revenueChangePercent >= 0;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _kpiTile('Total Penjualan', TextFormatter.formatRupiah(t.totalRevenue)),
        _kpiTile('Total Transaksi', '${t.totalTransactions}'),
        _kpiTile('Rata-rata / Transaksi',
            TextFormatter.formatRupiah(t.averageOrderValue)),
        _kpiTile(
          'vs periode sebelumnya',
          '${up ? '+' : ''}${t.revenueChangePercent.toStringAsFixed(1)}%',
          valueColor: t.prevPeriodRevenue == 0
              ? AppColors.muted
              : (up ? AppColors.successDark : AppColors.error),
          icon: t.prevPeriodRevenue == 0
              ? null
              : (up ? Icons.trending_up_rounded : Icons.trending_down_rounded),
        ),
      ],
    );
  }

  Widget _kpiTile(String label, String value, {Color? valueColor, IconData? icon}) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 6),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: valueColor),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartCard() {
    final days = _trend!.days;
    final maxY = days.fold<double>(
        0, (m, d) => d.total > m ? d.total : m);
    final safeMaxY = maxY <= 0 ? 1.0 : maxY * 1.2;
    // label sumbu-X: hemat, cuma tampilkan beberapa tanggal supaya tidak
    // saling tumpuk saat rentang panjang (mis. 30/90/366 hari).
    final labelEvery = (days.length / 6).ceil().clamp(1, days.length);
    return SectionCard(
      title: 'Tren Penjualan Harian',
      icon: Icons.show_chart_rounded,
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: safeMaxY,
            gridData: const FlGridData(drawVerticalLine: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: labelEvery.toDouble(),
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= days.length) return const SizedBox.shrink();
                    if (i % labelEvery != 0) return const SizedBox.shrink();
                    final d = DateTime.tryParse(days[i].date);
                    final label = d == null ? '' : DateFormat('d/M').format(d);
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(label, style: const TextStyle(fontSize: 10)),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((s) {
                  final i = s.x.toInt();
                  final date = i >= 0 && i < days.length ? days[i].date : '';
                  return LineTooltipItem(
                    '$date\n${TextFormatter.formatRupiah(s.y)}',
                    const TextStyle(color: Colors.white, fontSize: 11),
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < days.length; i++)
                    FlSpot(i.toDouble(), days[i].total),
                ],
                isCurved: true,
                color: AppColors.blue,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.blue.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topItemsCard() {
    final items = _trend!.topItems;
    return SectionCard(
      title: 'Top 5 Item Terlaris',
      icon: Icons.local_fire_department_rounded,
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Belum ada item terjual pada rentang ini.'),
            )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.blueLight,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.blue)),
                    ),
                    title: Text(items[i].itemName),
                    subtitle: Text('${items[i].qty} terjual'),
                    trailing: Text(
                      TextFormatter.formatRupiah(items[i].revenue),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
    );
  }
}
