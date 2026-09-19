import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';
import '../services/core_api.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// QRIS Saya: penjual menyimpan SATU foto kode QRIS statis milik mereka
/// sendiri, ditampilkan ke pembeli saat checkout untuk di-scan manual
/// (tombol "Tampilkan QRIS" di penjualan_screen.dart). BEDA dari
/// pembayaran QRIS Midtrans otomatis -- itu tidak pernah butuh foto.
/// Padanan pages/qris-saya (Next.js).
class QrisSayaScreen extends StatefulWidget {
  const QrisSayaScreen({super.key});

  @override
  State<QrisSayaScreen> createState() => _QrisSayaScreenState();
}

class _QrisSayaScreenState extends State<QrisSayaScreen> {
  final _coreApi = CoreApi();
  bool _loading = true;
  String? _currentUrl;
  File? _newFile;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final url = await _coreApi.getQrisPhotoUrl();
    if (mounted) {
      setState(() {
        _currentUrl = url;
        _loading = false;
      });
    }
  }

  Future<void> _pick() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    final file = File(picked.path);
    final size = await file.length();
    if (size > 2 * 1024 * 1024) {
      if (mounted) Toast.error(context, 'Ukuran foto maksimal 2 MB');
      return;
    }
    setState(() => _newFile = file);
  }

  Future<void> _save() async {
    if (_newFile == null) return;
    setState(() => _saving = true);
    try {
      final resp = await _coreApi.uploadQrisPhoto(_newFile!);
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        if (mounted) Toast.success(context, 'Foto QRIS tersimpan');
        setState(() => _newFile = null);
        await _load();
      } else {
        if (mounted) Toast.error(context, 'Gagal menyimpan foto QRIS');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal menyimpan foto QRIS');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus foto QRIS?'),
        content: const Text(
            'Pembeli tidak akan bisa lagi melihat kode QRIS ini di menu POS.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _deleting = true);
    try {
      final resp = await _coreApi.deleteQrisPhoto();
      if (resp.statusCode == 200) {
        if (mounted) Toast.success(context, 'Foto QRIS dihapus');
        setState(() => _currentUrl = null);
      } else {
        if (mounted) Toast.error(context, 'Gagal menghapus foto QRIS');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal menghapus foto QRIS');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'QRIS Saya'),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionCard(
                      title: 'Kode QRIS tersimpan',
                      icon: Icons.qr_code_2,
                      child: _currentUrl != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  child: Image.network(_currentUrl!,
                                      width: 220,
                                      height: 220,
                                      fit: BoxFit.contain),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _deleting ? null : _confirmDelete,
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.error),
                                  label: Text(
                                      _deleting ? 'Menghapus...' : 'Hapus foto QRIS',
                                      style: const TextStyle(color: AppColors.error)),
                                ),
                              ],
                            )
                          : const Text('Anda belum menyimpan foto QRIS.'),
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      title: _currentUrl != null
                          ? 'Ganti foto QRIS'
                          : 'Upload foto QRIS',
                      icon: Icons.qr_code_2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_newFile != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                child: Image.file(_newFile!,
                                    width: 160, height: 160, fit: BoxFit.contain),
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: _pick,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('Pilih foto QRIS'),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: (_newFile == null || _saving) ? null : _save,
                            child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
