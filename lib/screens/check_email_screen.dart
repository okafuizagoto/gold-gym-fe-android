import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/core_api.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/auth_card.dart';

const _resendCooldownSeconds = 60;

/// Halaman "cek email" -- ditampilkan setelah login/registrasi kalau email
/// BELUM diverifikasi (token yang tersimpan tidak bisa akses endpoint
/// terproteksi apa pun, lihat ValidateToken middleware backend). TIDAK
/// dibungkus PrivateRoute -- harus tetap bisa diakses walau token
/// "belum terverifikasi".
class CheckEmailScreen extends StatefulWidget {
  const CheckEmailScreen({super.key});

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
  final _coreApi = CoreApi();

  /// Logout: cabut sesi di server (refresh token) lalu hapus sesi lokal.
  Future<void> _logout() async {
    try {
      await _coreApi.logout();
    } catch (_) {
      // abaikan: sesi lokal tetap dihapus
    }
    Storage.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    }
  }

  String _email = '';
  bool _sending = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Storage.get(AppConstants.userEmail).then((v) {
      if (mounted) setState(() => _email = v ?? '');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = _resendCooldownSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _cooldown -= 1;
        if (_cooldown <= 0) t.cancel();
      });
    });
  }

  Future<void> _handleResend() async {
    if (_email.isEmpty || _sending || _cooldown > 0) return;
    setState(() => _sending = true);
    try {
      final response = await _coreApi.resendVerification(_email);
      if (response.statusCode == 200) {
        if (mounted) {
          Toast.success(context,
              'Email verifikasi sudah dikirim ulang. Silakan cek inbox kamu.');
        }
        _startCooldown();
      } else {
        String message = 'Gagal mengirim ulang email verifikasi';
        try {
          message = jsonDecode(response.body)['error'] ?? message;
        } catch (_) {}
        if (mounted) Toast.error(context, message);
      }
    } catch (_) {
      if (mounted) {
        Toast.error(
            context, 'Gagal mengirim ulang. Periksa koneksi internet Anda.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AuthCard(
      title: 'Verifikasi Email Kamu',
      showLogo: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_unread_rounded,
                  size: 44, color: AppColors.blue),
            ),
          ),
          const SizedBox(height: 20),
          Text.rich(
            TextSpan(
              style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              children: [
                const TextSpan(
                    text: 'Email kamu belum diverifikasi. Kami sudah '
                        'mengirim link verifikasi ke '),
                TextSpan(
                  text: _email.isEmpty ? 'email kamu' : _email,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const TextSpan(
                    text: '. Silakan cek inbox (dan folder spam) untuk '
                        'melanjutkan.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: (_sending || _cooldown > 0 || _email.isEmpty)
                  ? null
                  : _handleResend,
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_cooldown > 0
                      ? 'Kirim Ulang ($_cooldown detik)'
                      : 'Kirim Ulang Email Verifikasi'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: _logout,
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }
}
