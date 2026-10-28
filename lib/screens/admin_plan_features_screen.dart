import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/subscription_api.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

/// Layar ADMIN "Fitur per Paket" -- padanan pages/admin-plan-features/index.tsx di web. Aktif/nonaktifkan tiap fitur
/// per paket subscription. Toggle LANGSUNG menentukan apa yang backend izinkan (bukan sekadar tampilan); berlaku
/// maks 15 detik kemudian (cache entitlement) untuk SEMUA akun di paket itu.
class AdminPlanFeaturesScreen extends StatefulWidget {
  const AdminPlanFeaturesScreen({super.key});

  @override
  State<AdminPlanFeaturesScreen> createState() => _AdminPlanFeaturesScreenState();
}

class _AdminPlanFeaturesScreenState extends State<AdminPlanFeaturesScreen> {
  final _api = SubscriptionApi();
  bool _loading = true;
  bool _forbidden = false;
  List<Map<String, dynamic>> _plans = [];
  List<String> _keys = [];
  Map<String, String> _labels = {};
  final Map<String, Map<String, bool>> _matrix = {}; // planId -> featureKey -> enabled
  String _saving = ''; // "planId:featureKey" yang sedang disimpan

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.adminGetPlanFeatures();
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        _plans = ((body['plans'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
        _keys = ((body['feature_keys'] ?? []) as List).map((e) => '$e').toList();
        _labels = ((body['feature_labels'] ?? {}) as Map).map((k, v) => MapEntry('$k', '$v'));
        _matrix.clear();
        ((body['data'] ?? {}) as Map).forEach((plan, feats) {
          _matrix['$plan'] = ((feats ?? {}) as Map).map((k, v) => MapEntry('$k', v == true));
        });
        _forbidden = false;
      } else if (r.statusCode == 403) {
        _forbidden = true;
      } else if (mounted) {
        Toast.error(context, 'Gagal memuat data');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memuat data');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(String planId, String key, bool next) async {
    final cell = '$planId:$key';
    setState(() {
      _saving = cell;
      (_matrix[planId] ??= {})[key] = next; // optimistic
    });
    try {
      final r = await _api.adminSetPlanFeature(planId, key, next);
      if (r.statusCode != 200) {
        if (mounted) Toast.error(context, 'Gagal menyimpan');
        setState(() => (_matrix[planId] ??= {})[key] = !next);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
      setState(() => (_matrix[planId] ??= {})[key] = !next);
    } finally {
      if (mounted) setState(() => _saving = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Fitur per Paket'),
        drawer: const AppDrawer(),
        body: _forbidden
            ? const Center(child: Text('Khusus admin'))
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                              'Centang = fitur aktif untuk paket itu. Perubahan langsung memblokir/membuka akses (maks 15 detik), bukan sekadar tampilan.',
                              style: TextStyle(fontSize: 12.5)),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 18,
                            columns: [
                              const DataColumn(
                                  label: Text('Fitur',
                                      style: TextStyle(fontWeight: FontWeight.w700))),
                              for (final p in _plans)
                                DataColumn(
                                    label: Text('${p['name'] ?? p['id']}',
                                        style: const TextStyle(fontWeight: FontWeight.w700))),
                            ],
                            rows: [
                              for (final k in _keys)
                                DataRow(cells: [
                                  DataCell(Text(_labels[k] ?? k)),
                                  for (final p in _plans)
                                    DataCell(Checkbox(
                                      value: _matrix['${p['id']}']?[k] ?? false,
                                      onChanged: _saving == '${p['id']}:$k'
                                          ? null
                                          : (v) => _toggle('${p['id']}', k, v ?? false),
                                    )),
                                ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
