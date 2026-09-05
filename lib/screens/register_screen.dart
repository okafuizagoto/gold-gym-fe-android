import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/core_api.dart';
import '../utils/constants.dart';
import '../utils/toast.dart';

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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Daftar Akun')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Buat Akun',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Pilihan role: pembeli atau penjual — admin bisa
                  // membatasi lewat menu Akses Admin -> Daftar Akun.
                  if (_registrationMode == 'BOTH')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Pembeli'),
                          selected: _role == AppConstants.roleBuyer,
                          onSelected: (_) =>
                              setState(() => _role = AppConstants.roleBuyer),
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Penjual'),
                          selected: _role == AppConstants.roleSeller,
                          onSelected: (_) =>
                              setState(() => _role = AppConstants.roleSeller),
                        ),
                      ],
                    )
                  else
                    Text(
                      _registrationMode == 'SELLER_ONLY'
                          ? 'Pendaftaran saat ini hanya untuk akun penjual'
                          : 'Pendaftaran saat ini hanya untuk akun pembeli',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _namaController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _hpController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor HP',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password (min. 6 karakter)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed:
                          _isLoading || !_canSubmit ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade500,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('DAFTAR'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
