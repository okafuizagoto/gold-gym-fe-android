import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/staff_model.dart';
import '../services/staff_api.dart';
import 'package:flutter/services.dart';
import '../utils/password_generator.dart';
import '../utils/password_strength.dart';
import '../utils/responsive.dart';
import '../utils/staff_menu_keys.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/password_strength_bar.dart';
import '../widgets/private_route.dart';
import '../widgets/tour_target.dart';
import '../utils/tour_demo.dart';

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

    // Menu yang DITOLAK untuk staff baru (centang = boleh). Awal dari template server; pilihan disimpan server
    // sebagai template pendaftaran staff berikutnya.
    final denied = <String>{};
    try {
      final tr = await _api.getMenuTemplate();
      if (tr.statusCode == 200) {
        final keys = (jsonDecode(tr.body)['data']?['denied_menu_keys']) as List?;
        if (keys != null) denied.addAll(keys.map((e) => e.toString()));
      }
    } catch (_) {}
    if (!mounted) return;

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
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      helperText: 'Minimal 6 karakter, huruf besar, huruf kecil, dan angka',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                          label: const Text('Buat password acak'),
                          onPressed: () => setDialogState(() {
                            passC.text = generatePassword(12);
                            obscure = false;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Salin'),
                        onPressed: passC.text.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                    ClipboardData(text: passC.text));
                                if (dc.mounted) {
                                  Toast.success(dc,
                                      'Password disalin. Berikan ke staff; staff wajib menggantinya setelah verifikasi email.');
                                }
                              },
                      ),
                    ],
                  ),
                  PasswordStrengthBar(password: passC.text),
                  const SizedBox(height: 8),
                  const Text(
                    'Tautan verifikasi akan dikirim ke email staff; pastikan email aktif dan bisa dibuka staff.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  const Text('Menu yang boleh diakses staff',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text(
                    'Menu sensitif (refund, kas history, tarik kas, tambah kas, outlet, lokasi kantor, meja & area) tidak dicentang secara default. '
                    'Pilihan Anda diingat untuk pendaftaran staff berikutnya dan bisa diubah kapan saja lewat Akses Staff.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  for (final opt in StaffMenuKeys.options)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(opt.label, style: const TextStyle(fontSize: 13)),
                      value: !denied.contains(opt.key),
                      onChanged: (v) => setDialogState(() {
                        if (v == true) {
                          denied.remove(opt.key);
                        } else {
                          denied.add(opt.key);
                        }
                      }),
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

    if (namaC.text.trim().isEmpty || !emailC.text.contains('@')) {
      if (mounted) Toast.error(context, 'Lengkapi nama & email.');
      return;
    }
    if (!evaluatePassword(passC.text).valid) {
      if (mounted) Toast.error(context, passwordPolicyMessage);
      return;
    }

    try {
      final resp = await _api.register(
        nama: namaC.text.trim(),
        email: emailC.text.trim(),
        password: passC.text,
        nomorHp: hpC.text.trim(),
        deniedMenuKeys: StaffMenuKeys.options
            .map((o) => o.key)
            .where(denied.contains)
            .toList(),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (mounted) {
          Toast.success(context,
              'Staff berhasil didaftarkan. Tautan verifikasi dikirim ke email staff; staff harus memverifikasi email sebelum bisa masuk.');
        }
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
        floatingActionButton: TourTarget(
          id: 'staff-add',
          child: FloatingActionButton.extended(
            onPressed: _register,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Daftarkan Staff'),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _staff.isEmpty
                ? ListView(
                    children: [
                      TourDemo.when(
                        demo: () => const TourDemoBlock(
                          child: Card(
                            child: ListTile(
                              leading: CircleAvatar(child: Text('S')),
                              title: Text('Staff Contoh',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('staff.contoh@email.com'),
                            ),
                          ),
                        ),
                        normal: () => const EmptyState(
                          icon: Icons.badge_outlined,
                          title: 'Belum ada staff',
                          description:
                              'Daftarkan akun staff lewat tombol di kanan bawah. '
                              'Atur menu yang boleh diakses lewat menu "Akses Staff".',
                        ),
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
