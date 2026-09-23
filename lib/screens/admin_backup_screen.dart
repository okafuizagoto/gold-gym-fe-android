import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/backup_model.dart';
import '../services/api_client.dart';
import '../services/backup_api.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// Admin: riwayat backup harian otomatis (mysqldump -> gzip -> B2, jadwal
/// 02:00 WIB) + trigger manual + download presigned URL. Padanan
/// pages/admin-backup (Next.js).
class AdminBackupScreen extends StatefulWidget {
  const AdminBackupScreen({super.key});

  @override
  State<AdminBackupScreen> createState() => _AdminBackupScreenState();
}

class _AdminBackupScreenState extends State<AdminBackupScreen> {
  final _backupApi = BackupApi();
  bool _loading = true;
  bool _forbidden = false;
  bool _running = false;
  List<BackupRecord> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // KOREKSI 2026-09-18 (QA audit #1.1): dulu tidak ada try/catch sama
  // sekali -- exception (timeout, jsonDecode gagal, SessionExpired) tidak
  // pernah tertangkap, layar macet permanen di spinner karena
  // `_loading=false` tidak pernah tercapai.
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _backupApi.list();
      if (mounted) {
        setState(() {
          _rows = rows;
          _forbidden = false;
        });
      }
    } on ForbiddenException {
      if (mounted) setState(() => _forbidden = true);
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal memuat riwayat backup: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // KOREKSI 2026-09-18 (QA audit #1.2): dulu tidak ada try/catch -- kalau
  // `runNow()` melempar exception, `_running` tidak pernah kembali false,
  // tombol "Backup Sekarang" terkunci spinner selamanya tanpa toast.
  Future<void> _runNow() async {
    setState(() => _running = true);
    try {
      final rec = await _backupApi.runNow();
      if (mounted) {
        if (rec != null && rec.status == BackupRecord.statusSuccess) {
          Toast.success(context, 'Backup berhasil (${rec.sizeLabel})');
        } else if (rec != null) {
          Toast.error(context, 'Backup gagal: ${rec.errorMessage}');
        } else {
          Toast.error(context, 'Gagal menjalankan backup');
        }
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal menjalankan backup: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
    await _load();
  }

  Future<void> _download(BackupRecord r) async {
    final url = await _backupApi.downloadUrl(r.backupId);
    if (url == null) {
      if (mounted) Toast.error(context, 'Gagal mengambil link unduhan');
      return;
    }
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal membuka link unduhan');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Backup Data Harian'),
        drawer: const AppDrawer(),
        body: _forbidden
            ? const EmptyState(icon: Icons.backup_outlined, title: 'Khusus admin')
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        SectionCard(
                          title: 'Backup otomatis',
                          icon: Icons.backup_outlined,
                          description:
                              'Berjalan otomatis tiap hari jam 02:00 WIB. Retensi 30 hari.',
                          action: ElevatedButton.icon(
                            onPressed: _running ? null : _runNow,
                            icon: _running
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.play_arrow_rounded, size: 18),
                            label: Text(_running ? '...' : 'Backup Sekarang'),
                          ),
                          child: const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Riwayat Backup',
                          icon: Icons.history_rounded,
                          child: _rows.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text('Belum ada riwayat backup.'),
                                )
                              : Column(
                                  children: _rows.map(_row).toList(),
                                ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _row(BackupRecord r) {
    final ok = r.status == BackupRecord.statusSuccess;
    final created = r.createdAt == null
        ? '-'
        : DateFormat('d MMM yyyy HH:mm', 'id_ID').format(r.createdAt!);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: ok ? AppColors.successLight : AppColors.errorLight,
        child: Icon(
          ok ? Icons.check_rounded : Icons.close_rounded,
          size: 18,
          color: ok ? AppColors.successDark : AppColors.error,
        ),
      ),
      title: Text('${r.environment.toUpperCase()} · ${r.sizeLabel}'),
      subtitle: Text(
        ok ? created : '$created\n${r.errorMessage}',
      ),
      isThreeLine: !ok && r.errorMessage.isNotEmpty,
      trailing: ok
          ? IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Unduh',
              onPressed: () => _download(r),
            )
          : null,
    );
  }
}
