import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/staff_attendance_model.dart';
import '../models/staff_model.dart';
import '../services/staff_api.dart';
import '../utils/responsive.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';

/// Menu penjual: Absen Staff. Pilih staff -> lihat riwayat kehadiran 1
/// bulan (jam masuk/pulang/total jam, ditandai kalau kurang dari jam kerja
/// standar). Jam kerja standar bersifat GLOBAL untuk semua staff milik
/// owner ini (bukan per-staff individual).
class StaffAttendanceScreen extends StatefulWidget {
  const StaffAttendanceScreen({super.key});

  @override
  State<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  final _api = StaffApi();
  List<StaffRow> _staff = [];
  bool _loadingStaff = true;
  StaffRow? _selected;
  bool _loadingAttendance = false;
  List<AttendanceDay> _days = [];
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int? _workHours;
  bool _savingWorkHours = false;

  @override
  void initState() {
    super.initState();
    _loadStaff();
    _loadWorkHours();
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

  Future<void> _loadWorkHours() async {
    try {
      final resp = await _api.getWorkHours();
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (mounted) {
          setState(() => _workHours = (body['data']?['hours'] ?? 8) as int);
        }
      }
    } catch (_) {}
  }

  Future<void> _setWorkHours() async {
    final controller =
        TextEditingController(text: (_workHours ?? 8).toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Jam Kerja Standar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Berlaku untuk SEMUA staff, bukan cuma yang sedang dipilih.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jam per hari',
                suffixText: 'jam',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dc, true),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    final hours = int.tryParse(controller.text.trim());
    if (hours == null || hours <= 0 || hours > 24) {
      if (mounted) Toast.error(context, 'Jam kerja harus antara 1-24');
      return;
    }
    setState(() => _savingWorkHours = true);
    try {
      final resp = await _api.setWorkHours(hours);
      if (resp.statusCode == 200) {
        setState(() => _workHours = hours);
        if (mounted) Toast.success(context, 'Jam kerja standar diperbarui');
        if (_selected != null) await _loadAttendance();
      } else {
        if (mounted) Toast.error(context, 'Gagal menyimpan');
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _savingWorkHours = false);
    }
  }

  Future<void> _selectStaff(StaffRow s) async {
    setState(() => _selected = s);
    await _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    final s = _selected;
    if (s == null) return;
    setState(() => _loadingAttendance = true);
    try {
      final monthStr =
          '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}';
      final resp = await _api.getAttendance(s.goldId, monthStr);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _days = ((body['data'] ?? []) as List)
            .map((e) => AttendanceDay.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingAttendance = false);
  }

  Future<void> _changeMonth(int delta) async {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    await _loadAttendance();
  }

  String _time(String? ts) {
    if (ts == null || ts.isEmpty) return '-';
    final parts = ts.split(' ');
    return parts.length > 1 ? parts[1].substring(0, 5) : ts;
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final monthLabel = _month.month.toString().padLeft(2, '0');
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: AppBarCustom(
          title: 'Absen Staff',
          actions: [
            IconButton(
              tooltip: 'Jam Kerja Standar',
              icon: const Icon(Icons.timer_outlined),
              onPressed: _savingWorkHours ? null : _setWorkHours,
            ),
          ],
        ),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<int>(
                                initialValue: _selected?.goldId,
                                decoration: const InputDecoration(
                                  labelText: 'Pilih Staff',
                                  prefixIcon:
                                      Icon(Icons.person_outline_rounded),
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
                                  final s = _staff
                                      .firstWhere((s) => s.goldId == id);
                                  _selectStaff(s);
                                },
                              ),
                              if (_workHours != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.infoLight,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md),
                                    ),
                                    child: Text(
                                      'Jam kerja standar saat ini: $_workHours jam/hari (berlaku untuk semua staff).',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.infoDark),
                                    ),
                                  ),
                                ),
                              if (_selected != null) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                          Icons.chevron_left_rounded),
                                      onPressed: () => _changeMonth(-1),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${_month.year}-$monthLabel',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.chevron_right_rounded),
                                      onPressed: () => _changeMonth(1),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_selected != null)
                          Expanded(
                            child: _loadingAttendance
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : ListView.builder(
                                    padding:
                                        EdgeInsets.fromLTRB(pad, 0, pad, pad),
                                    itemCount: _days.length,
                                    itemBuilder: (context, i) {
                                      final d = _days[i];
                                      final isHadir = d.status == 'hadir';
                                      return Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 6),
                                        child: ListTile(
                                          dense: true,
                                          title: Text(d.date),
                                          subtitle: isHadir
                                              ? Text(
                                                  'Masuk ${_time(d.clockInAt)} • Pulang ${_time(d.clockOutAt)}'
                                                  '${d.workHours != null ? ' • ${d.workHours!.toStringAsFixed(1)} jam' : ''}')
                                              : const Text('Tidak masuk'),
                                          trailing: !isHadir
                                              ? const Chip(
                                                  label:
                                                      Text('Tidak Masuk'),
                                                  backgroundColor:
                                                      AppColors.chipBg,
                                                  labelStyle: TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors.muted),
                                                )
                                              : d.underHours
                                                  ? const Chip(
                                                      label: Text(
                                                          'Kurang Jam Kerja'),
                                                      backgroundColor:
                                                          AppColors.errorLight,
                                                      labelStyle: TextStyle(
                                                          fontSize: 11,
                                                          color: AppColors
                                                              .errorDark),
                                                    )
                                                  : const Chip(
                                                      label: Text('Hadir'),
                                                      backgroundColor:
                                                          AppColors
                                                              .successLight,
                                                      labelStyle: TextStyle(
                                                          fontSize: 11,
                                                          color: AppColors
                                                              .successDark),
                                                    ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
