import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/subscription_api.dart';
import '../utils/subscription_state.dart' show formatRupiah;
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

class _PlanPricingRow {
  final String planId;
  final String name;
  final int basePriceMonthly;
  final int basePriceYearly;
  int? priceMonthlyOverride;
  int? priceYearlyOverride;
  double discountPercent;

  _PlanPricingRow({
    required this.planId,
    required this.name,
    required this.basePriceMonthly,
    required this.basePriceYearly,
    this.priceMonthlyOverride,
    this.priceYearlyOverride,
    this.discountPercent = 0,
  });

  int get effectiveMonthly => priceMonthlyOverride ?? basePriceMonthly;
  int get effectiveYearly => priceYearlyOverride ?? basePriceYearly;
  int get finalMonthly =>
      (effectiveMonthly - effectiveMonthly * discountPercent / 100).round();
  int get finalYearly =>
      (effectiveYearly - effectiveYearly * discountPercent / 100).round();
}

/// Layar ADMIN (2026-10-10): ubah harga dasar & beri diskon per paket subscription. Harga final
/// (setelah diskon) inilah yang tampil ke penjual/pembeli di menu Langganan.
class AdminPlanPricingScreen extends StatefulWidget {
  const AdminPlanPricingScreen({super.key});

  @override
  State<AdminPlanPricingScreen> createState() => _AdminPlanPricingScreenState();
}

class _AdminPlanPricingScreenState extends State<AdminPlanPricingScreen> {
  final _api = SubscriptionApi();
  bool _loading = true;
  bool _forbidden = false;
  List<_PlanPricingRow> _rows = [];
  String _busyPlanId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await _api.adminGetPlanPricing();
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final base = ((body['base'] ?? []) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final overrides = ((body['data'] ?? []) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final overrideByPlan = {for (final o in overrides) o['plan_id']: o};
        _rows = base.map((b) {
          final o = overrideByPlan[b['id']];
          return _PlanPricingRow(
            planId: b['id'],
            name: b['name'] ?? b['id'],
            basePriceMonthly: (b['price_monthly'] as num?)?.toInt() ?? 0,
            basePriceYearly: (b['price_yearly'] as num?)?.toInt() ?? 0,
            priceMonthlyOverride:
                (o?['price_monthly_override'] as num?)?.toInt(),
            priceYearlyOverride: (o?['price_yearly_override'] as num?)?.toInt(),
            discountPercent: (o?['discount_percent'] as num?)?.toDouble() ?? 0,
          );
        }).toList();
        _forbidden = false;
      } else if (resp.statusCode == 403) {
        _forbidden = true;
      } else if (mounted) {
        Toast.error(context, 'Gagal memuat data');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memuat data');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save(_PlanPricingRow r) async {
    setState(() => _busyPlanId = r.planId);
    try {
      final resp = await _api.adminSetPlanPricing(
        planId: r.planId,
        priceMonthlyOverride: r.priceMonthlyOverride,
        priceYearlyOverride: r.priceYearlyOverride,
        discountPercent: r.discountPercent,
      );
      if (resp.statusCode == 200) {
        if (mounted) Toast.success(context, 'Harga ${r.name} tersimpan');
      } else {
        String msg = 'Gagal menyimpan';
        try {
          msg = jsonDecode(resp.body)['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _busyPlanId = '');
    }
  }

  Future<void> _editRow(_PlanPricingRow r) async {
    final monthlyCtl = TextEditingController(
        text: (r.priceMonthlyOverride ?? r.basePriceMonthly).toString());
    final yearlyCtl = TextEditingController(
        text: (r.priceYearlyOverride ?? r.basePriceYearly).toString());
    final discountCtl =
        TextEditingController(text: r.discountPercent.toStringAsFixed(0));
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Harga paket ${r.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: monthlyCtl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText:
                      'Harga/bulan (default: ${formatRupiah(r.basePriceMonthly)})'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: yearlyCtl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText:
                      'Harga/tahun (default: ${formatRupiah(r.basePriceYearly)})'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: discountCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Diskon (%)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (result != true) return;
    final monthly = int.tryParse(monthlyCtl.text.trim());
    final yearly = int.tryParse(yearlyCtl.text.trim());
    final discount = double.tryParse(discountCtl.text.trim()) ?? 0;
    if (discount < 0 || discount > 100) {
      if (mounted) Toast.error(context, 'Diskon harus antara 0-100%');
      return;
    }
    setState(() {
      r.priceMonthlyOverride = monthly == r.basePriceMonthly ? null : monthly;
      r.priceYearlyOverride = yearly == r.basePriceYearly ? null : yearly;
      r.discountPercent = discount;
    });
    await _save(r);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PrivateRoute(
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Harga & Diskon Paket'),
        drawer: const AppDrawer(),
        body: _forbidden
            ? const Center(child: Text('Khusus admin'))
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Harga final (setelah diskon) langsung tampil di menu Langganan penjual & pembeli.',
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        ..._rows.map((r) => SectionCard(
                              title: r.name,
                              icon: Icons.sell_outlined,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Bulan: ${formatRupiah(r.finalMonthly)}'
                                      '${r.discountPercent > 0 ? ' (dari ${formatRupiah(r.effectiveMonthly)}, -${r.discountPercent.toStringAsFixed(0)}%)' : ''}'),
                                  Text('Tahun: ${formatRupiah(r.finalYearly)}'
                                      '${r.discountPercent > 0 ? ' (dari ${formatRupiah(r.effectiveYearly)}, -${r.discountPercent.toStringAsFixed(0)}%)' : ''}'),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      icon: _busyPlanId == r.planId
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2))
                                          : const Icon(Icons.edit_outlined,
                                              size: 18),
                                      onPressed: _busyPlanId == r.planId
                                          ? null
                                          : () => _editRow(r),
                                      label: const Text('Ubah'),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
      ),
    );
  }
}
