import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/language_provider.dart';
import '../services/core_api.dart';
import '../utils/bidang_usaha.dart';
import '../utils/constants.dart';
import '../utils/countries.dart';
import '../utils/language_pref.dart';
import '../utils/password_strength.dart';
import '../utils/toast.dart';
import '../widgets/auth_card.dart';
import '../widgets/country_autocomplete.dart';
import '../widgets/language_switch.dart';
import '../widgets/password_strength_bar.dart';
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
  final _namaPTController = TextEditingController();
  final _emailController = TextEditingController();
  final _hpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _bidangUsahaLainnyaController = TextEditingController();
  final _coreApi = CoreApi();
  bool _isLoading = false;
  String _role = AppConstants.roleBuyer;
  String _bidangUsaha = '';
  // Negara akun (kode ISO2). Awalnya dari lokal perangkat (id_ID -> ID); wajib dipilih.
  String _countryIso2 = '';
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
    final cc = (WidgetsBinding.instance.platformDispatcher.locale.countryCode ?? '').toUpperCase();
    _countryIso2 = countryOptions.any((c) => c.iso2 == cc) ? cc : '';
  }

  /// Bahasa form mengikuti negara (Indonesia -> Indonesia, lainnya -> Inggris), KECUALI pengguna sudah memilih
  /// bahasa sendiri di perangkat ini (tombol ID/EN) -- pilihan manual menang.
  Future<void> _onCountryChanged(String iso2) async {
    setState(() => _countryIso2 = iso2);
    if (iso2.isEmpty || await readLanguagePref() != null || !mounted) return;
    await context.read<LanguageProvider>().setLanguage(languageForCountry(iso2), remember: false);
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
    _namaPTController.dispose();
    _emailController.dispose();
    _hpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _bidangUsahaLainnyaController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _countryIso2.isNotEmpty &&
        _namaController.text.isNotEmpty &&
        _emailController.text.contains('@') &&
        evaluatePassword(_passwordController.text).valid &&
        _passwordController.text == _confirmController.text;
  }

  Future<void> _handleRegister() async {
    final lang = context.read<LanguageProvider>();
    if (!_canSubmit) {
      Toast.error(
          context,
          !evaluatePassword(_passwordController.text).valid
              ? passwordPolicyMessage
              : context.read<LanguageProvider>().get(
                  'Complete the form. Password must match the confirmation.',
                  'Lengkapi data. Password harus sama dengan konfirmasi.'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final bidangUsahaFinal = _bidangUsaha == bidangUsahaLainnya
          ? _bidangUsahaLainnyaController.text.trim()
          : _bidangUsaha;
      final response = await _coreApi.registerBuyer(
        nama: _namaController.text,
        email: _emailController.text,
        password: _passwordController.text,
        nomorHp: _hpController.text,
        role: _role,
        namaPT: _namaPTController.text,
        bidangUsaha: bidangUsahaFinal,
        countryIso2: _countryIso2,
      );

      if (response.statusCode == 201) {
        if (mounted) {
          Toast.success(
            context,
lang.get('Registration successful. We sent a verification link to your email. Please check your inbox (or spam folder) to verify your email before logging in.',
                            'Registrasi berhasil. Kami telah mengirimkan tautan verifikasi ke email Anda. Silakan periksa kotak masuk (atau folder spam) untuk memverifikasi email sebelum masuk.'),
            duration: const Duration(seconds: 8),
          );
          Navigator.pop(context);
        }
      } else {
        String message = lang.get('Registration failed', 'Registrasi gagal');
        try {
          final body = jsonDecode(response.body);
          if (body['error'] != null) message = body['error'];
        } catch (_) {}
        if (mounted) Toast.error(context, message);
      }
    } catch (e) {
      if (mounted) Toast.error(context, '${lang.get('Registration failed', 'Registrasi gagal')}: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final textTheme = Theme.of(context).textTheme;
    final passwordMismatch = _confirmController.text.isNotEmpty &&
        _passwordController.text != _confirmController.text;

    return AuthCard(
      title: lang.get('Create Account', 'Buat Akun'),
      subtitle: lang.get('Sign up as a buyer or seller, active right away',
          'Daftar sebagai pembeli atau penjual, langsung aktif'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const LanguageSwitch(),
          // Pilihan role: pembeli atau penjual — admin bisa
          // membatasi lewat menu Akses Admin -> Daftar Akun.
          if (_registrationMode == 'BOTH')
            SegmentedTabs<String>(
              value: _role,
              onChanged: (v) => setState(() => _role = v),
              tabs: [
                SegmentedTab(
                  value: AppConstants.roleBuyer,
                  label: lang.get('Buyer', 'Pembeli'),
                  icon: Icons.shopping_bag_outlined,
                ),
                SegmentedTab(
                  value: AppConstants.roleSeller,
                  label: lang.get('Seller', 'Penjual'),
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
                    ? lang.get('Registration is currently for seller accounts only', 'Pendaftaran saat ini hanya untuk akun penjual')
                    : lang.get('Registration is currently for buyer accounts only', 'Pendaftaran saat ini hanya untuk akun pembeli'),
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: AppColors.infoDark),
              ),
            ),
          const SizedBox(height: 18),
          TextField(
            controller: _namaController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: lang.get('Full Name', 'Nama Lengkap'),
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          CountryAutocomplete(
            value: _countryIso2,
            onChanged: _onCountryChanged,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _namaPTController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: lang.get('Company Name (optional)', 'Nama PT (opsional)'),
              prefixIcon: const Icon(Icons.business_outlined),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            isExpanded: true, // isi memenuhi lebar & pilihan panjang dipotong (tanpa ini meluap di layar 360dp)
            initialValue: _bidangUsaha.isEmpty ? null : _bidangUsaha,
            decoration: InputDecoration(
              labelText: lang.get('Line of Business (optional)', 'Bidang Usaha (opsional)'),
              prefixIcon: const Icon(Icons.category_outlined),
            ),
            items: bidangUsahaOptions
                .map((opt) => DropdownMenuItem(
                    value: opt,
                    child: Text(opt, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _bidangUsaha = v ?? ''),
          ),
          if (_bidangUsaha == bidangUsahaLainnya) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _bidangUsahaLainnyaController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: lang.get('Specify Line of Business', 'Sebutkan Bidang Usaha'),
                prefixIcon: const Icon(Icons.edit_outlined),
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username],
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
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: lang.get('Phone Number', 'Nomor HP'),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: lang.get(
                  'At least 6 characters, with uppercase, lowercase and a number',
                  'Minimal 6 karakter, huruf besar, huruf kecil, dan angka'),
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
          PasswordStrengthBar(password: _passwordController.text),
          const SizedBox(height: 14),
          TextField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleRegister(),
            decoration: InputDecoration(
              labelText: lang.get('Confirm Password', 'Konfirmasi Password'),
              errorText: passwordMismatch
                  ? lang.get('Passwords do not match', 'Password tidak sama')
                  : null,
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
                  : Text(lang.get('REGISTER', 'DAFTAR')),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                lang.get('Already have an account? ', 'Sudah punya akun? '),
                style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Text(
                    lang.get('Log in', 'Masuk'),
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
