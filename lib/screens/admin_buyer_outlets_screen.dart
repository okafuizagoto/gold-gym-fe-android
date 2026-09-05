import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/order_model.dart';
import '../services/order_api.dart';
import '../utils/toast.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

/// Layar ADMIN: mengatur outlet penjual mana yang boleh dilihat & dipesan
/// oleh role pembeli. Pembeli hanya melihat outlet yang di-approve di sini.
/// Berlaku untuk pembeli mandiri maupun pembeli yang didaftarkan penjual.
class AdminBuyerOutletsScreen extends StatefulWidget {
  const AdminBuyerOutletsScreen({super.key});

  @override
  State<AdminBuyerOutletsScreen> createState() =>
      _AdminBuyerOutletsScreenState();
}

class _AdminBuyerOutletsScreenState extends State<AdminBuyerOutletsScreen> {
  final _orderApi = OrderApi();
  final _searchController = TextEditingController();
  List<PublicOutlet> _outlets = [];
  bool _loading = true;
  String _busyKey = '';
  Timer? _debounce;
  // mode tampilan: false = daftar per outlet, true = dikelompokkan per penjual
  bool _bySeller = false;

  // centang untuk aksi massal (aktifkan/nonaktifkan sekaligus + tombol Simpan).
  // Dua set terpisah karena granularitasnya beda (per outlet vs per penjual).
  final Set<String> _selectedOutletKeys = {};
  final Set<int> _selectedSellerIds = {};
  bool _saving = false;

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

  Future<void> _load(String name) async {
    setState(() => _loading = true);
    try {
      final response = await _orderApi.getAllOutletsAdmin(name);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        _outlets = ((body['data'] ?? []) as List)
            .map((e) => PublicOutlet.fromJson(e))
            .toList();
        // buang seleksi centang yang outlet/penjualnya sudah tidak muncul lagi
        // di hasil filter/search terbaru, supaya "Simpan" tidak menyentuh data
        // yang sudah tidak terlihat di layar.
        final presentKeys = _outlets
            .map((o) => '${o.outletGoldId}|${o.outletCode}')
            .toSet();
        _selectedOutletKeys.removeWhere((k) => !presentKeys.contains(k));
        final presentSellerIds = _outlets.map((o) => o.outletGoldId).toSet();
        _selectedSellerIds.removeWhere((id) => !presentSellerIds.contains(id));
      } else {
        String msg = 'Gagal memuat outlet';
        try {
          msg = jsonDecode(response.body)['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(PublicOutlet o, bool value) async {
    final key = '${o.outletGoldId}|${o.outletCode}';
    setState(() => _busyKey = key);
    try {
      final response = value
          ? await _orderApi.addVisibleOutlet(o.outletGoldId, o.outletCode)
          : await _orderApi.removeVisibleOutlet(o.outletGoldId, o.outletCode);
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          final idx = _outlets.indexWhere((x) =>
              x.outletGoldId == o.outletGoldId &&
              x.outletCode == o.outletCode);
          if (idx != -1) {
            _outlets[idx] = PublicOutlet(
              outletGoldId: o.outletGoldId,
              outletCode: o.outletCode,
              outletName: o.outletName,
              outletType: o.outletType,
              outletAddress: o.outletAddress,
              ownerName: o.ownerName,
              visible: value,
            );
          }
        });
        if (mounted) {
          Toast.success(
              context,
              value
                  ? '${o.outletName} kini terlihat pembeli'
                  : '${o.outletName} disembunyikan');
        }
      } else {
        String msg = 'Gagal mengubah';
        try {
          msg = jsonDecode(response.body)['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _busyKey = '');
    }
  }

  // Kelompokkan outlet per penjual (kunci = gold_id pemilik outlet).
  // LinkedHashMap menjaga urutan kemunculan penjual sesuai hasil dari server.
  Map<int, List<PublicOutlet>> _groupBySeller() {
    final map = <int, List<PublicOutlet>>{};
    for (final o in _outlets) {
      map.putIfAbsent(o.outletGoldId, () => []).add(o);
    }
    return map;
  }

  // Aktif/nonaktifkan SEMUA outlet milik satu penjual sekaligus. Outlet yang
  // statusnya sudah sesuai target dilewati supaya tidak memanggil API percuma.
  Future<void> _toggleSeller(
      int goldId, List<PublicOutlet> outlets, bool value) async {
    final busy = 'seller|$goldId';
    setState(() => _busyKey = busy);
    var changed = 0;
    try {
      for (final o in outlets) {
        if (o.visible == value) continue;
        final response = value
            ? await _orderApi.addVisibleOutlet(o.outletGoldId, o.outletCode)
            : await _orderApi.removeVisibleOutlet(o.outletGoldId, o.outletCode);
        if (response.statusCode == 200 || response.statusCode == 201) {
          final idx = _outlets.indexWhere((x) =>
              x.outletGoldId == o.outletGoldId && x.outletCode == o.outletCode);
          if (idx != -1) {
            _outlets[idx] = PublicOutlet(
              outletGoldId: o.outletGoldId,
              outletCode: o.outletCode,
              outletName: o.outletName,
              outletType: o.outletType,
              outletAddress: o.outletAddress,
              ownerName: o.ownerName,
              visible: value,
            );
            changed++;
          }
        }
      }
      if (mounted) {
        Toast.success(
            context,
            value
                ? 'Semua outlet penjual diaktifkan ($changed diubah)'
                : 'Semua outlet penjual disembunyikan ($changed diubah)');
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _busyKey = '');
    }
  }

  PublicOutlet? _findOutlet(String key) {
    for (final o in _outlets) {
      if ('${o.outletGoldId}|${o.outletCode}' == key) return o;
    }
    return null;
  }

  // Status gabungan outlet yang dicentang (mode Per Outlet):
  // true = semua terpilih sedang AKTIF (Simpan -> nonaktifkan),
  // false = semua terpilih sedang NONAKTIF (Simpan -> aktifkan),
  // null = belum ada yang dicentang, ATAU campuran aktif+nonaktif -> Simpan disable.
  bool? _commonVisibleForOutletSelection() {
    if (_selectedOutletKeys.isEmpty) return null;
    bool? common;
    for (final key in _selectedOutletKeys) {
      final o = _findOutlet(key);
      if (o == null) continue;
      if (common == null) {
        common = o.visible;
      } else if (common != o.visible) {
        return null;
      }
    }
    return common;
  }

  // Sama seperti di atas tapi untuk mode Per Penjual: status 1 penjual
  // dianggap "aktif" hanya jika SEMUA outlet miliknya aktif (konsisten
  // dengan makna switch "Aktifkan semua outlet penjual ini").
  bool? _commonAllActiveForSellerSelection() {
    if (_selectedSellerIds.isEmpty) return null;
    final groups = _groupBySeller();
    bool? common;
    for (final id in _selectedSellerIds) {
      final outlets = groups[id];
      if (outlets == null || outlets.isEmpty) continue;
      final allActive = outlets.every((o) => o.visible);
      if (common == null) {
        common = allActive;
      } else if (common != allActive) {
        return null;
      }
    }
    return common;
  }

  int get _selectedCount =>
      _bySeller ? _selectedSellerIds.length : _selectedOutletKeys.length;

  bool? get _commonSelectedStatus => _bySeller
      ? _commonAllActiveForSellerSelection()
      : _commonVisibleForOutletSelection();

  bool get _canSave => !_saving && _commonSelectedStatus != null;

  String _bulkActionCaption() {
    final unit = _bySeller ? 'penjual' : 'outlet';
    final status = _commonSelectedStatus;
    final n = _selectedCount;
    if (n == 0) {
      return 'Centang $unit untuk aktifkan/nonaktifkan sekaligus, lalu tekan Simpan.';
    }
    if (status == null) {
      return '$n $unit dipilih, campuran aktif & nonaktif — Simpan dinonaktifkan.';
    }
    return '$n $unit dipilih, akan ${status ? "dinonaktifkan" : "diaktifkan"}.';
  }

  bool? _selectAllValueOutlet() {
    if (_outlets.isEmpty) return false;
    if (_selectedOutletKeys.length == _outlets.length) return true;
    if (_selectedOutletKeys.isEmpty) return false;
    return null;
  }

  bool? _selectAllValueSeller() {
    final ids = _groupBySeller().keys.toSet();
    if (ids.isEmpty) return false;
    if (_selectedSellerIds.length == ids.length &&
        ids.every((id) => _selectedSellerIds.contains(id))) {
      return true;
    }
    if (_selectedSellerIds.isEmpty) return false;
    return null;
  }

  // Aksi tombol Simpan: menerapkan status kebalikan dari status gabungan
  // yang sedang dicentang (lihat _commonSelectedStatus) ke semua outlet
  // yang dicentang (langsung) atau ke semua outlet milik penjual yang
  // dicentang (mode Per Penjual).
  Future<void> _saveBulk() async {
    final commonStatus = _commonSelectedStatus;
    if (commonStatus == null) return;
    final target = !commonStatus;
    setState(() => _saving = true);
    var changed = 0;
    try {
      if (_bySeller) {
        final groups = _groupBySeller();
        for (final id in _selectedSellerIds) {
          final outlets = groups[id] ?? const <PublicOutlet>[];
          for (final o in outlets) {
            if (o.visible == target) continue;
            final response = target
                ? await _orderApi.addVisibleOutlet(o.outletGoldId, o.outletCode)
                : await _orderApi.removeVisibleOutlet(
                    o.outletGoldId, o.outletCode);
            if (response.statusCode == 200 || response.statusCode == 201) {
              changed++;
            }
          }
        }
        _selectedSellerIds.clear();
      } else {
        for (final key in _selectedOutletKeys) {
          final o = _findOutlet(key);
          if (o == null || o.visible == target) continue;
          final response = target
              ? await _orderApi.addVisibleOutlet(o.outletGoldId, o.outletCode)
              : await _orderApi.removeVisibleOutlet(
                  o.outletGoldId, o.outletCode);
          if (response.statusCode == 200 || response.statusCode == 201) {
            changed++;
          }
        }
        _selectedOutletKeys.clear();
      }
      if (mounted) {
        Toast.success(
          context,
          target ? '$changed outlet diaktifkan' : '$changed outlet dinonaktifkan',
        );
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    await _load(_searchController.text);
  }

  // Satu baris untuk satu outlet (dipakai di mode per outlet maupun di
  // dalam grup penjual saat di-expand). Checkbox = seleksi aksi massal,
  // switch = toggle instan satuan (perilaku lama, tetap dipertahankan).
  Widget _outletTile(PublicOutlet o) {
    final key = '${o.outletGoldId}|${o.outletCode}';
    final selected = _selectedOutletKeys.contains(key);
    return ListTile(
      leading: Checkbox(
        value: selected,
        onChanged: (v) => setState(() {
          if (v == true) {
            _selectedOutletKeys.add(key);
          } else {
            _selectedOutletKeys.remove(key);
          }
        }),
      ),
      title: Text(o.outletName.toUpperCase()),
      subtitle: Text(
          'Penjual: ${o.ownerName.isEmpty ? "-" : o.ownerName} • ${o.outletCode}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _busyKey == key
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(o.visible ? Icons.visibility : Icons.visibility_off,
                  color: o.visible ? Colors.teal : Colors.grey),
          Switch(
            value: o.visible,
            onChanged: _busyKey == key ? null : (v) => _toggle(o, v),
          ),
        ],
      ),
    );
  }

  // Daftar dikelompokkan per penjual: tiap penjual satu ExpansionTile berisi
  // master switch "aktifkan semua" + daftar outlet miliknya (bisa diatur satuan).
  Widget _buildSellerList() {
    final groups = _groupBySeller();
    final sellerIds = groups.keys.toList();
    return ListView.builder(
      itemCount: sellerIds.length,
      itemBuilder: (context, index) {
        final goldId = sellerIds[index];
        final outlets = groups[goldId]!;
        final ownerName = outlets.first.ownerName.isEmpty
            ? 'Penjual #$goldId'
            : outlets.first.ownerName;
        final activeCount = outlets.where((o) => o.visible).length;
        final allActive = activeCount == outlets.length;
        final busy = _busyKey == 'seller|$goldId';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ExpansionTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _selectedSellerIds.contains(goldId),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selectedSellerIds.add(goldId);
                    } else {
                      _selectedSellerIds.remove(goldId);
                    }
                  }),
                ),
                const Icon(Icons.person, color: Colors.teal),
              ],
            ),
            title: Text(ownerName.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                '${outlets.length} outlet • aktif $activeCount/${outlets.length}'),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              SwitchListTile(
                title: const Text('Aktifkan semua outlet penjual ini'),
                secondary: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.done_all, color: Colors.teal),
                value: allActive,
                onChanged:
                    busy ? null : (v) => _toggleSeller(goldId, outlets, v),
              ),
              const Divider(height: 1),
              ...outlets.map(_outletTile),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Outlet untuk Pembeli'),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _load(_searchController.text)),
          ],
        ),
        drawer: const AppDrawer(),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Cari outlet',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      _debounce?.cancel();
                      _debounce = Timer(
                          const Duration(milliseconds: 400), () => _load(v));
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Aktifkan outlet agar bisa dilihat & dipesan role pembeli.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 10),
                  // pemilih mode: pilih per outlet, atau per penjual (toggle
                  // satu penjual = semua outlet miliknya ikut aktif/nonaktif)
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                            value: false,
                            label: Text('Per Outlet'),
                            icon: Icon(Icons.storefront)),
                        ButtonSegment(
                            value: true,
                            label: Text('Per Penjual'),
                            icon: Icon(Icons.person)),
                      ],
                      selected: {_bySeller},
                      onSelectionChanged: (s) =>
                          setState(() => _bySeller = s.first),
                    ),
                  ),
                ],
              ),
            ),
            if (!_loading && _outlets.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Checkbox(
                      tristate: true,
                      value: _bySeller
                          ? _selectAllValueSeller()
                          : _selectAllValueOutlet(),
                      onChanged: (v) => setState(() {
                        if (_bySeller) {
                          if (v == true) {
                            _selectedSellerIds
                              ..clear()
                              ..addAll(_groupBySeller().keys);
                          } else {
                            _selectedSellerIds.clear();
                          }
                        } else {
                          if (v == true) {
                            _selectedOutletKeys
                              ..clear()
                              ..addAll(_outlets
                                  .map((o) => '${o.outletGoldId}|${o.outletCode}'));
                          } else {
                            _selectedOutletKeys.clear();
                          }
                        }
                      }),
                    ),
                    Text(_bySeller ? 'Pilih semua penjual' : 'Pilih semua outlet'),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _outlets.isEmpty
                      ? Center(
                          child: Text('Tidak ada outlet',
                              style: TextStyle(color: Colors.grey[600])))
                      : _bySeller
                          ? _buildSellerList()
                          : ListView.builder(
                              itemCount: _outlets.length,
                              itemBuilder: (context, index) {
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  child: _outletTile(_outlets[index]),
                                );
                              },
                            ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _bulkActionCaption(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _canSave ? _saveBulk : null,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Simpan'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
