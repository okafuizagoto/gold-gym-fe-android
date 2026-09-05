import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/theme.dart';
import '../models/seller_access_model.dart';
import '../services/seller_access_api.dart';
import '../utils/toast.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

/// Menu yang dikelola layar ini: "Daftar Pembeli" atau "Mode Pembeli".
enum SellerMenuAccessTarget { daftarPembeli, modePembeli }

/// Layar ADMIN: aktif/nonaktifkan menu "Daftar Pembeli" atau "Mode Pembeli"
/// milik akun penjual (retail & therapy) -- terlepas dari status pendaftaran
/// (gold_buyer_yn) mereka sendiri. Strukturnya mirip "Outlet untuk Pembeli"
/// (tab Per Outlet & Per Penjual, search, checkbox + Simpan), plus 2 tombol
/// cepat "Seluruh Outlet"/"Seluruh Penjual" yang langsung mengubah SEMUA
/// akun penjual di sistem tanpa perlu centang manual.
///
/// Catatan: flag yang dikelola di sini melekat di 1 akun penjual (gold_id),
/// bukan per outlet -- kalau 1 penjual punya beberapa outlet, semua baris
/// outletnya akan selalu menampilkan status yang sama, dan mengubah salah
/// satu ikut mengubah semuanya sekaligus.
class SellerMenuAccessScreen extends StatefulWidget {
  final SellerMenuAccessTarget target;
  const SellerMenuAccessScreen({super.key, required this.target});

  @override
  State<SellerMenuAccessScreen> createState() =>
      _SellerMenuAccessScreenState();
}

class _SellerMenuAccessScreenState extends State<SellerMenuAccessScreen> {
  final _api = SellerAccessApi();
  final _searchController = TextEditingController();
  List<SellerMenuAccessRow> _rows = [];
  bool _loading = true;
  String _busyKey = '';
  Timer? _debounce;
  bool _bySeller = false;
  bool _saving = false;

  final Set<String> _selectedOutletKeys = {};
  final Set<int> _selectedSellerIds = {};

  String get _menuLabel => widget.target == SellerMenuAccessTarget.daftarPembeli
      ? 'Daftar Pembeli'
      : 'Mode Pembeli';

  String get _screenTitle => 'Akses $_menuLabel';

  bool _activeOf(SellerMenuAccessRow r) =>
      widget.target == SellerMenuAccessTarget.daftarPembeli
          ? r.daftarPembeliActive
          : r.modePembeliActive;

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
      final response = await _api.getList(name);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        _rows = ((body['data'] ?? []) as List)
            .map((e) => SellerMenuAccessRow.fromJson(e))
            .toList();
        final presentKeys =
            _rows.map((o) => '${o.outletGoldId}|${o.outletCode}').toSet();
        _selectedOutletKeys.removeWhere((k) => !presentKeys.contains(k));
        final presentSellerIds = _rows.map((o) => o.outletGoldId).toSet();
        _selectedSellerIds.removeWhere((id) => !presentSellerIds.contains(id));
      } else {
        String msg = 'Gagal memuat data';
        try {
          msg = jsonDecode(response.body)['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // Sinkronkan status baru ke SEMUA baris outlet milik gold_id yang sama
  // (flag ini account-level, jadi 1 penjual dgn beberapa outlet harus
  // selalu tampil status yang sama).
  void _setLocalActive(int goldId, bool value) {
    _rows = _rows.map((r) {
      if (r.outletGoldId != goldId) return r;
      return SellerMenuAccessRow(
        outletGoldId: r.outletGoldId,
        outletCode: r.outletCode,
        outletName: r.outletName,
        outletType: r.outletType,
        outletAddress: r.outletAddress,
        ownerName: r.ownerName,
        daftarPembeliActive: widget.target == SellerMenuAccessTarget.daftarPembeli
            ? value
            : r.daftarPembeliActive,
        modePembeliActive: widget.target == SellerMenuAccessTarget.modePembeli
            ? value
            : r.modePembeliActive,
      );
    }).toList();
  }

  Future<http.Response> _applyOne(int goldId, bool active) {
    return widget.target == SellerMenuAccessTarget.daftarPembeli
        ? _api.setDaftarPembeli(goldId, active)
        : _api.setModePembeli(goldId, active);
  }

  Future<void> _toggle(SellerMenuAccessRow o, bool value) async {
    final key = '${o.outletGoldId}|${o.outletCode}';
    setState(() => _busyKey = key);
    try {
      final response = await _applyOne(o.outletGoldId, value);
      if (response.statusCode == 200) {
        setState(() => _setLocalActive(o.outletGoldId, value));
        if (mounted) {
          Toast.success(
              context,
              value
                  ? '$_menuLabel diaktifkan untuk ${o.ownerName}'
                  : '$_menuLabel dinonaktifkan untuk ${o.ownerName}');
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

  Map<int, List<SellerMenuAccessRow>> _groupBySeller() {
    final map = <int, List<SellerMenuAccessRow>>{};
    for (final o in _rows) {
      map.putIfAbsent(o.outletGoldId, () => []).add(o);
    }
    return map;
  }

  SellerMenuAccessRow? _findRow(String key) {
    for (final o in _rows) {
      if ('${o.outletGoldId}|${o.outletCode}' == key) return o;
    }
    return null;
  }

  bool? _commonActiveForOutletSelection() {
    if (_selectedOutletKeys.isEmpty) return null;
    bool? common;
    for (final key in _selectedOutletKeys) {
      final o = _findRow(key);
      if (o == null) continue;
      final active = _activeOf(o);
      if (common == null) {
        common = active;
      } else if (common != active) {
        return null;
      }
    }
    return common;
  }

  bool? _commonAllActiveForSellerSelection() {
    if (_selectedSellerIds.isEmpty) return null;
    final groups = _groupBySeller();
    bool? common;
    for (final id in _selectedSellerIds) {
      final outlets = groups[id];
      if (outlets == null || outlets.isEmpty) continue;
      final allActive = outlets.every(_activeOf);
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
      : _commonActiveForOutletSelection();

  bool get _canSave => !_saving && _commonSelectedStatus != null;

  String _bulkActionCaption() {
    final unit = _bySeller ? 'penjual' : 'outlet';
    final status = _commonSelectedStatus;
    final n = _selectedCount;
    if (n == 0) {
      return 'Centang $unit untuk aktifkan/nonaktifkan $_menuLabel sekaligus, lalu tekan Simpan.';
    }
    if (status == null) {
      return '$n $unit dipilih, campuran aktif & nonaktif — Simpan dinonaktifkan.';
    }
    return '$n $unit dipilih, $_menuLabel akan ${status ? "dinonaktifkan" : "diaktifkan"}.';
  }

  bool? _selectAllValueOutlet() {
    if (_rows.isEmpty) return false;
    if (_selectedOutletKeys.length == _rows.length) return true;
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

  Future<void> _saveBulk() async {
    final commonStatus = _commonSelectedStatus;
    if (commonStatus == null) return;
    final target = !commonStatus;
    setState(() => _saving = true);
    var changed = 0;
    try {
      if (_bySeller) {
        for (final id in _selectedSellerIds) {
          final response = await _applyOne(id, target);
          if (response.statusCode == 200) {
            _setLocalActive(id, target);
            changed++;
          }
        }
        _selectedSellerIds.clear();
      } else {
        final goldIds = _selectedOutletKeys
            .map((k) => _findRow(k)?.outletGoldId)
            .whereType<int>()
            .toSet();
        for (final id in goldIds) {
          final response = await _applyOne(id, target);
          if (response.statusCode == 200) {
            _setLocalActive(id, target);
            changed++;
          }
        }
        _selectedOutletKeys.clear();
      }
      if (mounted) {
        Toast.success(
          context,
          target
              ? '$changed penjual diaktifkan'
              : '$changed penjual dinonaktifkan',
        );
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    await _load(_searchController.text);
  }

  // Tombol cepat "Seluruh Outlet"/"Seluruh Penjual": tidak berhubungan
  // dengan centang, dan berlaku untuk BENAR-BENAR SEMUA penjual di sistem
  // (mengabaikan hasil search yang sedang tampil).
  Future<void> _quickGlobalAction(String scopeLabel) async {
    final target = await showDialog<bool>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(scopeLabel),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Aktifkan Semua $_menuLabel'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Nonaktifkan Semua $_menuLabel'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
    if (target == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: Text(
          '${target ? "Aktifkan" : "Nonaktifkan"} $_menuLabel untuk SEMUA '
          'penjual ($scopeLabel)?\n\nAksi ini berlaku untuk seluruh penjual '
          'di sistem, tidak memandang hasil pencarian yang sedang tampil.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, Lanjutkan')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    var changed = 0;
    try {
      final response = await _api.getList('');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final allRows = ((body['data'] ?? []) as List)
            .map((e) => SellerMenuAccessRow.fromJson(e))
            .toList();
        final seenGoldIds = <int>{};
        for (final r in allRows) {
          if (!seenGoldIds.add(r.outletGoldId)) continue;
          if (_activeOf(r) == target) continue;
          final resp = await _applyOne(r.outletGoldId, target);
          if (resp.statusCode == 200) changed++;
        }
      }
      if (mounted) {
        Toast.success(
          context,
          '$changed penjual diubah (${target ? "diaktifkan" : "dinonaktifkan"})',
        );
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    await _load(_searchController.text);
  }

  Widget _outletTile(SellerMenuAccessRow o) {
    final key = '${o.outletGoldId}|${o.outletCode}';
    final selected = _selectedOutletKeys.contains(key);
    final active = _activeOf(o);
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
              : Icon(active ? Icons.check_circle : Icons.cancel,
                  color: active ? Colors.teal : Colors.grey),
          Switch(
            value: active,
            onChanged: _busyKey == key ? null : (v) => _toggle(o, v),
          ),
        ],
      ),
    );
  }

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
        final activeCount = outlets.where(_activeOf).length;
        final allActive = activeCount == outlets.length;
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
                '${outlets.length} outlet • $_menuLabel aktif $activeCount/${outlets.length}'),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              SwitchListTile(
                title: Text('Aktifkan $_menuLabel untuk penjual ini'),
                secondary: const Icon(Icons.done_all, color: Colors.teal),
                value: allActive,
                onChanged: (v) => _toggle(outlets.first, v).then((_) {
                  // sinkron sisa outlet penjual ini (sama gold_id) secara lokal
                  if (mounted) setState(() => _setLocalActive(goldId, v));
                }),
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
          title: Text(_screenTitle),
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
                      labelText: 'Cari outlet atau penjual',
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
                    'Aktifkan/nonaktifkan menu "$_menuLabel" untuk penjual retail & therapy.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 10),
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
            if (!_loading && _rows.isNotEmpty)
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
                              ..addAll(_rows
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
                  : _rows.isEmpty
                      ? Center(
                          child: Text('Tidak ada outlet',
                              style: TextStyle(color: Colors.grey[600])))
                      : _bySeller
                          ? _buildSellerList()
                          : ListView.builder(
                              itemCount: _rows.length,
                              itemBuilder: (context, index) {
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  child: _outletTile(_rows[index]),
                                );
                              },
                            ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _bulkActionCaption(),
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey[700]),
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
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed:
                              _saving ? null : () => _quickGlobalAction('Seluruh Outlet'),
                          child: const Text('Seluruh Outlet'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => _quickGlobalAction('Seluruh Penjual'),
                          child: const Text('Seluruh Penjual'),
                        ),
                      ],
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
