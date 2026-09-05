import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/core_api.dart';
import '../utils/toast.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

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
  String _mode = 'BOTH';
  bool _loading = true;
  bool _saving = false;

  static const _options = [
    ('BOTH', 'Bisa memilih keduanya', 'Pengguna memilih sendiri: pembeli atau penjual'),
    ('BUYER_ONLY', 'Pembeli saja', 'Pendaftaran mandiri hanya membuat akun pembeli'),
    ('SELLER_ONLY', 'Penjual saja', 'Pendaftaran mandiri hanya membuat akun penjual'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await _coreApi.getRegistrationMode();
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final mode = (body['data']?['mode'] ?? 'BOTH') as String;
        if (mounted) setState(() => _mode = mode);
      } else if (mounted) {
        Toast.error(context, 'Gagal memuat pengaturan, memakai default');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memuat pengaturan, memakai default');
    }
    if (mounted) setState(() => _loading = false);
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
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Daftar Akun')),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Atur siapa yang boleh mendaftar sendiri lewat layar '
                      '"Daftar Akun" (tanpa OTP).',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),
                    for (final (value, title, subtitle) in _options)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => setState(() => _mode = value),
                          leading: Icon(
                            _mode == value
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: _mode == value ? Colors.green.shade600 : null,
                          ),
                          title: Text(title,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(subtitle),
                        ),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Menyimpan...' : 'SIMPAN'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
