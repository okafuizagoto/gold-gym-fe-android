import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/outlet_model.dart';
import '../models/stock_model.dart';
import '../services/outlet_api.dart';
import '../services/stock_api.dart';
import '../services/stock_transfer_api.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import 'stock_transfer_detail_screen.dart';

/// Buat transfer (status DIBUAT, stok belum berubah). Padanan pages/transfer-stok/baru.
class StockTransferCreateScreen extends StatefulWidget {
  const StockTransferCreateScreen({super.key});

  @override
  State<StockTransferCreateScreen> createState() =>
      _StockTransferCreateScreenState();
}

class _StockTransferCreateScreenState extends State<StockTransferCreateScreen> {
  final _api = StockTransferApi();
  final _noteC = TextEditingController();
  final _searchC = TextEditingController();
  final Map<String, TextEditingController> _qtyC = {};

  List<OutletResponse> _outlets = [];
  String _from = '';
  String _to = '';
  List<StockResponse> _stocks = [];
  bool _booting = true;
  bool _loadingStock = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _noteC.dispose();
    _searchC.dispose();
    for (final c in _qtyC.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    _from = await Storage.get(AppConstants.outcode) ?? '';
    try {
      final resp = await OutletsApi().getAllOutlet('', '', 1, 200);
      if (resp.statusCode == 200) {
        _outlets = OutletPagination.fromJson(jsonDecode(resp.body))
            .data
            .where((o) =>
                !o.locked &&
                !o.deleted &&
                o.outlet_type != AppConstants.outletTherapy)
            .toList();
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memuat outlet');
    }
    if (mounted) setState(() => _booting = false);
    await _loadStock();
  }

  Future<void> _loadStock() async {
    if (_from.isEmpty) return;
    setState(() => _loadingStock = true);
    for (final c in _qtyC.values) {
      c.clear();
    }
    try {
      final resp = await StockApi().getAllStock('', _from, 1, 1000);
      _stocks = resp.statusCode == 200
          ? StockPagination.fromJson(jsonDecode(resp.body))
              .data
              .where((s) => !s.isTherapy && s.stock_qty > 0)
              .toList()
          : [];
    } catch (_) {
      _stocks = [];
      if (mounted) Toast.error(context, 'Gagal memuat stok outlet asal');
    }
    if (mounted) setState(() => _loadingStock = false);
  }

  TextEditingController _c(String id) =>
      _qtyC.putIfAbsent(id, () => TextEditingController());

  List<({StockResponse s, int n})> get _chosen => [
        for (final s in _stocks)
          if ((int.tryParse(_c(s.stock_id).text.trim()) ?? 0) > 0)
            (s: s, n: int.parse(_c(s.stock_id).text.trim())),
      ];

  Future<void> _submit() async {
    if (_from.isEmpty || _to.isEmpty) {
      Toast.error(context, 'Pilih outlet asal dan tujuan');
      return;
    }
    if (_from == _to) {
      Toast.error(context, 'Outlet asal dan tujuan tidak boleh sama');
      return;
    }
    final chosen = _chosen;
    if (chosen.isEmpty) {
      Toast.error(context, 'Isi jumlah minimal satu barang');
      return;
    }
    for (final x in chosen) {
      if (x.n > x.s.stock_qty) {
        Toast.error(context,
            'Jumlah ${x.s.stock_name} melebihi stok (${x.s.stock_qty})');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final resp = await _api.create(
        fromOutcode: _from,
        toOutcode: _to,
        note: _noteC.text.trim(),
        items: [for (final x in chosen) (stockId: x.s.stock_id, qty: x.n)],
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        final id = jsonDecode(resp.body)['data']?['id'];
        if (!mounted) return;
        Toast.success(context,
            'Transfer dibuat. Kirim dari halaman detail agar stok berpindah.');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => StockTransferDetailScreen(transferId: id as int)),
        );
      } else {
        String msg = 'Gagal membuat transfer';
        try {
          msg = jsonDecode(resp.body)['error']?.toString() ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal membuat transfer');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchC.text.toLowerCase();
    final shown =
        _stocks.where((s) => s.stock_name.toLowerCase().contains(q)).toList();
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Buat Transfer Stok'),
        body: _booting
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    value: _outlets.any((o) => o.outlet_code == _from) ? _from : null,
                    decoration: const InputDecoration(labelText: 'Dari outlet'),
                    items: [
                      for (final o in _outlets)
                        DropdownMenuItem(
                            value: o.outlet_code,
                            child: Text(o.outlet_name.isEmpty
                                ? o.outlet_code
                                : o.outlet_name)),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _from = v ?? '';
                        if (_to == _from) _to = '';
                      });
                      _loadStock();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _outlets.any((o) => o.outlet_code == _to) ? _to : null,
                    decoration: const InputDecoration(labelText: 'Ke outlet'),
                    items: [
                      for (final o in _outlets.where((o) => o.outlet_code != _from))
                        DropdownMenuItem(
                            value: o.outlet_code,
                            child: Text(o.outlet_name.isEmpty
                                ? o.outlet_code
                                : o.outlet_name)),
                    ],
                    onChanged: (v) => setState(() => _to = v ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteC,
                    maxLength: 255,
                    decoration:
                        const InputDecoration(labelText: 'Catatan (opsional)'),
                  ),
                  const SizedBox(height: 8),
                  const Text('Barang',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchC,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        hintText: 'Cari barang…', prefixIcon: Icon(Icons.search)),
                  ),
                  const SizedBox(height: 8),
                  if (_loadingStock)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()))
                  else if (shown.isEmpty)
                    const EmptyState(
                        compact: true,
                        title: 'Tidak ada stok yang bisa ditransfer')
                  else
                    for (final s in shown)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.stock_name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text('Stok ${s.stock_qty} ${s.stock_pack}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 96,
                              child: TextField(
                                controller: _c(s.stock_id),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration:
                                    const InputDecoration(labelText: 'Jumlah'),
                              ),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: Text(_saving
                        ? 'Menyimpan…'
                        : 'Buat Transfer (${_chosen.length} barang)'),
                  ),
                ],
              ),
      ),
    );
  }
}
