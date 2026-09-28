import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/staff_model.dart';
import '../models/stock_transfer_model.dart';
import '../services/staff_api.dart';
import '../services/stock_transfer_api.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';

/// Izin kirim & terima stok per staf (khusus pemilik).
/// Padanan pages/izin-transfer-staff (Next.js).
class StaffTransferPermissionScreen extends StatefulWidget {
  const StaffTransferPermissionScreen({super.key});

  @override
  State<StaffTransferPermissionScreen> createState() =>
      _StaffTransferPermissionScreenState();
}

class _StaffTransferPermissionScreenState
    extends State<StaffTransferPermissionScreen> {
  final _staffApi = StaffApi();
  final _api = StockTransferApi();
  List<StaffRow> _staff = [];
  StaffRow? _selected;
  bool _loading = true;
  bool _loadingPerm = false;
  bool _saving = false;
  String _send = TransferLevel.none;
  String _receive = TransferLevel.none;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    try {
      final resp = await _staffApi.list();
      if (resp.statusCode == 200) {
        _staff = ((jsonDecode(resp.body)['data'] ?? []) as List)
            .map((e) => StaffRow.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pick(StaffRow s) async {
    setState(() {
      _selected = s;
      _loadingPerm = true;
    });
    try {
      final p = await _api.getPermission(s.goldId);
      _send = p?.sendLevel ?? TransferLevel.none;
      _receive = p?.receiveLevel ?? TransferLevel.none;
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memuat izin staf');
    }
    if (mounted) setState(() => _loadingPerm = false);
  }

  Future<void> _save() async {
    final s = _selected;
    if (s == null) return;
    setState(() => _saving = true);
    try {
      final resp = await _api.setPermission(s.goldId, _send, _receive);
      if (resp.statusCode == 200) {
        if (mounted) Toast.success(context, 'Izin transfer ${s.nama} diperbarui');
      } else {
        String msg = 'Gagal menyimpan';
        try {
          msg = jsonDecode(resp.body)['error']?.toString() ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal menyimpan');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _levelField(String label, String value, ValueChanged<String> set) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final l in TransferLevel.all)
              DropdownMenuItem(value: l, child: Text(TransferLevel.label(l))),
          ],
          onChanged: (v) => set(v ?? TransferLevel.none),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Izin Transfer Stok'),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _staff.isEmpty
                ? const EmptyState(
                    title: 'Belum ada staff',
                    description:
                        'Daftarkan staff terlebih dahulu lewat menu "Daftar Staff".')
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      DropdownButtonFormField<StaffRow>(
                        value: _selected,
                        decoration: const InputDecoration(labelText: 'Pilih Staff'),
                        items: [
                          for (final s in _staff)
                            DropdownMenuItem(
                                value: s,
                                child: Text(s.nama.isEmpty ? s.email : s.nama)),
                        ],
                        onChanged: (s) => s == null ? null : _pick(s),
                      ),
                      if (_selected != null)
                        if (_loadingPerm)
                          const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()))
                        else ...[
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                                '"Perlu persetujuan pemilik": aksi staf hanya berupa permintaan, stok baru berpindah setelah Anda menyetujui.',
                                style: TextStyle(color: Colors.grey)),
                          ),
                          _levelField('Sisi kirim (buat, kirim, batal)', _send,
                              (v) => setState(() => _send = v)),
                          _levelField('Sisi terima', _receive,
                              (v) => setState(() => _receive = v)),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                                onPressed: _saving ? null : _save,
                                child: const Text('Simpan')),
                          ),
                        ],
                    ],
                  ),
      ),
    );
  }
}
