import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/sales_api.dart';
import '../utils/responsive.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import '../widgets/search_field.dart';
import '../widgets/segmented_tabs.dart';

class _PosOutlet {
  final int goldId;
  final String code;
  final String name;
  final String address;
  final String owner;
  final bool optional;
  _PosOutlet(this.goldId, this.code, this.name, this.address, this.owner,
      this.optional);
  String get key => '$goldId|$code';
  factory _PosOutlet.fromJson(Map<String, dynamic> j) => _PosOutlet(
        j['outlet_gold_id'] is int
            ? j['outlet_gold_id']
            : int.tryParse('${j['outlet_gold_id']}') ?? 0,
        j['outlet_code'] ?? '',
        j['outlet_name'] ?? '',
        j['outlet_address'] ?? '',
        j['owner_name'] ?? '',
        j['optional'] == true || j['optional'] == 1 || j['optional'] == '1',
      );
}

/// Layar ADMIN: memberi akses penjual RETAIL agar POS-nya boleh transaksi
/// TANPA mengisi nama customer. Cari alamat/nama → outlet cocok auto-tercentang
/// → bisa uncheck → tombol Simpan (hanya berlaku untuk yang sedang tampil).
class AdminPosCustomerScreen extends StatefulWidget {
  const AdminPosCustomerScreen({super.key});

  @override
  State<AdminPosCustomerScreen> createState() => _AdminPosCustomerScreenState();
}

class _AdminPosCustomerScreenState extends State<AdminPosCustomerScreen> {
  final _salesApi = SalesApi();
  final _searchController = TextEditingController();
  List<_PosOutlet> _outlets = [];
  final Map<String, bool> _checked = {};
  bool _loading = true;
  bool _saving = false;
  Timer? _debounce;
  String _currentSearch = '';
  // mode tampilan: false = daftar per outlet, true = dikelompokkan per penjual
  bool _bySeller = false;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load(String search) async {
    setState(() => _loading = true);
    _currentSearch = search;
    try {
      final resp = await _salesApi.getPosOutletsAdmin(search);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _outlets = ((body['data'] ?? []) as List)
            .map((e) => _PosOutlet.fromJson(e))
            .toList();
        _checked.clear();
        for (final o in _outlets) {
          // selalu tampilkan status tersimpan (optional='Y' => tercentang).
          // Default outlet baru = boleh tanpa customer (tercentang); admin
          // menghilangkan centang untuk outlet yang WAJIB mengisi customer.
          _checked[o.key] = o.optional;
        }
      } else {
        String msg = 'Gagal memuat outlet';
        try {
          msg = jsonDecode(resp.body)['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_outlets.isEmpty) return;
    setState(() => _saving = true);
    try {
      final items = _outlets
          .map((o) => {
                "gold_id": o.goldId,
                "outcode": o.code,
                "optional": _checked[o.key] ?? false,
              })
          .toList();
      final resp = await _salesApi.savePosCustomerAccess(items);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (mounted) Toast.success(context, 'Akses POS tersimpan');
        await _load(_currentSearch);
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
      if (mounted) setState(() => _saving = false);
    }
  }

  // Kelompokkan outlet per penjual (kunci = gold_id pemilik outlet).
  Map<int, List<_PosOutlet>> _groupBySeller() {
    final map = <int, List<_PosOutlet>>{};
    for (final o in _outlets) {
      map.putIfAbsent(o.goldId, () => []).add(o);
    }
    return map;
  }

  // Centang/hapus centang SEMUA outlet milik satu penjual sekaligus (perubahan
  // baru tersimpan setelah tombol SIMPAN ditekan, sama seperti mode per outlet).
  void _setSeller(List<_PosOutlet> outlets, bool value) {
    setState(() {
      for (final o in outlets) {
        _checked[o.key] = value;
      }
    });
  }

  // Satu baris checkbox untuk satu outlet (dipakai di kedua mode tampilan).
  Widget _outletCheckTile(_PosOutlet o) {
    return CheckboxListTile(
      value: _checked[o.key] ?? false,
      onChanged: (v) => setState(() => _checked[o.key] = v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(o.name.toUpperCase(),
          maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${o.owner.isEmpty ? "-" : o.owner} • ${o.address.isEmpty ? "-" : o.address}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // Daftar dikelompokkan per penjual: master checkbox "centang semua" +
  // daftar outlet miliknya (bisa diatur satuan saat di-expand).
  Widget _buildSellerList(EdgeInsets padding) {
    final groups = _groupBySeller();
    final sellerIds = groups.keys.toList();
    return ListView.builder(
      padding: padding,
      itemCount: sellerIds.length,
      itemBuilder: (context, index) {
        final goldId = sellerIds[index];
        final outlets = groups[goldId]!;
        final ownerName = outlets.first.owner.isEmpty
            ? 'Penjual #$goldId'
            : outlets.first.owner;
        final checkedCount =
            outlets.where((o) => _checked[o.key] ?? false).length;
        final allChecked = checkedCount == outlets.length;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: const Icon(Icons.person_outline_rounded,
                color: AppColors.tealDark),
            title: Text(ownerName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                '${outlets.length} outlet • dicentang $checkedCount/${outlets.length}'),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              CheckboxListTile(
                title: const Text('Centang semua outlet penjual ini'),
                secondary: const Icon(Icons.done_all_rounded,
                    color: AppColors.tealDark),
                value: allChecked,
                onChanged: (v) => _setSeller(outlets, v ?? false),
              ),
              const Divider(height: 1),
              ...outlets.map(_outletCheckTile),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pad = context.pagePadding;
    final listPadding = EdgeInsets.fromLTRB(pad, 4, pad, pad);
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'POS Tanpa Customer'),
        drawer: const AppDrawer(),
        body: SafeArea(
          top: false,
          child: ContentWidth(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 12, pad, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SearchField(
                        controller: _searchController,
                        hintText: 'Cari nama / alamat outlet (mis. "pasar")',
                        onChanged: (v) {
                          _debounce?.cancel();
                          _debounce = Timer(const Duration(milliseconds: 450),
                              () => _load(v));
                        },
                      ),
                      if (!context.isShort) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Default: semua outlet BOLEH transaksi tanpa customer '
                          '(tercentang). Hilangkan centang outlet yang WAJIB mengisi '
                          'customer. Simpan hanya berlaku untuk outlet yang tampil.',
                          style: textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 10),
                      // pemilih mode: per outlet, atau per penjual (centang satu
                      // penjual = semua outlet miliknya ikut tercentang)
                      SegmentedTabs<bool>(
                        value: _bySeller,
                        onChanged: (v) => setState(() => _bySeller = v),
                        tabs: const [
                          SegmentedTab(
                              value: false,
                              label: 'Per Outlet',
                              icon: Icons.storefront_outlined),
                          SegmentedTab(
                              value: true,
                              label: 'Per Penjual',
                              icon: Icons.person_outline_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _outlets.isEmpty
                          ? EmptyState(
                              icon: Icons.storefront_outlined,
                              title: 'Tidak ada outlet',
                              compact: context.isShort,
                            )
                          : _bySeller
                              ? _buildSellerList(listPadding)
                              : ListView.builder(
                                  padding: listPadding,
                                  itemCount: _outlets.length,
                                  itemBuilder: (context, i) {
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: _outletCheckTile(_outlets[i]),
                                    );
                                  },
                                ),
                ),
                if (_outlets.isNotEmpty)
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: pad, vertical: 10),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_outlined, size: 20),
                        label: Text(_saving ? 'Menyimpan...' : 'SIMPAN'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successDark,
                        ),
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
