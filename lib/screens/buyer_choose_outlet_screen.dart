import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/order_model.dart';
import '../providers/buyer_order_provider.dart';
import '../services/order_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/info_row.dart';
import '../widgets/page_header.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

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
    final savedGold = int.tryParse(
            await Storage.get(AppConstants.buyerOutletGoldIdKey) ?? '') ??
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
    cart.selectOutlet(
        outlet.outletGoldId, outlet.outletCode, outlet.outletName);
    await Storage.set(AppConstants.buyerOutcodeKey, outlet.outletCode);
    await Storage.set(AppConstants.buyerOutletNameKey, outlet.outletName);
    await Storage.set(
        AppConstants.buyerOutletGoldIdKey, outlet.outletGoldId.toString());
    if (!silent && mounted) {
      Toast.success(context, 'Outlet ${outlet.outletName} dipilih');
    }
  }

  String _keyOf(PublicOutlet o) => '${o.outletGoldId}|${o.outletCode}';

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<BuyerOrderProvider>(context);
    final selectedKey = _selected == null ? null : _keyOf(_selected!);
    return PrivateRoute(
      child: Scaffold(
        appBar: AppBarCustom(
          title: 'Pilih Outlet',
          actions: [
            if (cart.itemCount > 0)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '${cart.itemCount} item',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.tealDark),
                  ),
                ),
              ),
          ],
        ),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _outlets.isEmpty
                ? const PageBody(
                    child: EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Belum ada outlet tersedia',
                    description:
                        'Outlet penjual yang sudah diaktifkan admin akan tampil di sini.',
                  ))
                : PageBody(
                    maxWidth: 720,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const PageHeader(
                          title: 'Pilih Outlet Penjual',
                          subtitle:
                              'Barang yang bisa dipesan mengikuti outlet yang dipilih',
                          icon: Icons.store_mall_directory_rounded,
                        ),
                        SectionCard(
                          title: 'Outlet tujuan',
                          icon: Icons.search_rounded,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(selectedKey),
                            initialValue: selectedKey,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Pilih outlet penjual',
                              prefixIcon: Icon(Icons.storefront_outlined),
                            ),
                            items: _outlets
                                .map((o) => DropdownMenuItem<String>(
                                      value: _keyOf(o),
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
                                  o.outletGoldId == gid &&
                                  o.outletCode == code));
                            },
                          ),
                        ),
                        if (_selected != null) ...[
                          const SizedBox(height: 12),
                          SectionCard(
                            title: _selected!.outletName.toUpperCase(),
                            description: 'Detail outlet terpilih',
                            icon: Icons.storefront_rounded,
                            child: Column(
                              children: [
                                InfoRow(
                                  label: 'Penjual',
                                  value: _selected!.ownerName.isEmpty
                                      ? '-'
                                      : _selected!.ownerName,
                                ),
                                InfoRow(
                                    label: 'Kode',
                                    value: _selected!.outletCode),
                                InfoRow(
                                    label: 'Tipe',
                                    value: _selected!.outletType),
                                InfoRow(
                                  label: 'Alamat',
                                  value: _selected!.outletAddress.isEmpty
                                      ? '-'
                                      : _selected!.outletAddress,
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 48,
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 20),
                                    label: const Text('PILIH OUTLET INI'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.successDark,
                                    ),
                                    onPressed: () =>
                                        Navigator.pushReplacementNamed(
                                            context, '/belanja'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}
