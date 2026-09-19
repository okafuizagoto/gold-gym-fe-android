import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/staff_attendance_model.dart';
import '../services/staff_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

/// Menu wajib staff: Absen. Clock-in/out sendiri (1 sesi/hari) + riwayat
/// ringkas beberapa hari terakhir.
class StaffClockScreen extends StatefulWidget {
  const StaffClockScreen({super.key});

  @override
  State<StaffClockScreen> createState() => _StaffClockScreenState();
}

class _StaffClockScreenState extends State<StaffClockScreen> {
  final _api = StaffApi();
  TodayStatus? _today;
  bool _loading = true;
  bool _busy = false;
  List<AttendanceDay> _recent = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await _api.today();
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _today = TodayStatus.fromJson(body['data'] as Map<String, dynamic>);
      }
      final now = DateTime.now();
      final monthStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
      final myGoldId =
          int.tryParse(await Storage.get(AppConstants.userGoldIdKey) ?? '') ??
              0;
      final histResp = await _api.getAttendance(myGoldId, monthStr);
      if (histResp.statusCode == 200) {
        final body = jsonDecode(histResp.body);
        final all = ((body['data'] ?? []) as List)
            .map((e) => AttendanceDay.fromJson(e as Map<String, dynamic>))
            .where((d) => d.status == 'hadir')
            .toList()
            .reversed
            .take(7)
            .toList();
        _recent = all;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _clockIn() async {
    setState(() => _busy = true);
    try {
      final resp = await _api.clockIn();
      if (resp.statusCode == 200) {
        if (mounted) Toast.success(context, 'Absen masuk berhasil');
        await _load();
      } else {
        _showErr(resp.body);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clockOut() async {
    setState(() => _busy = true);
    try {
      final resp = await _api.clockOut();
      if (resp.statusCode == 200) {
        if (mounted) Toast.success(context, 'Absen pulang berhasil');
        await _load();
      } else {
        _showErr(resp.body);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showErr(String body) {
    String msg = 'Gagal';
    try {
      msg = jsonDecode(body)['error'] ?? msg;
    } catch (_) {}
    if (mounted) Toast.error(context, msg);
  }

  String _time(String? ts) {
    if (ts == null || ts.isEmpty) return '-';
    final parts = ts.split(' ');
    return parts.length > 1 ? parts[1].substring(0, 5) : ts;
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final textTheme = Theme.of(context).textTheme;
    final isClockedIn = _today?.isClockedIn ?? false;
    final isDone = _today?.isDone ?? false;

    return PrivateRoute(
      child: Scaffold(
        appBar: AppBarCustom(
          title: 'Absen',
          actions: [
            IconButton(
              tooltip: 'Muat ulang',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _load,
            ),
          ],
        ),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ContentWidth(
                child: ListView(
                  padding: EdgeInsets.all(pad),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              isDone
                                  ? Icons.check_circle_outline_rounded
                                  : isClockedIn
                                      ? Icons.timer_outlined
                                      : Icons.fingerprint_rounded,
                              size: 56,
                              color: isDone
                                  ? AppColors.successDark
                                  : isClockedIn
                                      ? AppColors.tealDark
                                      : AppColors.muted,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isDone
                                  ? 'Sudah absen hari ini'
                                  : isClockedIn
                                      ? 'Sedang bekerja'
                                      : 'Belum absen masuk',
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Masuk: ${_time(_today?.clockInAt)}   •   Pulang: ${_time(_today?.clockOutAt)}',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: AppColors.muted),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: _busy || isDone
                                    ? null
                                    : (isClockedIn ? _clockOut : _clockIn),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isClockedIn
                                      ? AppColors.error
                                      : AppColors.successDark,
                                ),
                                icon: _busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : Icon(isClockedIn
                                        ? Icons.logout_rounded
                                        : Icons.login_rounded),
                                label: Text(isDone
                                    ? 'Absen Selesai'
                                    : (isClockedIn
                                        ? 'Absen Pulang'
                                        : 'Absen Masuk')),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_recent.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text('Riwayat Terakhir', style: textTheme.titleSmall),
                      const SizedBox(height: 8),
                      ..._recent.map((d) => Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              title: Text(d.date),
                              subtitle: Text(
                                  'Masuk ${_time(d.clockInAt)} • Pulang ${_time(d.clockOutAt)}'),
                              trailing: d.underHours
                                  ? const Chip(
                                      label: Text('Kurang Jam'),
                                      backgroundColor: AppColors.errorLight,
                                      labelStyle: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.errorDark),
                                    )
                                  : null,
                            ),
                          )),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
