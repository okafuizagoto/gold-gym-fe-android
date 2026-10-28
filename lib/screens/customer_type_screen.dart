import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/customer_type_api.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';

/// Tipe Pelanggan -- padanan pages/customer-type/index.tsx di web. Kategori opsional untuk pelanggan
/// (mis. Reguler, Member, Grosir) per outlet; bisa ditandai saat menambah customer.
class CustomerTypeScreen extends StatefulWidget {
  const CustomerTypeScreen({super.key});

  @override
  State<CustomerTypeScreen> createState() => _CustomerTypeScreenState();
}

class _CustomerTypeScreenState extends State<CustomerTypeScreen> {
  final _api = CustomerTypeApi();
  String _outcode = '';
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _outcode = await Storage.get(AppConstants.outcode) ?? '';
    try {
      final r = await _api.getAll(_outcode);
      if (r.statusCode == 200) {
        final list = (jsonDecode(r.body)['data'] ?? []) as List;
        _rows = list.map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (mounted) {
        Toast.error(context, _err(r.body, 'Gagal memuat tipe pelanggan'));
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  String _err(String body, String fallback) {
    try {
      return jsonDecode(body)['error'] ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  bool _active(Map<String, dynamic> r) =>
      '${r['ct_status'] ?? 'active'}'.toLowerCase() == 'active';

  /// Dialog tambah (row == null) atau edit.
  Future<void> _form([Map<String, dynamic>? row]) async {
    final nameC = TextEditingController(text: row == null ? '' : '${row['ct_name'] ?? ''}');
    final catC = TextEditingController(text: row == null ? '' : '${row['ct_category'] ?? ''}');
    final descC = TextEditingController(text: row == null ? '' : '${row['ct_description'] ?? ''}');
    bool active = row == null ? true : _active(row);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (dc, setD) => AlertDialog(
          title: Text(row == null ? 'Tambah Tipe Pelanggan' : 'Edit Tipe Pelanggan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameC,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Nama *')),
                const SizedBox(height: 10),
                TextField(
                    controller: catC,
                    decoration: const InputDecoration(
                        labelText: 'Kategori', hintText: 'mis. grosir, member')),
                const SizedBox(height: 10),
                TextField(
                    controller: descC,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Deskripsi')),
                if (row != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktif'),
                    value: active,
                    onChanged: (v) => setD(() => active = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.pop(dc, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (nameC.text.trim().isEmpty) {
      if (mounted) Toast.error(context, 'Nama tipe wajib diisi');
      return;
    }
    try {
      final r = row == null
          ? await _api.insert({
              'ct_outcode': _outcode,
              'ct_name': nameC.text.trim(),
              'ct_category': catC.text.trim(),
              'ct_description': descC.text.trim(),
              'ct_status': 'active',
            })
          : await _api.update({
              'ct_id': row['ct_id'],
              'ct_outcode': row['ct_outcode'],
              'ct_name': nameC.text.trim(),
              'ct_category': catC.text.trim(),
              'ct_description': descC.text.trim(),
              'ct_status': active ? 'active' : 'nonactive',
            });
      if (r.statusCode == 200) {
        if (mounted) {
          Toast.success(context, row == null ? 'Tipe pelanggan ditambahkan' : 'Tipe pelanggan diperbarui');
        }
        await _load();
      } else if (mounted) {
        Toast.error(context, _err(r.body, 'Gagal menyimpan'));
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Hapus Tipe Pelanggan'),
        content: Text(
            'Hapus tipe "${row['ct_name']}"? Customer yang sudah ditandai tipe ini tidak ikut terhapus, tapi tandanya jadi tidak valid lagi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Batal')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(dc, true),
              child: const Text('HAPUS')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await _api.remove(int.tryParse('${row['ct_id']}') ?? 0, '${row['ct_outcode']}');
      if (r.statusCode == 200) {
        if (mounted) Toast.success(context, 'Tipe pelanggan dihapus');
        await _load();
      } else if (mounted) {
        Toast.error(context, _err(r.body, 'Gagal menghapus'));
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Tipe Pelanggan'),
        drawer: const AppDrawer(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _form(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Tambah'),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 60),
                      EmptyState(
                          icon: Icons.label_outline_rounded,
                          title: 'Belum ada tipe pelanggan',
                          description: 'Tekan tombol Tambah untuk membuat tipe pertama.'),
                    ])
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                              'Kategori opsional untuk pelanggan (mis. Reguler, Member, Grosir) -- bisa ditandai saat menambah customer.',
                              style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                        ),
                        for (final r in _rows)
                          Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    _active(r) ? AppColors.blueLight : Colors.grey.shade300,
                                child: Icon(Icons.label_outline_rounded,
                                    color: _active(r) ? AppColors.blueDark : Colors.grey.shade600),
                              ),
                              title: Text('${r['ct_name'] ?? ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text([
                                if ('${r['ct_category'] ?? ''}'.isNotEmpty) '${r['ct_category']}',
                                _active(r) ? 'Aktif' : 'Nonaktif',
                                if ('${r['ct_description'] ?? ''}'.isNotEmpty) '${r['ct_description']}',
                              ].join(' · ')),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.edit_rounded),
                                      color: AppColors.blueDark,
                                      onPressed: () => _form(r)),
                                  IconButton(
                                      icon: const Icon(Icons.delete_rounded),
                                      color: Colors.red.shade700,
                                      onPressed: () => _delete(r)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}
