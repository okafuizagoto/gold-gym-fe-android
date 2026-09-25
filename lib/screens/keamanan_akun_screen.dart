import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../providers/language_provider.dart';
import '../services/account_api.dart';
import '../services/twofa_api.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/page_header.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// Verifikasi 2 langkah (TOTP). Padanan pages/keamanan-akun/index.tsx (Next.js).
class KeamananAkunScreen extends StatefulWidget {
  const KeamananAkunScreen({super.key});

  @override
  State<KeamananAkunScreen> createState() => _KeamananAkunScreenState();
}

class _KeamananAkunScreenState extends State<KeamananAkunScreen> {
  final _api = TwoFaApi();
  final _code = TextEditingController();
  Map<String, dynamic>? _st;
  Map<String, dynamic>? _setup;
  List<String>? _recovery;
  bool _busy = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _load();
    Storage.get(AppConstants.userRoleKey).then((r) {
      if (mounted) setState(() => _isAdmin = r == AppConstants.roleAdmin);
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final lang = context.read<LanguageProvider>();
    try {
      final res = await _api.status();
      if (res.statusCode == 200 && mounted) {
        setState(() =>
            _st = Map<String, dynamic>.from(jsonDecode(res.body)['data']));
      } else if (mounted) {
        Toast.error(context, lang.get('Failed to load', 'Gagal memuat'));
      }
    } catch (_) {
      if (mounted)
        Toast.error(context, lang.get('Failed to load', 'Gagal memuat'));
    }
  }

  Future<void> _run(
      Future<dynamic> Function() fn, void Function(dynamic data) ok) async {
    final lang = context.read<LanguageProvider>();
    setState(() => _busy = true);
    try {
      final res = await fn();
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        ok(body['data']);
      } else if (mounted) {
        Toast.error(
            context, (body['error'] as String?) ?? lang.get('Failed', 'Gagal'));
      }
    } catch (_) {
      if (mounted) Toast.error(context, lang.get('Failed', 'Gagal'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final lang = context.read<LanguageProvider>();
    final pw = TextEditingController();
    final code = TextEditingController();
    final confirm = TextEditingController();
    final enabled = _st?['enabled'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(lang.get('Delete account?', 'Hapus akun?')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(lang.get(
                  'This permanently removes your personal data and photos. It cannot be undone.',
                  'Ini menghapus permanen data pribadi dan foto Anda. Tidak bisa dibatalkan.')),
              TextField(
                controller: pw,
                obscureText: true,
                onChanged: (_) => setD(() {}),
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (enabled)
                TextField(
                  controller: code,
                  onChanged: (_) => setD(() {}),
                  decoration: InputDecoration(
                      labelText: lang.get('2FA code or recovery code',
                          'Kode 2FA atau kode pemulihan')),
                ),
              TextField(
                controller: confirm,
                onChanged: (_) => setD(() {}),
                decoration: InputDecoration(
                    labelText: lang.get('Type HAPUS to confirm',
                        'Ketik HAPUS untuk konfirmasi')),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(lang.get('Cancel', 'Batal'))),
            TextButton(
              onPressed: pw.text.isEmpty ||
                      confirm.text != 'HAPUS' ||
                      (enabled && code.text.trim().isEmpty)
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: Text(lang.get('Delete permanently', 'Hapus permanen'),
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await AccountApi()
          .deleteAccount(pw.text, totpCode: enabled ? code.text.trim() : null);
      final body = jsonDecode(res.body);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final notice = (body['data']?['notice'] as String?);
        await Storage.clear();
        if (!mounted) return;
        Toast.success(
            context,
            notice == null
                ? lang.get('Your account has been deleted.',
                    'Akun Anda telah dihapus.')
                : notice);
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      } else {
        Toast.error(
            context,
            (body['error'] as String?) ??
                lang.get('Failed to delete account', 'Gagal menghapus akun'));
      }
    } catch (_) {
      if (mounted) {
        Toast.error(context,
            lang.get('Failed to delete account', 'Gagal menghapus akun'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final title = lang.get('Account Security', 'Keamanan Akun');
    final st = _st;
    return PrivateRoute(
      child: Scaffold(
        appBar: AppBarCustom(title: title),
        drawer: const AppDrawer(),
        body: st == null
            ? const Center(child: CircularProgressIndicator())
            : PageBody(
                maxWidth: 760,
                child: ListView(children: [
                  PageHeader(
                    title: title,
                    subtitle: lang.get(
                        'Two-step verification (2FA) with an authenticator app',
                        'Verifikasi 2 langkah (2FA) dengan aplikasi authenticator'),
                    icon: Icons.lock_person_outlined,
                  ),
                  if (st['configured'] != true)
                    Text(lang.get('2FA is not available on the server yet.',
                        '2FA belum tersedia di server.')),
                  if (_recovery != null)
                    SectionCard(
                      title: lang.get('Recovery codes (shown once)',
                          'Kode pemulihan (tampil sekali)'),
                      icon: Icons.key_outlined,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(_recovery!.join('\n'),
                                style:
                                    const TextStyle(fontFamily: 'monospace')),
                            Row(children: [
                              TextButton(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                      text: _recovery!.join('\n')));
                                  Toast.success(
                                      context, lang.get('Copied', 'Disalin'));
                                },
                                child: Text(lang.get('Copy', 'Salin')),
                              ),
                              TextButton(
                                onPressed: () =>
                                    setState(() => _recovery = null),
                                child: Text(lang.get(
                                    'I have saved them', 'Sudah saya simpan')),
                              ),
                            ]),
                          ]),
                    ),
                  if (st['configured'] == true)
                    SectionCard(
                      title:
                          '2FA: ${st['enabled'] == true ? lang.get('Active', 'Aktif') : lang.get('Inactive', 'Tidak aktif')}',
                      icon: Icons.verified_user_outlined,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (st['enabled'] == true) ...[
                              Text(
                                  '${lang.get('Recovery codes left', 'Sisa kode pemulihan')}: ${st['recovery_left']}'),
                              TextField(
                                controller: _code,
                                decoration: InputDecoration(
                                    labelText: lang.get(
                                        'Code or recovery code (to disable)',
                                        'Kode atau kode pemulihan (untuk menonaktifkan)')),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(
                                            () =>
                                                _api.disable(_code.text.trim()),
                                            (_) {
                                          Toast.success(
                                              context,
                                              lang.get('2FA disabled',
                                                  '2FA dinonaktifkan'));
                                          _code.clear();
                                          _load();
                                        }),
                                child: Text(
                                    lang.get('Disable 2FA', 'Nonaktifkan 2FA')),
                              ),
                            ] else if (_setup == null)
                              ElevatedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(
                                        () => _api.setup(),
                                        (d) => setState(() {
                                              _setup =
                                                  Map<String, dynamic>.from(d);
                                              _code.clear();
                                            })),
                                child: Text(
                                    lang.get('Enable 2FA', 'Aktifkan 2FA')),
                              )
                            else ...[
                              Text(lang.get(
                                  'Scan this QR with Google Authenticator / Authy, or enter the key manually, then type the 6-digit code.',
                                  'Pindai QR ini dengan Google Authenticator / Authy, atau masukkan kunci secara manual, lalu ketik kode 6 digit.')),
                              const SizedBox(height: 8),
                              Center(
                                child: Image.memory(
                                  base64Decode(
                                      (_setup!['qr_data_url'] as String)
                                          .split(',')
                                          .last),
                                  width: 200,
                                  height: 200,
                                ),
                              ),
                              SelectableText(_setup!['secret'] as String,
                                  style:
                                      const TextStyle(fontFamily: 'monospace')),
                              TextField(
                                controller: _code,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                    labelText: lang.get(
                                        '6-digit code', 'Kode 6 digit')),
                              ),
                              ElevatedButton(
                                onPressed: _busy ||
                                        _code.text.trim().length != 6
                                    ? null
                                    : () => _run(
                                            () =>
                                                _api.enable(_code.text.trim()),
                                            (d) {
                                          setState(() {
                                            _recovery = List<String>.from(
                                                d['recovery_codes']);
                                            _setup = null;
                                            _code.clear();
                                          });
                                          _load();
                                        }),
                                child: Text(lang.get('Confirm & activate',
                                    'Konfirmasi & aktifkan')),
                              ),
                            ],
                          ]),
                    ),
                  if (_isAdmin && st['configured'] == true)
                    SectionCard(
                      title: lang.get('Require 2FA for all admins',
                          'Wajibkan 2FA untuk semua admin'),
                      icon: Icons.admin_panel_settings_outlined,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(lang.get(
                            'Admins without 2FA cannot use admin menus. Enable 2FA on your own account first.',
                            'Admin tanpa 2FA tidak bisa memakai menu admin. Aktifkan 2FA di akun Anda dulu.')),
                        value: st['admin_required'] == true,
                        onChanged: _busy
                            ? null
                            : (v) => _run(
                                () => _api.setAdminRequired(v),
                                (d) => setState(() {
                                      st['admin_required'] =
                                          d['admin_required'] == true;
                                    })),
                      ),
                    ),
                  if (!_isAdmin)
                    SectionCard(
                      title: lang.get('Delete account', 'Hapus Akun'),
                      icon: Icons.delete_forever_outlined,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(lang.get(
                                'Permanently removes your personal data, photos, and (for sellers) outlets and staff accounts. Transaction records stay without identity.',
                                'Menghapus permanen data pribadi, foto, dan (untuk penjual) outlet serta akun staf. Catatan transaksi tetap ada tanpa identitas.')),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _busy ? null : _confirmDelete,
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red),
                              child: Text(lang.get(
                                  'Delete my account', 'Hapus akun saya')),
                            ),
                          ]),
                    ),
                ]),
              ),
      ),
    );
  }
}
