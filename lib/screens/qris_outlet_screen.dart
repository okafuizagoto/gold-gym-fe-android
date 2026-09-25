import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';
import '../models/outlet_model.dart';
import '../services/core_api.dart';
import '../services/outlet_api.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// QRIS Outlet (2026-09-25): menggantikan QrisSayaScreen -- satu penjual bisa punya banyak
/// outlet, tiap outlet SATU foto kode QRIS statis sendiri, ditampilkan ke pembeli lewat tombol
/// "Tampilkan QRIS" di penjualan_screen.dart saat metode bayar Transfer Bank (tetap tercatat
/// sebagai transfer bank, bukan metode terpisah). Padanan pages/qris-outlet (Next.js).
class QrisOutletScreen extends StatefulWidget {
  const QrisOutletScreen({super.key});

  @override
  State<QrisOutletScreen> createState() => _QrisOutletScreenState();
}

class _QrisOutletScreenState extends State<QrisOutletScreen> {
  final _coreApi = CoreApi();
  final _outletApi = OutletsApi();
  bool _loading = true;
  List<OutletResponse> _outlets = [];
  String? _outletCode;
  String? _currentUrl;
  File? _newFile;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    setState(() => _loading = true);
    try {
      final resp = await _outletApi.getAllOutlet('', 'ACTIVE', 0, 0);
      if (resp.statusCode == 200) {
        final pagination =
            OutletPagination.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
        _outlets = pagination.data;
        if (_outlets.isNotEmpty) _outletCode = _outlets.first.outlet_code;
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memuat daftar outlet');
    }
    if (_outletCode != null) await _loadPhoto(_outletCode!);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadPhoto(String code) async {
    final url = await _coreApi.getOutletQrisPhotoUrl(code);
    if (mounted) {
      setState(() {
        _currentUrl = url;
        _newFile = null;
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
    if (_newFile == null || _outletCode == null) return;
    setState(() => _saving = true);
    try {
      final resp = await _coreApi.uploadOutletQrisPhoto(_outletCode!, _newFile!);
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        if (mounted) Toast.success(context, 'Foto QRIS outlet tersimpan');
        await _loadPhoto(_outletCode!);
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
    if (_outletCode == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus foto QRIS outlet?'),
        content: const Text(
            'Pembeli tidak akan bisa lagi melihat kode QRIS outlet ini di POS.'),
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
      final resp = await _coreApi.deleteOutletQrisPhoto(_outletCode!);
      if (resp.statusCode == 200) {
        if (mounted) Toast.success(context, 'Foto QRIS outlet dihapus');
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
        appBar: const AppBarCustom(title: 'QRIS Outlet'),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _outlets.isEmpty
                ? const Center(child: Text('Belum ada outlet aktif. Buat outlet dulu di menu Outlet.'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionCard(
                          title: 'Pilih outlet',
                          icon: Icons.qr_code_2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _outletCode,
                            items: _outlets
                                .map((o) => DropdownMenuItem(
                                    value: o.outlet_code, child: Text(o.outlet_name)))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _outletCode = v);
                              _loadPhoto(v);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
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
                                          _deleting ? 'Menghapus...' : 'Hapus foto QRIS outlet ini',
                                          style: const TextStyle(color: AppColors.error)),
                                    ),
                                  ],
                                )
                              : const Text('Outlet ini belum menyimpan foto QRIS.'),
                        ),
                        const SizedBox(height: 16),
                        SectionCard(
                          title: _currentUrl != null ? 'Ganti foto QRIS' : 'Upload foto QRIS',
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
