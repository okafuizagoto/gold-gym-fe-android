import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/core_api.dart';
import '../services/staff_api.dart';
import '../models/login_response_model.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../utils/constants.dart';
import '../providers/user_provider.dart';
import '../config/theme.dart';
import '../widgets/auth_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _totpController = TextEditingController();
  bool _needTotp = false;
  final _coreApi = CoreApi();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Dilempar keluar karena akun login di perangkat lain (ApiClient menandai
    // session_replaced) -> beri tahu alasannya.
    Storage.get('session_replaced').then((v) async {
      if (v == '1') {
        await Storage.delete('session_replaced');
        if (mounted) {
          Toast.error(context,
              'Akun Anda sedang dipakai di perangkat lain. Silakan masuk lagi.');
        }
      }
    });
  }

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    _totpController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _userController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        (!_needTotp || _totpController.text.trim().isNotEmpty);
  }

  Future<void> _handleLogin() async {
    if (!_canSubmit || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final response = await _coreApi.login(
        _userController.text.trim(),
        _passwordController.text,
        totpCode: _needTotp ? _totpController.text.trim() : null,
      );
      final rawCookie = response.headers['set-cookie'];

      if (response.statusCode == 200) {
        final loginResponse = LoginResponseModel.fromJson(
          jsonDecode(response.body),
        );

        // Save to storage
        await Storage.set(
            AppConstants.accessTokenKey, loginResponse.bearerToken);
        await Storage.set(
            AppConstants.expiresAtKey, loginResponse.expiresAt.toString());
        await Storage.set(AppConstants.userNIPKey, loginResponse.username);
        await Storage.set(AppConstants.userEmail, _userController.text.trim());
        await Storage.set(AppConstants.userRoleKey, loginResponse.role);
        await Storage.set(
            AppConstants.userGoldIdKey, loginResponse.goldId.toString());
        await Storage.set(AppConstants.userIsBuyerKey, loginResponse.buyerYn);
        await Storage.set(
            AppConstants.menuDaftarPembeliKey, loginResponse.menuDaftarPembeli);
        await Storage.set(
            AppConstants.menuModePembeliKey, loginResponse.menuModePembeli);
        await Storage.set(AppConstants.emailVerifiedKey,
            loginResponse.emailVerified.toString());
        await Storage.set(
            AppConstants.languageKey, AppConstants.defaultLanguage);
        if (rawCookie != null) {
          final cookie = rawCookie.split(';').first;
          await Storage.set('refresh_cookie', cookie);
        }

        // Staff: cache menu yang TIDAK boleh diakses (dibaca app_drawer.dart).
        // Gagal fetch (network dll) -> anggap tidak ada yang ditolak, supaya
        // staff tidak tiba-tiba kehilangan semua menu. Non-staff: bersihkan
        // sisa cache akun STAFF sebelumnya di device yang sama.
        if (loginResponse.role == AppConstants.roleStaff) {
          try {
            final resp = await StaffApi().myDeniedMenus();
            if (resp.statusCode == 200) {
              final body = jsonDecode(resp.body);
              final keys = ((body['data'] ?? []) as List)
                  .map((e) => e.toString())
                  .toList();
              await Storage.setStaffDeniedMenuKeys(keys);
            }
          } catch (_) {
            // fail-open
          }
        } else {
          await Storage.setStaffDeniedMenuKeys([]);
        }

        // Tujuan setelah login berbeda per role: pembeli TIDAK melewati menu
        // pilih-outlet milik penjual (/outlet), melainkan langsung ke menu
        // pembeli (pilih outlet penjual → belanja). ADMIN juga tidak lewat
        // pilih-outlet -- semua layar admin (grup "Akses Admin") bersifat
        // global, tidak terikat 1 outlet -- langsung ke Dashboard.
        //
        // KECUALI email belum diverifikasi -- token yang baru saja disimpan
        // TETAP tidak bisa akses endpoint terproteksi apa pun sampai user
        // klik link verifikasi & login ULANG (lihat ValidateToken backend).
        String dest = '/outlet';
        if (!loginResponse.emailVerified) {
          dest = '/check-email';
        } else if (loginResponse.role == AppConstants.roleBuyer) {
          final buyerOutlet = await Storage.get(AppConstants.buyerOutcodeKey);
          dest = (buyerOutlet == null || buyerOutlet.isEmpty)
              ? '/pilih-outlet'
              : '/belanja';
        } else if (loginResponse.role == AppConstants.roleAdmin) {
          dest = '/';
        }

        // Update user provider
        if (mounted) {
          Provider.of<UserProvider>(context, listen: false)
              .setUserFromToken(loginResponse.bearerToken);

          Navigator.pushReplacementNamed(context, dest);
        }
      } else {
        String? code;
        String? msg;
        try {
          final b = jsonDecode(response.body);
          code = b['error'] is String ? b['error'] : null;
          msg = b['message'] is String ? b['message'] : null;
        } catch (_) {}
        if (!mounted) return;
        if (response.statusCode == 401 && code == 'TOTP_REQUIRED') {
          setState(() => _needTotp = true);
          Toast.info(context,
              'Masukkan kode verifikasi dari aplikasi authenticator Anda.');
        } else if (response.statusCode == 401 && code == 'TOTP_INVALID') {
          _totpController.clear();
          Toast.error(context, msg ?? 'Kode verifikasi salah.');
        } else if (response.statusCode == 429) {
          Toast.error(
              context,
              msg ??
                  'Terlalu banyak percobaan masuk. Coba lagi beberapa saat lagi.');
        } else {
          Toast.error(
              context, 'Login gagal. Periksa kembali email dan password Anda.');
        }
      }
    } catch (e) {
      if (mounted) {
        Toast.error(context, 'Login gagal. Periksa koneksi internet Anda.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AuthCard(
      title: 'Masuk',
      subtitle: 'Silakan masuk untuk mulai menggunakan aplikasi',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: 'Email / Username',
                hintText: 'contoh: nama@email.com',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? 'Tampilkan password'
                      : 'Sembunyikan password',
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
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _handleLogin(),
            ),
            if (_needTotp) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _totpController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Kode verifikasi 2 langkah',
                  helperText:
                      'Kode 6 digit dari authenticator, atau kode pemulihan',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
                autofillHints: const [AutofillHints.oneTimeCode],
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _handleLogin(),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading || !_canSubmit ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('MASUK'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/');
                },
                child: const Text('KEMBALI'),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Belum punya akun? ',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/register'),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    child: Text(
                      'Daftarkan akunmu segera',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${AppConstants.appName} v${AppConstants.version}',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: AppColors.disabled),
            ),
          ],
        ),
      ),
    );
  }
}
