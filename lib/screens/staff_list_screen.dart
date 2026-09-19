import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/staff_model.dart';
import '../services/staff_api.dart';
import '../utils/responsive.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';

/// Menu penjual: Daftar Staff. Registrasi akun staff (dibawahi owner, akses
/// menu diatur lewat menu "Akses Staff") + daftar staff yang sudah terdaftar.
class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  final _api = StaffApi();
  List<StaffRow> _staff = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await _api.list();
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _staff = ((body['data'] ?? []) as List)
            .map((e) => StaffRow.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _register() async {
    final namaC = TextEditingController();
    final emailC = TextEditingController();
    final hpC = TextEditingController();
    final passC = TextEditingController();
    bool obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (dc, setDialogState) => AlertDialog(
          title: const Text('Daftarkan Staff'),
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          content: SizedBox(
            width: dc.dialogMaxWidth(440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: namaC,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap *',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailC,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hpC,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor HP',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passC,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      helperText: 'Minimal 6 karakter',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dc, false),
                child: const Text('Batal')),
            ElevatedButton(
                onPressed: () => Navigator.pop(dc, true),
                child: const Text('Daftarkan')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    if (namaC.text.trim().isEmpty ||
        !emailC.text.contains('@') ||
        passC.text.length < 6) {
      if (mounted) {
        Toast.error(context,
            'Lengkapi nama & email, password minimal 6 karakter.');
      }
      return;
    }

    try {
      final resp = await _api.register(
        nama: namaC.text.trim(),
        email: emailC.text.trim(),
        password: passC.text,
        nomorHp: hpC.text.trim(),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (mounted) Toast.success(context, 'Staff berhasil didaftarkan');
        await _load();
      } else {
        _showErr(resp.body);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal: $e');
    }
  }

  void _showErr(String body) {
    String msg = 'Gagal menyimpan';
    try {
      msg = jsonDecode(body)['error'] ?? msg;
    } catch (_) {}
    if (mounted) Toast.error(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final textTheme = Theme.of(context).textTheme;
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: AppBarCustom(
          title: 'Daftar Staff',
          actions: [
            IconButton(
              tooltip: 'Muat ulang',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _load,
            ),
          ],
        ),
        drawer: const AppDrawer(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _register,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Daftarkan Staff'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _staff.isEmpty
                ? ListView(
                    children: const [
                      EmptyState(
                        icon: Icons.badge_outlined,
                        title: 'Belum ada staff',
                        description:
                            'Daftarkan akun staff lewat tombol di kanan bawah. '
                            'Atur menu yang boleh diakses lewat menu "Akses Staff".',
                      ),
                    ],
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ContentWidth(
                      child: ListView.builder(
                        padding: EdgeInsets.fromLTRB(pad, pad, pad, 96),
                        itemCount: _staff.length,
                        itemBuilder: (context, i) {
                          final s = _staff[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.blueLight,
                                child: Text(
                                  s.nama.isNotEmpty
                                      ? s.nama[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: AppColors.blue,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              title: Text(s.nama.isEmpty ? '-' : s.nama,
                                  style: textTheme.titleSmall),
                              subtitle: Text(
                                [
                                  s.email,
                                  if (s.nomorHp.isNotEmpty) s.nomorHp,
                                ].join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
      ),
    );
  }
}
