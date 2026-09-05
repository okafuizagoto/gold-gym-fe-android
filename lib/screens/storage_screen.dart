import 'package:flutter/material.dart';
import '../models/storage_model.dart';
import '../services/storage_api.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

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
      if (mounted) setState(() { _isAdmin = true; _loading = false; });
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
      Toast.info(context, 'Penyimpanan Anda masih kosong — belum ada foto yang tersimpan.');
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Menu ini tidak tersedia untuk admin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
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
      return Center(
        child: TextButton(
          onPressed: _loadSummary,
          child: const Text('Coba lagi'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(summary),
          const SizedBox(height: 16),
          if (summary.entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'Belum ada foto tersimpan.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...summary.entries.map((e) => _buildEntryCard(e)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(StorageSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Penyimpanan Terpakai',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                Text(
                  '${(summary.usedFraction * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: summary.usedFraction >= 1
                        ? Colors.red
                        : summary.usedFraction >= 0.8
                            ? Colors.orange
                            : Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: summary.usedFraction,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                color: summary.usedFraction >= 1
                    ? Colors.red
                    : summary.usedFraction >= 0.8
                        ? Colors.orange
                        : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${summary.usedMb.toStringAsFixed(2)} MB dari ${summary.quotaMb.toStringAsFixed(0)} MB terpakai',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(StorageEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _showPreview(entry),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _storageApi.photoUrl(entry),
                  headers: _photoHeaders,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    width: 56,
                    height: 56,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported,
                        color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(entry.contextText,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${entry.sizeKb / 1024 < 1 ? entry.sizeKb : (entry.sizeKb / 1024).toStringAsFixed(2)} '
                      '${entry.sizeKb / 1024 < 1 ? "KB" : "MB"}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            _deletingSourceId == entry.sourceId
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(entry),
                  ),
          ],
        ),
      ),
    );
  }
}
