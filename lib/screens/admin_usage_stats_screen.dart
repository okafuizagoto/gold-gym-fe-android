import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/usage_stats_api.dart';
import '../utils/responsive.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/page_header.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';
import 'admin_account_usage_screen.dart';
import 'admin_online_now_users_screen.dart';

String _dur(num sec) {
  if (sec <= 0) return '-';
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = (sec % 60).round();
  if (h > 0) return '${h}j ${m.toString().padLeft(2, '0')}m';
  if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}d';
  return '${s}d';
}

/// Format durasi yang sama dipakai layar Detail Total Akun.
String usageDur(num sec) => _dur(sec);

/// Layar ADMIN: statistik pemakaian (live sekarang, pendaftar, durasi pakai). Auto-refresh 30 dtk.
/// Padanan pages/admin-statistik-pengguna/index.tsx (Next.js).
class AdminUsageStatsScreen extends StatefulWidget {
  const AdminUsageStatsScreen({super.key});

  @override
  State<AdminUsageStatsScreen> createState() => _AdminUsageStatsScreenState();
}

class _AdminUsageStatsScreenState extends State<AdminUsageStatsScreen> {
  final _api = UsageStatsApi();
  Map<String, dynamic>? _r;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final lang = context.read<LanguageProvider>();
    try {
      final res = await _api.getReport();
      if (res.statusCode == 200 && mounted) {
        setState(
            () => _r = Map<String, dynamic>.from(jsonDecode(res.body)['data']));
      } else if (mounted && _r == null) {
        Toast.error(context, lang.get('Failed to load', 'Gagal memuat'));
      }
    } catch (_) {
      if (mounted && _r == null) {
        Toast.error(context, lang.get('Failed to load', 'Gagal memuat'));
      }
    }
  }

  String _fmtSince(dynamic v) {
    final d = DateTime.tryParse('$v')?.toLocal();
    if (d == null) return '$v';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} ${two(d.hour)}.${two(d.minute)}.${two(d.second)}';
  }

  String _d(Map<String, dynamic> d) => (d['count'] ?? 0) > 0
      ? '${_dur(d['min_sec'])} / ${_dur(d['max_sec'])} / ${_dur(d['avg_sec'])}'
      : '-';

  Widget _roleChips(dynamic m) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(spacing: 4, runSpacing: 4, children: [
          for (final e in (m as Map? ?? {}).entries)
            Chip(
                label: Text('${e.key}: ${e.value}'),
                visualDensity: VisualDensity.compact),
        ]),
      );

  /// Satu tabel periode (padanan Table di web): kolom sama, bisa digeser ke samping.
  Widget _periodTable(LanguageProvider lang, Map<String, dynamic> r) {
    final rows = <(String, Map<String, dynamic>)>[
      (lang.get('Today', 'Hari ini'), Map<String, dynamic>.from(r['today'])),
      (
        lang.get('Last 7 days', '7 hari terakhir'),
        Map<String, dynamic>.from(r['last_7_days'])
      ),
      (
        lang.get('Last 30 days', '30 hari terakhir'),
        Map<String, dynamic>.from(r['last_30_days'])
      ),
    ];
    DataColumn col(String label) =>
        DataColumn(label: Text(label), numeric: true);
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text(lang.get('Period', 'Periode'))),
            col(lang.get('Active users', 'Pengguna aktif')),
            col(lang.get('New registrations', 'Pendaftar baru')),
            col(lang.get('Sessions', 'Sesi')),
            col(lang.get('Session shortest / longest / avg',
                'Sesi tersingkat / terlama / rata-rata')),
            col(lang.get('Per-user total shortest / longest / avg',
                'Total per pengguna tersingkat / terlama / rata-rata')),
          ],
          rows: [
            for (final (label, p) in rows)
              DataRow(cells: [
                DataCell(Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(Text('${p['active_users']}')),
                DataCell(Text('${p['registered']}')),
                DataCell(Text('${(p['sessions'] as Map)['count']}')),
                DataCell(Text(_d(Map<String, dynamic>.from(p['sessions'])))),
                DataCell(
                    Text(_d(Map<String, dynamic>.from(p['per_user_total'])))),
              ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final title = lang.get('User Statistics', 'Statistik Pengguna');
    final r = _r;
    return PrivateRoute(
      child: Scaffold(
        appBar: AppBarCustom(title: title),
        drawer: const AppDrawer(),
        body: r == null
            ? const Center(child: CircularProgressIndicator())
            : PageBody(
                maxWidth: 760,
                child: Column(children: [
                  PageHeader(
                    title: title,
                    subtitle: lang.get(
                        'Live users, registrations, and usage time (refreshes every 30 s)',
                        'Pengguna live, pendaftar, dan lama pemakaian (diperbarui tiap 30 dtk)'),
                    icon: Icons.insights_outlined,
                  ),
                  SectionCard(
                    title: lang.get('Online now (active < 5 min)',
                        'Live sekarang (aktif < 5 menit)'),
                    icon: Icons.circle,
                    action: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminOnlineNowUsersScreen(),
                        ),
                      ),
                      child: Text(lang.get('Detail', 'Detail')),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r['online_now']}',
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(color: Colors.green)),
                          _roleChips(r['online_by_role']),
                        ]),
                  ),
                  SectionCard(
                    title: lang.get('Total accounts', 'Total akun'),
                    icon: Icons.people_outline,
                    action: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminAccountUsageScreen(),
                        ),
                      ),
                      child: Text(lang.get('Detail', 'Detail')),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r['total_accounts']}',
                              style: Theme.of(context).textTheme.displaySmall),
                          _roleChips(r['accounts_by_role']),
                        ]),
                  ),
                  SectionCard(
                    title: lang.get('Registration date unknown',
                        'Tanggal daftar tidak tercatat'),
                    icon: Icons.help_outline,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r['registered_date_unknown']}',
                              style: Theme.of(context).textTheme.displaySmall),
                          Text(
                              lang.get('Older accounts (before tracking)',
                                  'Akun lama (sebelum pencatatan)'),
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                  _periodTable(lang, r),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '${lang.get('A session is a run of activity with gaps ≤ 30 minutes. Durations have 1-minute resolution (a session with one request counts as 1 minute). Only time with requests to the server is measured; an app left open idle is not counted.', 'Sesi = rangkaian aktivitas dengan jeda ≤ 30 menit. Durasi beresolusi 1 menit (sesi dengan satu request dihitung 1 menit). Hanya waktu dengan request ke server yang terukur; aplikasi yang dibiarkan terbuka tanpa aktivitas tidak dihitung.')}'
                      '${r['tracking_since'] != null ? ' ${lang.get('Tracking since', 'Pencatatan sejak')}: ${_fmtSince(r['tracking_since'])}.' : ' ${lang.get('No sessions recorded yet.', 'Belum ada sesi tercatat.')}'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ]),
              ),
      ),
    );
  }
}
