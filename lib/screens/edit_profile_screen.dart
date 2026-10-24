import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/account_api.dart';
import '../utils/responsive.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/page_header.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// Ubah nama akun; email dan nomor HP hanya dibaca. Padanan pages/edit-profil/index.tsx (Next.js).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _api = AccountApi();
  final _namaC = TextEditingController();
  String _saved = '';
  String _email = '';
  String _hp = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _namaC.dispose();
    super.dispose();
  }

  String get _trimmed => _namaC.text.trim().replaceAll(RegExp(r'\s+'), ' ');
  bool get _canSave =>
      _trimmed.length >= 2 &&
      _trimmed.length <= 100 &&
      _trimmed != _saved &&
      !_saving;

  Future<void> _load() async {
    final lang = context.read<LanguageProvider>();
    try {
      final res = await _api.getProfile();
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _saved = (d['nama'] as String?) ?? '';
          _namaC.text = _saved;
          _email = (d['email'] as String?) ?? '';
          _hp = (d['nomor_hp'] as String?) ?? '';
        });
      } else if (mounted) {
        Toast.error(context,
            lang.get('Failed to load profile.', 'Gagal memuat profil.'));
      }
    } catch (_) {
      if (mounted) {
        Toast.error(
            context,
            lang.get('Failed to load profile. Check your connection.',
                'Gagal memuat profil. Periksa koneksi internet Anda.'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final lang = context.read<LanguageProvider>();
    setState(() => _saving = true);
    try {
      final res = await _api.updateProfile(_trimmed);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _saved = (body['nama'] as String?) ?? _trimmed;
          _namaC.text = _saved;
        });
        Toast.success(context,
            lang.get('Profile updated.', 'Profil berhasil diperbarui.'));
      } else {
        Toast.error(
            context,
            (body['error'] as String?) ??
                lang.get(
                    'Failed to update profile.', 'Gagal memperbarui profil.'));
      }
    } catch (_) {
      if (mounted) {
        Toast.error(
            context,
            lang.get('Failed to update profile. Check your connection.',
                'Gagal memperbarui profil. Periksa koneksi internet Anda.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final title = lang.get('Edit Profile', 'Edit Profil');
    return PrivateRoute(
      child: Scaffold(
        appBar: AppBarCustom(title: title),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : PageBody(
                maxWidth: 760,
                child: Column(children: [
                  PageHeader(
                    title: title,
                    subtitle: lang.get(
                        'Change your account name', 'Ubah nama akun Anda'),
                    icon: Icons.account_circle_outlined,
                  ),
                  SectionCard(
                    title: title,
                    icon: Icons.person_outline,
                    child: Column(children: [
                      TextField(
                        controller: _namaC,
                        maxLength: 100,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [],
                        decoration: InputDecoration(
                          labelText: lang.get('Name', 'Nama'),
                          helperText:
                              lang.get('2–100 characters', '2–100 karakter'),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: ValueKey('email-$_email'),
                        initialValue: _email,
                        enabled: false,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: ValueKey('hp-$_hp'),
                        initialValue: _hp,
                        enabled: false,
                        decoration: InputDecoration(
                            labelText: lang.get('Phone number', 'Nomor HP')),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _canSave ? _save : null,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Text(lang.get('Save', 'Simpan')),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
      ),
    );
  }
}
