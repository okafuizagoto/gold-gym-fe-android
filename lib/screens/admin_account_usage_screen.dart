import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/usage_stats_api.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/empty_state.dart';
import 'admin_usage_stats_screen.dart' show usageDur;

/// Layar ADMIN: pemakaian per akun pada periode terpilih -- tujuan tombol "Detail" di kartu Akun pada
/// Statistik Pengguna. Padanan pages/admin-statistik-pengguna/accounts.tsx (Next.js).
class AdminAccountUsageScreen extends StatefulWidget {
  const AdminAccountUsageScreen({super.key});

  @override
  State<AdminAccountUsageScreen> createState() =>
      _AdminAccountUsageScreenState();
}

class _AdminAccountUsageScreenState extends State<AdminAccountUsageScreen> {
  static const _page = 50;
  final _api = UsageStatsApi();
  final _search = TextEditingController();
  Timer? _debounce;
  int _seq = 0;
  String _period = '7d';
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
      final res = await _api.getAccountUsage(
          _period, _search.text.trim(), _page, append ? _rows.length : 0);
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

  String _trio(Map<String, dynamic> u, String min, String max, String avg,
      bool has) {
    if (!has) return '-';
    return '${usageDur(u[min] ?? 0)} / ${usageDur(u[max] ?? 0)} / ${usageDur(u[avg] ?? 0)}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final periods = <List<String>>[
      ['today', 'Today', 'Hari ini'],
      ['7d', 'Last 7 days', '7 hari terakhir'],
      ['30d', 'Last 30 days', '30 hari terakhir'],
      ['6m', 'Last 6 months', '6 bulan terakhir'],
      ['1y', 'Last 1 year', '1 tahun terakhir'],
    ];
    return Scaffold(
      appBar: AppBarCustom(
          title: lang.get('Total Accounts Detail', 'Detail Total Akun')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: DropdownButtonFormField<String>(
              initialValue: _period,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: lang.get('Period', 'Periode'),
                isDense: true,
              ),
              items: [
                for (final p in periods)
                  DropdownMenuItem(
                      value: p[0], child: Text(lang.get(p[1], p[2]))),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _period = v);
                _load(false);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: lang.get('Search name, email or company',
                    'Cari nama, email, atau nama PT'),
                isDense: true,
              ),
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
                              icon: Icons.groups_outlined,
                              title: lang.get('No accounts found', 'Tidak ada akun'),
                            ),
                          ])
                        : ListView(
                            padding: const EdgeInsets.all(12),
                            children: [
                              Text('${_rows.length} / $_total',
                                  style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 6),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 20,
                                  headingRowHeight: 64,
                                  dataRowMinHeight: 52,
                                  dataRowMaxHeight: 64,
                                  columns: [
                                    DataColumn(
                                        label: Text(lang.get('Name', 'Nama'))),
                                    DataColumn(
                                        label: Text(lang.get('Email', 'Email'))),
                                    DataColumn(
                                        label: Text(lang.get('Company', 'Nama PT'))),
                                    DataColumn(
                                        numeric: true,
                                        label: Text(lang.get('Sessions', 'Sesi'))),
                                    DataColumn(
                                        label: Text(lang.get(
                                            'Session shortest / longest / avg',
                                            'Sesi tersingkat / terlama / rata-rata'))),
                                    DataColumn(
                                        label: Text(
                                            '${lang.get('Per-user total shortest / longest / avg', 'Total per pengguna tersingkat / terlama / rata-rata')}\n${lang.get('(per active day)', '(per hari aktif)')}')),
                                  ],
                                  rows: [
                                    for (final u in _rows)
                                      DataRow(cells: [
                                        DataCell(ConstrainedBox(
                                          constraints:
                                              const BoxConstraints(maxWidth: 180),
                                          child: Text(
                                              '${(u['nama'] ?? '').toString().isEmpty ? '-' : u['nama']}\n${u['role'] ?? '-'} · #${u['gold_id']}',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis),
                                        )),
                                        DataCell(ConstrainedBox(
                                          constraints:
                                              const BoxConstraints(maxWidth: 220),
                                          child: Text(
                                              (u['email'] ?? '-').toString(),
                                              overflow: TextOverflow.ellipsis),
                                        )),
                                        DataCell(ConstrainedBox(
                                          constraints:
                                              const BoxConstraints(maxWidth: 180),
                                          child: Text(
                                              (u['nama_pt'] ?? '').toString().isEmpty
                                                  ? '-'
                                                  : u['nama_pt'].toString(),
                                              overflow: TextOverflow.ellipsis),
                                        )),
                                        DataCell(Text('${u['sessions'] ?? 0}')),
                                        DataCell(Text(_trio(
                                            u,
                                            'session_min_sec',
                                            'session_max_sec',
                                            'session_avg_sec',
                                            (u['sessions'] ?? 0) > 0))),
                                        DataCell(Text(_trio(
                                            u,
                                            'day_min_sec',
                                            'day_max_sec',
                                            'day_avg_sec',
                                            (u['active_days'] ?? 0) > 0))),
                                      ]),
                                  ],
                                ),
                              ),
                              if (_rows.length < _total)
                                TextButton(
                                  onPressed: _loadingMore
                                      ? null
                                      : () {
                                          setState(() => _loadingMore = true);
                                          _load(true);
                                        },
                                  child: Text(lang.get(
                                      'Load more', 'Muat lebih banyak')),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  lang.get(
                                      'Same definitions as the summary: a session is a run of activity with gaps ≤ 30 minutes; 1-minute resolution. Per-user total is the time spent per active day; accounts with no sessions show “-”.',
                                      'Definisi sama dengan ringkasan: sesi = rangkaian aktivitas dengan jeda ≤ 30 menit; resolusi 1 menit. Total per pengguna = waktu pakai per hari aktif; akun tanpa sesi tampil “-”.'),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
