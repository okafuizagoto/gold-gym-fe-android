import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/core_api.dart';
import '../utils/responsive.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/page_header.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// Layar ADMIN: hide/unhide "Jasa Terapi & Spa" dari daftar Tipe Outlet (form
/// Tambah Outlet, web & Android). TIDAK memblokir outlet THERAPY yang sudah
/// ada -- cuma menyembunyikan opsinya untuk outlet baru.
class AdminOutletTypeSettingsScreen extends StatefulWidget {
  const AdminOutletTypeSettingsScreen({super.key});

  @override
  State<AdminOutletTypeSettingsScreen> createState() =>
      _AdminOutletTypeSettingsScreenState();
}

class _AdminOutletTypeSettingsScreenState
    extends State<AdminOutletTypeSettingsScreen> {
  final _coreApi = CoreApi();
  bool _therapyVisible = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await _coreApi.getOutletTypeSettings();
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final visible = body['data']?['therapyVisible'];
        if (mounted) setState(() => _therapyVisible = visible != false);
      } else if (mounted) {
        Toast.error(context, 'Gagal memuat pengaturan, memakai default');
      }
    } catch (_) {
      if (mounted) {
        Toast.error(context, 'Gagal memuat pengaturan, memakai default');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final resp = await _coreApi.updateOutletTypeSettings(_therapyVisible);
      if (resp.statusCode == 200) {
        if (mounted) Toast.success(context, 'Pengaturan tersimpan');
      } else {
        String msg = 'Gagal menyimpan';
        try {
          msg = jsonDecode(resp.body)['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Tipe Outlet'),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : PageBody(
                maxWidth: 760,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PageHeader(
                      title: 'Tipe Outlet',
                      subtitle:
                          'Atur opsi "Jasa Terapi & Spa" di form Tambah Outlet '
                          '(web & Android).',
                      icon: Icons.category_rounded,
                    ),
                    SectionCard(
                      title: 'Jasa Terapi & Spa',
                      icon: Icons.spa_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchListTile(
                            value: _therapyVisible,
                            onChanged: (v) =>
                                setState(() => _therapyVisible = v),
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                                'Tampilkan "Jasa Terapi & Spa" di Tipe Outlet'),
                            subtitle: Text(
                              _therapyVisible
                                  ? 'Seller bisa memilih tipe ini saat daftar outlet baru -- otomatis mengaktifkan fitur Booking Terapi untuk outlet tersebut.'
                                  : 'Opsi disembunyikan dari daftar. Outlet THERAPY yang SUDAH ADA tidak terpengaruh -- Booking Terapi tetap jalan untuk mereka. Seller baru tidak bisa membuat outlet THERAPY lagi lewat UI sampai diaktifkan kembali.',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.save_outlined, size: 20),
                              label: Text(_saving ? 'Menyimpan...' : 'SIMPAN'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.successDark,
                              ),
                              onPressed: _saving ? null : _save,
                            ),
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
