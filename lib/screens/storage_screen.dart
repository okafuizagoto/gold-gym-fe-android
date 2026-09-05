import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/storage_model.dart';
import '../services/storage_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// Menu Storage: ringkasan pemakaian + daftar foto (item katalog & bukti
/// pembayaran) milik user yang login, dengan aksi hapus per foto. TIDAK
/// tersedia untuk role ADMIN (admin tidak punya kuota storage).
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  final _storageApi = StorageApi();

  bool _isAdmin = false;
  bool _loading = true;
  StorageSummary? _summary;
  Map<String, String> _photoHeaders = {};
  int? _deletingSourceId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final role = await Storage.get(AppConstants.userRoleKey) ?? '';
    if (role == AppConstants.roleAdmin) {
      if (mounted) {
        setState(() {
          _isAdmin = true;
          _loading = false;
        });
      }
      return;
    }
    _photoHeaders = await _storageApi.getAuthHeaders();
    await _loadSummary();
  }

  Future<void> _loadSummary() async {
    if (mounted) setState(() => _loading = true);
    final summary = await _storageApi.getSummary();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
    if (summary == null) {
      Toast.error(context, 'Gagal memuat data penyimpanan');
    } else if (summary.entries.isEmpty) {
      Toast.info(context,
          'Penyimpanan Anda masih kosong — belum ada foto yang tersimpan.');
    }
  }

  Future<void> _confirmDelete(StorageEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Foto'),
        content: Text(
            'Foto "${entry.contextText}" akan dihapus permanen dari penyimpanan Anda. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deletingSourceId = entry.sourceId);
    try {
      final response =
          await _storageApi.deleteEntry(entry.sourceType, entry.sourceId);
      if (!mounted) return;
      if (response.statusCode == 200) {
        Toast.success(context, 'Foto berhasil dihapus');
        await _loadSummary();
      } else {
        Toast.error(context, 'Gagal menghapus foto');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal menghapus foto');
    } finally {
      if (mounted) setState(() => _deletingSourceId = null);
    }
  }

  void _showPreview(StorageEntry entry) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: InteractiveViewer(
          child: Image.network(
            _storageApi.photoUrl(entry),
            headers: _photoHeaders,
            errorBuilder: (context, error, stack) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Foto tidak tersedia saat ini.'),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Storage'),
        drawer: const AppDrawer(),
        body: _isAdmin
            ? const SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Menu ini tidak tersedia untuk admin',
                  description: 'Admin tidak memiliki kuota penyimpanan foto.',
                ),
              )
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final summary = _summary;
    if (summary == null) {
      return SingleChildScrollView(
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Gagal memuat data penyimpanan',
          description: 'Periksa koneksi internet Anda lalu coba lagi.',
          action: ElevatedButton.icon(
            onPressed: _loadSummary,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba lagi'),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: ListView(
        padding: context.pageInsets,
        children: [
          ContentWidth(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummaryCard(summary),
                const SizedBox(height: 16),
                if (summary.entries.isEmpty)
                  const EmptyState(
                    icon: Icons.photo_library_outlined,
                    title: 'Belum ada foto tersimpan',
                    description:
                        'Foto item katalog dan bukti pembayaran yang Anda unggah akan tampil di sini.',
                  )
                else
                  ...summary.entries.map((e) => _buildEntryCard(e)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(StorageSummary summary) {
    final textTheme = Theme.of(context).textTheme;
    final fraction = summary.usedFraction;
    final color = fraction >= 1
        ? AppColors.error
        : fraction >= 0.8
            ? AppColors.warning
            : AppColors.blue;
    return SectionCard(
      title: 'Penyimpanan Terpakai',
      icon: Icons.sd_storage_outlined,
      action: Text(
        '${(fraction * 100).toStringAsFixed(0)}%',
        style: textTheme.titleLarge?.copyWith(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppColors.chipBg,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${summary.usedMb.toStringAsFixed(2)} MB dari ${summary.quotaMb.toStringAsFixed(0)} MB terpakai',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(StorageEntry entry) {
    final textTheme = Theme.of(context).textTheme;
    final sizeLabel = entry.sizeKb / 1024 < 1
        ? '${entry.sizeKb} KB'
        : '${(entry.sizeKb / 1024).toStringAsFixed(2)} MB';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
        child: Row(
          children: [
            InkWell(
              onTap: () => _showPreview(entry),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Image.network(
                  _storageApi.photoUrl(entry),
                  headers: _photoHeaders,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    width: 56,
                    height: 56,
                    color: AppColors.chipBg,
                    child: const Icon(Icons.image_not_supported_outlined,
                        color: AppColors.muted),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.contextText,
                    style: textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(sizeLabel, style: textTheme.bodySmall),
                ],
              ),
            ),
            _deletingSourceId == entry.sourceId
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Hapus',
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.error),
                    onPressed: () => _confirmDelete(entry),
                  ),
          ],
        ),
      ),
    );
  }
}
