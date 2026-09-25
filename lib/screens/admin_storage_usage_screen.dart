import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/storage_model.dart';
import '../services/storage_api.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';
import '../widgets/storage_limit_rules.dart';

/// Admin: penggunaan storage Backblaze B2 lintas semua user -- total
/// upload/download/simpan per user, batas per user/global, rollup
/// alert/limit per environment. Padanan pages/admin-storage-usage (Next.js).
class AdminStorageUsageScreen extends StatefulWidget {
  const AdminStorageUsageScreen({super.key});

  @override
  State<AdminStorageUsageScreen> createState() =>
      _AdminStorageUsageScreenState();
}

class _AdminStorageUsageScreenState extends State<AdminStorageUsageScreen> {
  final _storageApi = StorageApi();
  bool _loading = true;
  bool _forbidden = false;
  List<AdminUserUsage> _users = [];
  List<AdminUsageSummary> _summary = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final users = await _storageApi.adminListUsers();
    final summary = await _storageApi.adminGetUsageSummary();
    if (mounted) {
      setState(() {
        if (users == null || summary == null) {
          _forbidden = true;
        } else {
          _users = users;
          _summary = summary;
          _forbidden = false;
        }
        _loading = false;
      });
    }
  }

  String _gb(double n) => '${n.toStringAsFixed(3)} GB';

  Future<void> _editGlobalLimit() async {
    final controller = TextEditingController();
    final val = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limit default semua user'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Limit (GB)', hintText: 'mis. 0.05 untuk 50 MB'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.pop(context, v);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (val == null || val <= 0) return;
    final resp = await _storageApi.adminSetGlobalLimit(val);
    if (resp.statusCode == 200) {
      if (mounted) Toast.success(context, 'Default limit diubah ke $val GB');
      await _load();
    } else {
      if (mounted) Toast.error(context, 'Gagal mengubah limit global');
    }
  }

  Future<void> _editUserLimit(AdminUserUsage u) async {
    final controller = TextEditingController(
        text: u.hasOverride ? u.effectiveLimitGb.toString() : '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Limit user #${u.goldId}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Limit (GB) -- kosongkan untuk pakai default global'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final val =
        result.isEmpty ? null : double.tryParse(result.replaceAll(',', '.'));
    if (result.isNotEmpty && (val == null || val <= 0)) {
      if (mounted) Toast.error(context, 'Isi angka GB yang valid');
      return;
    }
    final resp = await _storageApi.adminSetUserLimit(u.goldId, val);
    if (resp.statusCode == 200) {
      if (mounted) {
        Toast.success(context,
            val == null ? 'Override dihapus' : 'Limit diubah ke $val GB');
      }
      await _load();
    } else {
      if (mounted) Toast.error(context, 'Gagal mengubah limit user');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Penggunaan Storage (B2)'),
        drawer: const AppDrawer(),
        body: _forbidden
            ? const EmptyState(icon: Icons.data_usage, title: 'Khusus admin')
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        SectionCard(
                          title: 'Ringkasan per environment',
                          icon: Icons.data_usage,
                          child: Column(
                            children: _summary
                                .map((s) => Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                    s.environment.toUpperCase(),
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                if (s.alerted)
                                                  const Chip(
                                                      label: Text(
                                                          'Alert tercapai'),
                                                      backgroundColor: AppColors
                                                          .warningLight),
                                              ],
                                            ),
                                            Text(
                                                'Simpan: ${_gb(s.storageGb)} · Upload: ${_gb(s.uploadGb)} · Download: ${_gb(s.downloadGb)}'),
                                            Text(
                                                'Alert di ${s.alertGb} GB · Limit keras ${s.limitGb} GB'),
                                          ],
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Daftar user',
                          icon: Icons.data_usage,
                          action: TextButton(
                            onPressed: _editGlobalLimit,
                            child: const Text('Ubah default'),
                          ),
                          child: _users.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                      'Belum ada user dengan riwayat penggunaan storage'),
                                )
                              : Column(
                                  children: _users
                                      .map((u) => ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text('Gold ID ${u.goldId}'),
                                            subtitle: Text(
                                                'Paket ${u.plan.isEmpty ? '-' : u.plan}\n'
                                                'Bukti bayar + QRIS ${(u.storageGb * 1024).toStringAsFixed(2)} MB · Foto produk ${(u.itemStorageGb * 1024).toStringAsFixed(2)} MB${u.itemQuotaMb > 0 ? ' / ${u.itemQuotaMb.toStringAsFixed(0)} MB' : ''}\n'
                                                'Maks/foto: produk ${u.itemMaxMb.toStringAsFixed(0)} MB · bukti ${u.proofMaxMb.toStringAsFixed(0)} MB\n'
                                                'Upload ${_gb(u.uploadGb)} · Download ${_gb(u.downloadGb)} · Limit ${_gb(u.effectiveLimitGb)}${u.hasOverride ? ' (override)' : ''}'),
                                            isThreeLine: true,
                                            trailing: TextButton(
                                              onPressed: () =>
                                                  _editUserLimit(u),
                                              child: const Text('Atur limit'),
                                            ),
                                          ))
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 16),
                        StorageLimitRules(onChanged: _load),
                      ],
                    ),
                  ),
      ),
    );
  }
}
