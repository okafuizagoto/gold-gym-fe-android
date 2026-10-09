import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/usage_stats_api.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/empty_state.dart';

/// Layar ADMIN (2026-10-10): daftar akun yang "online sekarang" (aktif < 5 menit) -- tujuan tombol
/// "Detail" di kartu Live Sekarang pada layar User Statistics.
class AdminOnlineNowUsersScreen extends StatefulWidget {
  const AdminOnlineNowUsersScreen({super.key});

  @override
  State<AdminOnlineNowUsersScreen> createState() =>
      _AdminOnlineNowUsersScreenState();
}

class _AdminOnlineNowUsersScreenState extends State<AdminOnlineNowUsersScreen> {
  final _api = UsageStatsApi();
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getOnlineNowUsers();
      if (res.statusCode == 200) {
        final data = (jsonDecode(res.body)['data'] ?? []) as List;
        _rows = data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (mounted) {
        final lang = context.read<LanguageProvider>();
        Toast.error(context, lang.get('Failed to load', 'Gagal memuat'));
      }
    } catch (_) {
      if (mounted) {
        final lang = context.read<LanguageProvider>();
        Toast.error(context, lang.get('Failed to load', 'Gagal memuat'));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Scaffold(
      appBar: AppBarCustom(title: lang.get('Online Now', 'Live Sekarang')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _rows.isEmpty
                  ? EmptyState(
                      icon: Icons.circle_outlined,
                      title: lang.get('No one online right now',
                          'Tidak ada yang online sekarang'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _rows.length,
                      itemBuilder: (context, i) {
                        final u = _rows[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text((u['nama'] ?? '').toString().isEmpty
                                ? (u['email'] ?? '-').toString()
                                : u['nama'].toString()),
                            subtitle: Text(
                                '${u['email'] ?? '-'} · ${u['role'] ?? '-'}'),
                            trailing: Text('#${u['gold_id']}'),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
