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

String _dur(num sec) {
  if (sec <= 0) return '-';
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = (sec % 60).round();
  if (h > 0) return '${h}j ${m.toString().padLeft(2, '0')}m';
  if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}d';
  return '${s}d';
}

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

  String _roles(dynamic m) => (m as Map? ?? {})
      .entries
      .map((e) => '${e.key}: ${e.value}')
      .join('  ·  ');

  String _d(Map<String, dynamic> d) => (d['count'] ?? 0) > 0
      ? '${_dur(d['min_sec'])} / ${_dur(d['max_sec'])} / ${_dur(d['avg_sec'])}'
      : '-';

  Widget _period(LanguageProvider lang, String label, Map<String, dynamic> p) {
    final s = Map<String, dynamic>.from(p['sessions']);
    final u = Map<String, dynamic>.from(p['per_user_total']);
    return SectionCard(
      title: label,
      icon: Icons.calendar_today_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            '${lang.get('Active users', 'Pengguna aktif')}: ${p['active_users']}'),
        Text(
            '${lang.get('New registrations', 'Pendaftar baru')}: ${p['registered']}'),
        Text('${lang.get('Sessions', 'Sesi')}: ${s['count']}'),
        Text(
            '${lang.get('Session shortest / longest / avg', 'Sesi tersingkat / terlama / rata-rata')}: ${_d(s)}'),
        Text(
            '${lang.get('Per-user total shortest / longest / avg', 'Total per pengguna tersingkat / terlama / rata-rata')}: ${_d(u)}'),
      ]),
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
                child: ListView(children: [
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
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r['online_now']}',
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(color: Colors.green)),
                          Text(_roles(r['online_by_role'])),
                        ]),
                  ),
                  SectionCard(
                    title: lang.get('Accounts', 'Akun'),
                    icon: Icons.people_outline,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${lang.get('Total', 'Total')}: ${r['total_accounts']}'),
                          Text(_roles(r['accounts_by_role'])),
                          Text(
                              '${lang.get('Registration date unknown (older accounts)', 'Tanggal daftar tidak tercatat (akun lama)')}: ${r['registered_date_unknown']}'),
                        ]),
                  ),
                  _period(lang, lang.get('Today', 'Hari ini'),
                      Map<String, dynamic>.from(r['today'])),
                  _period(lang, lang.get('Last 7 days', '7 hari terakhir'),
                      Map<String, dynamic>.from(r['last_7_days'])),
                  _period(lang, lang.get('Last 30 days', '30 hari terakhir'),
                      Map<String, dynamic>.from(r['last_30_days'])),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      lang.get(
                          'A session is a run of activity with gaps ≤ 30 minutes; 1-minute resolution. Idle open apps are not counted.',
                          'Sesi = rangkaian aktivitas dengan jeda ≤ 30 menit; resolusi 1 menit. Aplikasi terbuka tanpa aktivitas tidak dihitung.'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ]),
              ),
      ),
    );
  }
}
