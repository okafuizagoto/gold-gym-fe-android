import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/language_provider.dart';
import '../services/account_admin_api.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/empty_state.dart';

/// Layar ADMIN: daftar akun + ban / buka ban. Padanan pages/admin-akun (Next.js).
/// Akun di-ban tidak bisa login dan token yang masih berlaku ditolak dalam ~30 detik.
class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key});

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  static const _page = 30;
  final _api = AccountAdminApi();
  final _search = TextEditingController();
  Timer? _debounce;
  int _seq = 0;
  String _status = 'all';
  bool _loading = true;
  bool _loadingMore = false;
  int _total = 0;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load(false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load(bool append) async {
    final my = ++_seq;
    if (!append) setState(() => _loading = true);
    try {
      final res = await _api.list(
          _search.text.trim(), _status, _page, append ? _rows.length : 0);
      if (my != _seq || !mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = ((body['data'] ?? []) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _total = (body['total'] ?? data.length) as int;
        _rows = append ? [..._rows, ...data] : data;
      } else {
        Toast.error(context,
            context.read<LanguageProvider>().get('Failed to load', 'Gagal memuat'));
      }
    } catch (_) {
      if (my == _seq && mounted) {
        Toast.error(context,
            context.read<LanguageProvider>().get('Failed to load', 'Gagal memuat'));
      }
    }
    if (my == _seq && mounted) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(false));
  }

  Future<void> _toggle(Map<String, dynamic> a) async {
    final lang = context.read<LanguageProvider>();
    final active = a['active'] == true;
    final email = (a['email'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(active
            ? lang.get('Ban this account?', 'Ban akun ini?')
            : lang.get('Unban this account?', 'Buka ban akun ini?')),
        content: Text(active
            ? lang.get(
                '$email will be logged out and cannot sign in again until unbanned.',
                '$email akan keluar dan tidak bisa masuk lagi sampai ban dibuka. Staf milik akun ini ikut tidak bisa masuk.')
            : lang.get('$email will be able to sign in again.',
                '$email bisa masuk lagi.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(lang.get('Cancel', 'Batal'))),
          ElevatedButton(
            style: active
                ? ElevatedButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(active ? 'Ban' : lang.get('Unban', 'Buka Ban')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final res = await _api.setActive(a['gold_id'] as int, !active);
      if (!mounted) return;
      if (res.statusCode == 200) {
        Toast.success(
            context,
            active
                ? lang.get('Account banned', 'Akun di-ban')
                : lang.get('Account reactivated', 'Ban akun dibuka'));
        await _load(false);
      } else if (res.body.contains('ACCOUNT_PROTECTED')) {
        Toast.error(
            context,
            lang.get('Admin accounts and your own account cannot be banned',
                'Akun admin dan akun Anda sendiri tidak bisa di-ban'));
      } else {
        Toast.error(context, lang.get('Failed', 'Gagal'));
      }
    } catch (_) {
      if (mounted) Toast.error(context, lang.get('Failed', 'Gagal'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Scaffold(
      appBar: AppBarCustom(title: lang.get('Manage Accounts', 'Kelola Akun')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: lang.get('Search email, name or shop',
                    'Cari email, nama, atau toko'),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              spacing: 8,
              children: [
                for (final s in const [
                  ['all', 'All', 'Semua'],
                  ['active', 'Active', 'Aktif'],
                  ['banned', 'Banned', 'Di-ban'],
                ])
                  ChoiceChip(
                    label: Text(lang.get(s[1], s[2])),
                    selected: _status == s[0],
                    onSelected: (_) {
                      setState(() => _status = s[0]);
                      _load(false);
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _load(false),
                    child: _rows.isEmpty
                        ? ListView(children: [
                            EmptyState(
                              icon: Icons.block,
                              title: lang.get('No accounts found', 'Tidak ada akun'),
                            ),
                          ])
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _rows.length + 1,
                            itemBuilder: (context, i) {
                              if (i == _rows.length) {
                                if (_rows.length >= _total) {
                                  return Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Center(
                                        child: Text('${_rows.length} / $_total')),
                                  );
                                }
                                return TextButton(
                                  onPressed: _loadingMore
                                      ? null
                                      : () {
                                          setState(() => _loadingMore = true);
                                          _load(true);
                                        },
                                  child: Text(lang.get('Load more', 'Muat lebih banyak')),
                                );
                              }
                              final a = _rows[i];
                              final active = a['active'] == true;
                              final isAdmin = a['role'] == 'ADMIN';
                              final nama = (a['nama'] ?? '').toString();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(nama.isEmpty
                                      ? (a['email'] ?? '-').toString()
                                      : nama),
                                  subtitle: Text(
                                      '${a['email'] ?? '-'}\n${a['role'] ?? '-'} · #${a['gold_id']} · ${active ? lang.get('Active', 'Aktif') : lang.get('Banned', 'Di-ban')}'),
                                  isThreeLine: true,
                                  trailing: isAdmin
                                      ? null
                                      : OutlinedButton(
                                          style: active
                                              ? OutlinedButton.styleFrom(
                                                  foregroundColor: AppColors.error)
                                              : null,
                                          onPressed: () => _toggle(a),
                                          child: Text(active
                                              ? 'Ban'
                                              : lang.get('Unban', 'Buka Ban')),
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
