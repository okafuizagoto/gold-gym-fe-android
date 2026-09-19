import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/staff_model.dart';
import '../services/staff_api.dart';
import '../utils/responsive.dart';
import '../utils/staff_menu_keys.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';

/// Menu penjual: Akses Staff. Pilih 1 staff, lalu centang menu mana yang
/// boleh diakses (default semua tercentang -- lihat StaffMenuKeys).
class StaffMenuAccessScreen extends StatefulWidget {
  const StaffMenuAccessScreen({super.key});

  @override
  State<StaffMenuAccessScreen> createState() => _StaffMenuAccessScreenState();
}

class _StaffMenuAccessScreenState extends State<StaffMenuAccessScreen> {
  final _api = StaffApi();
  List<StaffRow> _staff = [];
  bool _loadingStaff = true;
  StaffRow? _selected;
  bool _loadingAccess = false;
  bool _saving = false;
  final Set<String> _deniedKeys = {};

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _loadingStaff = true);
    try {
      final resp = await _api.list();
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _staff = ((body['data'] ?? []) as List)
            .map((e) => StaffRow.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingStaff = false);
  }

  Future<void> _selectStaff(StaffRow s) async {
    setState(() {
      _selected = s;
      _loadingAccess = true;
      _deniedKeys.clear();
    });
    try {
      final resp = await _api.getMenuAccess(s.goldId);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _deniedKeys.addAll(
            ((body['data'] ?? []) as List).map((e) => e.toString()));
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingAccess = false);
  }

  Future<void> _save() async {
    final s = _selected;
    if (s == null) return;
    setState(() => _saving = true);
    try {
      final resp = await _api.setMenuAccess(s.goldId, _deniedKeys.toList());
      if (resp.statusCode == 200) {
        if (mounted) Toast.success(context, 'Akses menu ${s.nama} diperbarui');
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

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Akses Staff'),
        drawer: const AppDrawer(),
        body: _loadingStaff
            ? const Center(child: CircularProgressIndicator())
            : _staff.isEmpty
                ? ListView(
                    children: const [
                      EmptyState(
                        icon: Icons.badge_outlined,
                        title: 'Belum ada staff',
                        description:
                            'Daftarkan staff terlebih dahulu lewat menu "Daftar Staff".',
                      ),
                    ],
                  )
                : ContentWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(pad, 12, pad, 4),
                          child: DropdownButtonFormField<int>(
                            initialValue: _selected?.goldId,
                            decoration: const InputDecoration(
                              labelText: 'Pilih Staff',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            items: _staff
                                .map((s) => DropdownMenuItem(
                                      value: s.goldId,
                                      child: Text(s.nama.isEmpty
                                          ? s.email
                                          : s.nama),
                                    ))
                                .toList(),
                            onChanged: (id) {
                              final s =
                                  _staff.firstWhere((s) => s.goldId == id);
                              _selectStaff(s);
                            },
                          ),
                        ),
                        if (_selected != null)
                          Expanded(
                            child: _loadingAccess
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : ListView(
                                    padding:
                                        EdgeInsets.fromLTRB(pad, 4, pad, 96),
                                    children: [
                                      Text(
                                        'Centang menu yang BOLEH diakses ${_selected!.nama}. '
                                        'Menu "About Us" dan "Absen" selalu bisa diakses staff.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: AppColors.muted),
                                      ),
                                      const SizedBox(height: 8),
                                      Card(
                                        child: Column(
                                          children: StaffMenuKeys.options
                                              .map((opt) => CheckboxListTile(
                                                    value: !_deniedKeys
                                                        .contains(opt.key),
                                                    title: Text(opt.label),
                                                    onChanged: (checked) {
                                                      setState(() {
                                                        if (checked == true) {
                                                          _deniedKeys
                                                              .remove(opt.key);
                                                        } else {
                                                          _deniedKeys
                                                              .add(opt.key);
                                                        }
                                                      });
                                                    },
                                                  ))
                                              .toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                      ],
                    ),
                  ),
        floatingActionButton: _selected == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: const Text('Simpan'),
              ),
      ),
    );
  }
}
