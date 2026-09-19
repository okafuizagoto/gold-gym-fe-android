import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/theme.dart';
import '../models/seller_access_model.dart';
import '../services/seller_access_api.dart';
import '../utils/responsive.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import '../widgets/search_field.dart';
import '../widgets/segmented_tabs.dart';

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
  State<SellerMenuAccessScreen> createState() => _SellerMenuAccessScreenState();
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
        daftarPembeliActive:
            widget.target == SellerMenuAccessTarget.daftarPembeli
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
        content: SingleChildScrollView(
          child: Text(
            '${target ? "Aktifkan" : "Nonaktifkan"} $_menuLabel untuk SEMUA '
            'penjual ($scopeLabel)?\n\nAksi ini berlaku untuk seluruh penjual '
            'di sistem, tidak memandang hasil pencarian yang sedang tampil.',
          ),
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
      title: Text(o.outletName.toUpperCase(),
          maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        'Penjual: ${o.ownerName.isEmpty ? "-" : o.ownerName} • ${o.outletCode}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _busyKey == key
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(
                  active
                      ? Icons.check_circle_outline_rounded
                      : Icons.cancel_outlined,
                  size: 20,
                  color: active ? AppColors.tealDark : AppColors.disabled),
          Switch(
            value: active,
            onChanged: _busyKey == key ? null : (v) => _toggle(o, v),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerList(EdgeInsets padding) {
    final groups = _groupBySeller();
    final sellerIds = groups.keys.toList();
    return ListView.builder(
      padding: padding,
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
          margin: const EdgeInsets.only(bottom: 8),
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
                const Icon(Icons.person_outline_rounded,
                    color: AppColors.tealDark),
              ],
            ),
            title: Text(ownerName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                '${outlets.length} outlet • $_menuLabel aktif $activeCount/${outlets.length}'),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              SwitchListTile(
                title: Text('Aktifkan $_menuLabel untuk penjual ini'),
                secondary: const Icon(Icons.done_all_rounded,
                    color: AppColors.tealDark),
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
    final textTheme = Theme.of(context).textTheme;
    final pad = context.pagePadding;
    final listPadding = EdgeInsets.fromLTRB(pad, 4, pad, pad);
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: AppBarCustom(
          title: _screenTitle,
          actions: [
            IconButton(
                tooltip: 'Muat ulang',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => _load(_searchController.text)),
          ],
        ),
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
                        hintText: 'Cari outlet atau penjual...',
                        onChanged: (v) {
                          _debounce?.cancel();
                          _debounce = Timer(const Duration(milliseconds: 400),
                              () => _load(v));
                        },
                      ),
                      if (!context.isShort) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Aktifkan/nonaktifkan menu "$_menuLabel" untuk penjual retail & therapy.',
                          style: textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 10),
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
                if (!_loading && _rows.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: pad),
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
                                  ..addAll(_rows.map((o) =>
                                      '${o.outletGoldId}|${o.outletCode}'));
                              } else {
                                _selectedOutletKeys.clear();
                              }
                            }
                          }),
                        ),
                        Expanded(
                          child: Text(
                            _bySeller
                                ? 'Pilih semua penjual'
                                : 'Pilih semua outlet',
                            style: textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _rows.isEmpty
                          ? SingleChildScrollView(
                              child: EmptyState(
                                icon: Icons.storefront_outlined,
                                title: 'Tidak ada outlet',
                                compact: context.isShort,
                              ),
                            )
                          : _bySeller
                              ? _buildSellerList(listPadding)
                              : ListView.builder(
                                  padding: listPadding,
                                  itemCount: _rows.length,
                                  itemBuilder: (context, index) {
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: _outletTile(_rows[index]),
                                    );
                                  },
                                ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: pad, vertical: context.isShort ? 6 : 10),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall,
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
                      const SizedBox(height: 6),
                      ResponsiveActions(
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            icon:
                                const Icon(Icons.storefront_outlined, size: 18),
                            onPressed: _saving
                                ? null
                                : () => _quickGlobalAction('Seluruh Outlet'),
                            label: const Text('Seluruh Outlet'),
                          ),
                          OutlinedButton.icon(
                            icon:
                                const Icon(Icons.people_alt_outlined, size: 18),
                            onPressed: _saving
                                ? null
                                : () => _quickGlobalAction('Seluruh Penjual'),
                            label: const Text('Seluruh Penjual'),
                          ),
                        ],
                      ),
                    ],
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
