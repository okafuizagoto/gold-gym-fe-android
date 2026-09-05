import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/core_api.dart';
import '../utils/constants.dart';
import '../utils/toast.dart';
import '../widgets/auth_card.dart';
import '../widgets/segmented_tabs.dart';

/// Registrasi akun (role PEMBELI atau PENJUAL) — langsung aktif tanpa OTP.
/// Pembeli yang daftar mandiri di sini TIDAK punya nama toko di nota;
/// nama toko hanya untuk pembeli yang didaftarkan lewat menu penjual.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _hpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _coreApi = CoreApi();
  bool _isLoading = false;
  String _role = AppConstants.roleBuyer;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  // BOTH (default) / BUYER_ONLY / SELLER_ONLY — diatur admin lewat menu
  // Akses Admin -> Daftar Akun. Gagal ambil (network dll) dianggap BOTH
  // supaya layar registrasi tidak terblokir.
  String _registrationMode = 'BOTH';

  @override
  void initState() {
    super.initState();
    _loadRegistrationMode();
  }

  Future<void> _loadRegistrationMode() async {
    try {
      final response = await _coreApi.getRegistrationMode();
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final mode = (body['data']?['mode'] ?? 'BOTH') as String;
        if (!mounted) return;
        setState(() {
          _registrationMode = mode;
          if (mode == 'BUYER_ONLY') _role = AppConstants.roleBuyer;
          if (mode == 'SELLER_ONLY') _role = AppConstants.roleSeller;
        });
      }
    } catch (_) {
      // biarkan default BOTH — jangan blokir layar registrasi
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _hpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _namaController.text.isNotEmpty &&
        _emailController.text.contains('@') &&
        _passwordController.text.length >= 6 &&
        _passwordController.text == _confirmController.text;
  }

  Future<void> _handleRegister() async {
    if (!_canSubmit) {
      Toast.error(context,
          'Lengkapi data. Password minimal 6 karakter dan harus sama dengan konfirmasi.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _coreApi.registerBuyer(
        nama: _namaController.text,
        email: _emailController.text,
        password: _passwordController.text,
        nomorHp: _hpController.text,
        role: _role,
      );

      if (response.statusCode == 201) {
        if (mounted) {
          Toast.success(context, 'Registrasi berhasil, silakan login');
          Navigator.pop(context);
        }
      } else {
        String message = 'Registrasi gagal';
        try {
          final body = jsonDecode(response.body);
          if (body['error'] != null) message = body['error'];
        } catch (_) {}
        if (mounted) Toast.error(context, message);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Registrasi gagal: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final passwordMismatch = _confirmController.text.isNotEmpty &&
        _passwordController.text != _confirmController.text;

    return AuthCard(
      title: 'Buat Akun',
      subtitle: 'Daftar sebagai pembeli atau penjual, langsung aktif',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pilihan role: pembeli atau penjual — admin bisa
          // membatasi lewat menu Akses Admin -> Daftar Akun.
          if (_registrationMode == 'BOTH')
            SegmentedTabs<String>(
              value: _role,
              onChanged: (v) => setState(() => _role = v),
              tabs: const [
                SegmentedTab(
                  value: AppConstants.roleBuyer,
                  label: 'Pembeli',
                  icon: Icons.shopping_bag_outlined,
                ),
                SegmentedTab(
                  value: AppConstants.roleSeller,
                  label: 'Penjual',
                  icon: Icons.storefront_outlined,
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                _registrationMode == 'SELLER_ONLY'
                    ? 'Pendaftaran saat ini hanya untuk akun penjual'
                    : 'Pendaftaran saat ini hanya untuk akun pembeli',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: AppColors.infoDark),
              ),
            ),
          const SizedBox(height: 18),
          TextField(
            controller: _namaController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nama Lengkap',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _hpController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nomor HP',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: 'Minimal 6 karakter',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleRegister(),
            decoration: InputDecoration(
              labelText: 'Konfirmasi Password',
              errorText: passwordMismatch ? 'Password tidak sama' : null,
              prefixIcon: const Icon(Icons.lock_reset_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirm = !_obscureConfirm;
                  });
                },
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading || !_canSubmit ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successDark,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('DAFTAR'),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Sudah punya akun? ',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Text(
                    'Masuk',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
