import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/account_api.dart';
import '../services/core_api.dart';
import '../utils/constants.dart';
import '../utils/password_strength.dart';
import '../utils/seller_outlet_gate.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/auth_card.dart';
import '../widgets/password_strength_bar.dart';

/// Wajib ganti password -- ditampilkan setelah staff yang didaftarkan penjual memverifikasi email
/// (password awal dibuat penjual). Password lama harus benar, password baru + konfirmasi harus sama, baru
/// diarahkan ke pilih outlet. Padanan pages/ganti-password/index.tsx (web). TIDAK dibungkus PrivateRoute
/// (guard itu justru mengarahkan ke sini).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _api = AccountApi();
  final _oldC = TextEditingController();
  final _newC = TextEditingController();
  final _confirmC = TextEditingController();
  bool _show = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _requireSession();
  }

  Future<void> _requireSession() async {
    final token = await Storage.get(AppConstants.accessTokenKey);
    if ((token == null || token.isEmpty) && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    }
  }

  @override
  void dispose() {
    _oldC.dispose();
    _newC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  bool get _policyOk => evaluatePassword(_newC.text).valid;
  bool get _mismatch =>
      _confirmC.text.isNotEmpty && _confirmC.text != _newC.text;
  bool get _sameAsOld => _newC.text.isNotEmpty && _newC.text == _oldC.text;
  bool get _canSubmit =>
      _oldC.text.isNotEmpty &&
      _policyOk &&
      _confirmC.text == _newC.text &&
      !_sameAsOld;

  Future<void> _submit() async {
    if (!_canSubmit || _loading) return;
    setState(() => _loading = true);
    try {
      final resp = await _api.changePassword(_oldC.text, _newC.text);
      if (resp.statusCode == 200) {
        await Storage.set(AppConstants.forceChangePasswordKey, '0');
        if (!mounted) return;
        Toast.success(context, 'Password berhasil diganti.');
        // Penjual baru tanpa outlet yang belum melihat panduan: Dashboard dulu (panduan pertama), bukan /outlet.
        final role = await Storage.get(AppConstants.userRoleKey);
        final tourFirst = role == AppConstants.roleSeller &&
            await SellerOutletGate.sellerNeedsTourFirst();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
            context, tourFirst ? '/' : '/outlet', (r) => false);
      } else {
        String msg = 'Gagal mengganti password.';
        try {
          msg = jsonDecode(resp.body)['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (_) {
      if (mounted) {
        Toast.error(context,
            'Gagal mengganti password. Periksa koneksi internet Anda.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    try {
      await CoreApi().logout();
    } catch (_) {
      // abaikan: sesi lokal tetap dihapus
    }
    Storage.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    }
  }

  InputDecoration _dec(String label, {String? helper, String? error}) =>
      InputDecoration(
        labelText: label,
        helperText: helper,
        errorText: error,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          icon: Icon(_show
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined),
          onPressed: () => setState(() => _show = !_show),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AuthCard(
      title: 'Ganti Password',
      subtitle:
          'Password awal dibuat oleh pemilik usaha. Ganti dengan password pribadi Anda sebelum melanjutkan.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _oldC,
            obscureText: !_show,
            autofillHints: const [AutofillHints.password],
            decoration: _dec('Password lama'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _newC,
            obscureText: !_show,
            autofillHints: const [AutofillHints.newPassword],
            decoration: _dec('Password baru',
                helper: passwordPolicyMessage,
                error: _sameAsOld
                    ? 'Password baru tidak boleh sama dengan password lama'
                    : null),
            onChanged: (_) => setState(() {}),
          ),
          PasswordStrengthBar(password: _newC.text),
          const SizedBox(height: 14),
          TextField(
            controller: _confirmC,
            obscureText: !_show,
            autofillHints: const [AutofillHints.newPassword],
            decoration: _dec('Konfirmasi password baru',
                error: _mismatch ? 'Password belum sama' : null),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _canSubmit && !_loading ? _submit : null,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('SIMPAN PASSWORD BARU'),
            ),
          ),
          TextButton(
            onPressed: _loading ? null : _logout,
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
