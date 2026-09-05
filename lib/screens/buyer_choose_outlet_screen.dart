import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/order_model.dart';
import '../providers/buyer_order_provider.dart';
import '../services/order_api.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

/// Mode pembeli — layar pertama: pilih outlet penjual tujuan.
/// Menampilkan SEMUA outlet non-THERAPY yang terdaftar (lintas penjual),
/// lalu tekan "PILIH OUTLET INI" untuk mulai memesan barang.
class BuyerChooseOutletScreen extends StatefulWidget {
  const BuyerChooseOutletScreen({super.key});

  @override
  State<BuyerChooseOutletScreen> createState() =>
      _BuyerChooseOutletScreenState();
}

class _BuyerChooseOutletScreenState extends State<BuyerChooseOutletScreen> {
  final _orderApi = OrderApi();
  List<PublicOutlet> _outlets = [];
  PublicOutlet? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final response = await _orderApi.getOutlets('');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        _outlets = ((body['data'] ?? []) as List)
            .map((e) => PublicOutlet.fromJson(e))
            .toList();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);

    // pulihkan pilihan sebelumnya
    final saved = await Storage.get(AppConstants.buyerOutcodeKey) ?? '';
    final savedGold =
        int.tryParse(await Storage.get(AppConstants.buyerOutletGoldIdKey) ?? '') ??
            0;
    final match = _outlets
        .where((o) => o.outletCode == saved && o.outletGoldId == savedGold)
        .toList();
    if (match.isNotEmpty && mounted) {
      _selectOutlet(match.first, silent: true);
    }
  }

  Future<void> _selectOutlet(PublicOutlet outlet, {bool silent = false}) async {
    setState(() => _selected = outlet);
    final cart = Provider.of<BuyerOrderProvider>(context, listen: false);
    cart.selectOutlet(outlet.outletGoldId, outlet.outletCode, outlet.outletName);
    await Storage.set(AppConstants.buyerOutcodeKey, outlet.outletCode);
    await Storage.set(AppConstants.buyerOutletNameKey, outlet.outletName);
    await Storage.set(
        AppConstants.buyerOutletGoldIdKey, outlet.outletGoldId.toString());
    if (!silent && mounted) {
      Toast.success(context, 'Outlet ${outlet.outletName} dipilih');
    }
  }

  Widget _outletDetailCard(PublicOutlet o) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.store, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    o.outletName.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Penjual : ${o.ownerName.isEmpty ? "-" : o.ownerName}'),
            Text('Kode    : ${o.outletCode}'),
            Text('Tipe    : ${o.outletType}'),
            Text('Alamat  : ${o.outletAddress.isEmpty ? "-" : o.outletAddress}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<BuyerOrderProvider>(context);
    return PrivateRoute(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Pilih Outlet'),
          actions: [
            if (cart.itemCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                    child: Text('${cart.itemCount} item',
                        style: const TextStyle(fontSize: 13))),
              ),
          ],
        ),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _outlets.isEmpty
                ? Center(
                    child: Text('Belum ada outlet tersedia',
                        style: TextStyle(color: Colors.grey[600])))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: DropdownButtonFormField<String>(
                          value: _selected == null
                              ? null
                              : '${_selected!.outletGoldId}|${_selected!.outletCode}',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Pilih outlet penjual',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _outlets
                              .map((o) => DropdownMenuItem<String>(
                                    value: '${o.outletGoldId}|${o.outletCode}',
                                    child: Text(
                                      '${o.outletName.toUpperCase()} — ${o.ownerName}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (key) {
                            if (key == null) return;
                            final parts = key.split('|');
                            final gid = int.tryParse(parts[0]) ?? 0;
                            final code = parts.sublist(1).join('|');
                            _selectOutlet(_outlets.firstWhere((o) =>
                                o.outletGoldId == gid && o.outletCode == code));
                          },
                        ),
                      ),
                      if (_selected != null) ...[
                        _outletDetailCard(_selected!),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.shopping_bag),
                              label: const Text('PILIH OUTLET INI — MULAI PESAN'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pushReplacementNamed(
                                  context, '/belanja'),
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                    ],
                  ),
      ),
    );
  }
}
