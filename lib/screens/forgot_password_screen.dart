import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/core_api.dart';
import '../utils/toast.dart';
import '../utils/password_strength.dart';
import '../widgets/password_strength_bar.dart';
import '../widgets/auth_card.dart';
import '../providers/language_provider.dart';

/// Lupa password: minta OTP 6 digit ke email, lalu OTP + password baru
/// sekaligus (padanan web pages/lupa-password -- backend UpdateOTP +
/// UpdateDataPeserta, keduanya publik/tanpa login).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _coreApi = CoreApi();
  bool _step2 = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp(LanguageProvider lang) async {
    if (_emailController.text.trim().isEmpty || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final response =
          await _coreApi.requestPasswordResetOtp(_emailController.text.trim());
      if (!mounted) return;
      if (response.statusCode == 200) {
        Toast.success(
            context, lang.get('OTP code sent, check your email.', 'Kode OTP terkirim, cek email Anda.'));
        setState(() => _step2 = true);
      } else {
        Toast.error(context, _extractError(response.body,
            lang.get('Failed to send OTP. Check the email address.', 'Gagal mengirim OTP. Periksa alamat email.')));
      }
    } catch (_) {
      if (mounted) {
        Toast.error(context,
            lang.get('Failed to send OTP. Check your internet connection.', 'Gagal mengirim OTP. Periksa koneksi internet Anda.'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _canReset =>
      _otpController.text.trim().length == 6 &&
      evaluatePassword(_passwordController.text).valid &&
      _passwordController.text == _confirmController.text;

  Future<void> _resetPassword(LanguageProvider lang) async {
    if (!_canReset || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final response = await _coreApi.confirmPasswordReset(
        _emailController.text.trim(),
        _otpController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        Toast.success(context,
            lang.get('Password changed. Please log in again.', 'Password berhasil diganti. Silakan masuk kembali.'));
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        Toast.error(context, _extractError(response.body,
            lang.get('Failed to reset password. Check the OTP code.', 'Gagal mengganti password. Periksa kode OTP.')));
      }
    } catch (_) {
      if (mounted) {
        Toast.error(context, lang.get('Failed. Check your internet connection.', 'Gagal. Periksa koneksi internet Anda.'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _extractError(String body, String fallback) {
    try {
      final b = jsonDecode(body);
      final msg = b['message'] ?? b['error'];
      if (msg is String && msg.isNotEmpty) return msg;
    } catch (_) {}
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, lang, child) {
        return AuthCard(
          title: lang.get('Forgot Password', 'Lupa Password'),
          subtitle: _step2
              ? lang.get('Enter the OTP code and your new password.', 'Masukkan kode OTP dan password baru Anda.')
              : lang.get("Enter your account email, we'll send a 6-digit OTP code.",
                  'Masukkan email akun Anda, kami kirim kode OTP 6 digit.'),
          child: _step2 ? _buildStep2(lang) : _buildStep1(lang),
        );
      },
    );
  }

  Widget _buildStep1(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'contoh: nama@email.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _sendOtp(lang),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed:
                _isLoading || _emailController.text.trim().isEmpty ? null : () => _sendOtp(lang),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(lang.get('SEND OTP', 'KIRIM OTP')),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            child: Text(lang.get('BACK TO LOGIN', 'KEMBALI KE MASUK')),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('${lang.get("Email:", "Email:")} ${_emailController.text}'),
            ),
            TextButton(
              onPressed: () => setState(() => _step2 = false),
              child: Text(lang.get('change', 'ubah')),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _otpController,
          decoration: InputDecoration(
            labelText: lang.get('6-digit OTP code', 'Kode OTP 6 digit'),
            prefixIcon: const Icon(Icons.pin_outlined),
          ),
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: lang.get('New password', 'Password baru'),
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.newPassword],
          onChanged: (_) => setState(() {}),
        ),
        PasswordStrengthBar(password: _passwordController.text),
        const SizedBox(height: 14),
        TextField(
          controller: _confirmController,
          decoration: InputDecoration(
            labelText: lang.get('Confirm new password', 'Konfirmasi password baru'),
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            errorText: _confirmController.text.isNotEmpty &&
                    _confirmController.text != _passwordController.text
                ? lang.get('Passwords do not match', 'Password tidak sama')
                : null,
          ),
          obscureText: _obscurePassword,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _resetPassword(lang),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading || !_canReset ? null : () => _resetPassword(lang),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(lang.get('SAVE NEW PASSWORD', 'SIMPAN PASSWORD BARU')),
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : () => _sendOtp(lang),
          child: Text(lang.get('Resend OTP', 'Kirim ulang OTP')),
        ),
      ],
    );
  }
}
