import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/seller_access_model.dart';
import '../services/core_api.dart';
import '../services/seller_access_api.dart';
import '../utils/responsive.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/page_header.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// Layar ADMIN: atur mode pendaftaran mandiri di layar "Daftar Akun"
/// (register_screen.dart) — pembeli saja, penjual saja, atau tetap bisa
/// memilih keduanya (perilaku default).
class AdminRegistrationModeScreen extends StatefulWidget {
  const AdminRegistrationModeScreen({super.key});

  @override
  State<AdminRegistrationModeScreen> createState() =>
      _AdminRegistrationModeScreenState();
}

class _AdminRegistrationModeScreenState
    extends State<AdminRegistrationModeScreen> {
  final _coreApi = CoreApi();
  final _sellerAccessApi = SellerAccessApi();
  String _mode = 'BOTH';
  bool _loading = true;
  bool _saving = false;
  // 2026-10-10: "Daftar Akun" (mode global pendaftaran) dan "Akses Daftar Pembeli" (per-penjual)
  // sama-sama soal pendaftaran pembeli -- kalau mode global MENGIZINKAN pembeli (BOTH/BUYER_ONLY)
  // tapi ada penjual dengan akses Daftar Pembeli mati (atau sebaliknya, mode SELLER_ONLY tapi ada
  // penjual yang aksesnya masih nyala), tandai sebagai tidak sinkron -- murni informasi.
  List<SellerMenuAccessRow> _sellerRows = [];

  List<int> _distinctSellerIds(List<SellerMenuAccessRow> rows) {
    final seen = <int>{};
    for (final r in rows) {
      seen.add(r.outletGoldId);
    }
    return seen.toList();
  }

  int get _mismatchedSellerCount {
    final buyerAllowed = _mode == 'BOTH' || _mode == 'BUYER_ONLY';
    var mismatched = 0;
    for (final goldId in _distinctSellerIds(_sellerRows)) {
      final access = _sellerRows.firstWhere((r) => r.outletGoldId == goldId);
      if (access.daftarPembeliActive != buyerAllowed) mismatched++;
    }
    return mismatched;
  }

  static const _options = [
    (
      'BOTH',
      'Bisa memilih keduanya',
      'Pengguna memilih sendiri: pembeli atau penjual',
      Icons.people_alt_outlined,
    ),
    (
      'BUYER_ONLY',
      'Pembeli saja',
      'Pendaftaran mandiri hanya membuat akun pembeli',
      Icons.shopping_bag_outlined,
    ),
    (
      'SELLER_ONLY',
      'Penjual saja',
      'Pendaftaran mandiri hanya membuat akun penjual',
      Icons.storefront_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    String mode = _mode;
    try {
      final resp = await _coreApi.getRegistrationMode();
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        mode = (body['data']?['mode'] ?? 'BOTH') as String;
      } else if (mounted) {
        Toast.error(context, 'Gagal memuat pengaturan, memakai default');
      }
    } catch (_) {
      if (mounted) {
        Toast.error(context, 'Gagal memuat pengaturan, memakai default');
      }
    }
    await _loadSellerRows();
    if (mounted) setState(() => _mode = mode);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSellerRows() async {
    try {
      final resp = await _sellerAccessApi.getList('');
      if (resp.statusCode != 200) return;
      final body = jsonDecode(resp.body);
      final rows = ((body['data'] ?? []) as List)
          .map((e) => SellerMenuAccessRow.fromJson(e))
          .toList();
      if (mounted) setState(() => _sellerRows = rows);
    } catch (_) {
      // gagal muat -- banner tidak tampil, tidak memblokir layar utama
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final resp = await _coreApi.updateRegistrationMode(_mode);
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
    final textTheme = Theme.of(context).textTheme;
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Daftar Akun'),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : PageBody(
                maxWidth: 760,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PageHeader(
                      title: 'Daftar Akun',
                      subtitle:
                          'Atur siapa yang boleh mendaftar sendiri lewat layar '
                          '"Daftar Akun" (tanpa OTP).',
                      icon: Icons.how_to_reg_rounded,
                    ),
                    if (_mismatchedSellerCount > 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 18, color: AppColors.warningDark),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$_mismatchedSellerCount akun penjual tidak sinkron dengan mode pendaftaran saat ini. '
                                'Cek menu "Akses Daftar Pembeli".',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.warningDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SectionCard(
                      title: 'Mode pendaftaran',
                      icon: Icons.tune_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (value, title, subtitle, icon) in _options)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ModeOption(
                                selected: _mode == value,
                                title: title,
                                subtitle: subtitle,
                                icon: icon,
                                onTap: () => setState(() => _mode = value),
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
                    const SizedBox(height: 12),
                    Text(
                      'Perubahan langsung berlaku untuk layar Daftar Akun '
                      'tanpa perlu update aplikasi.',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeOption({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: selected ? AppColors.blueLight : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.blue : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.blue : AppColors.disabled,
              ),
              const SizedBox(width: 10),
              Icon(icon,
                  size: 20, color: selected ? AppColors.blue : AppColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleSmall),
                    Text(subtitle, style: textTheme.bodySmall),
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
