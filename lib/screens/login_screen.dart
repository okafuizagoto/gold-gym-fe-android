import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/core_api.dart';
import '../models/login_response_model.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../utils/constants.dart';
import '../providers/user_provider.dart';
import '../config/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _coreApi = CoreApi();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _userController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty;
  }

  Future<void> _handleLogin() async {
    if (!_canSubmit) return;

    setState(() => _isLoading = true);

    try {
      final response = await _coreApi.login(
        _userController.text,
        _passwordController.text,
      );
      print("responses = ${response.body}");
      final rawCookie = response.headers['set-cookie'];

      // final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final loginResponse = LoginResponseModel.fromJson(
          jsonDecode(response.body),
        );
        // print("masok2",   );

        // Save to storage
        await Storage.set(
            AppConstants.accessTokenKey, loginResponse.bearerToken);
        await Storage.set(
            AppConstants.expiresAtKey, loginResponse.expiresAt.toString());
        await Storage.set(AppConstants.userNIPKey, loginResponse.username);
        await Storage.set(AppConstants.userEmail, _userController.text);
        await Storage.set(AppConstants.userRoleKey, loginResponse.role);
        await Storage.set(
            AppConstants.userGoldIdKey, loginResponse.goldId.toString());
        await Storage.set(AppConstants.userIsBuyerKey, loginResponse.buyerYn);
        await Storage.set(
            AppConstants.menuDaftarPembeliKey, loginResponse.menuDaftarPembeli);
        await Storage.set(
            AppConstants.menuModePembeliKey, loginResponse.menuModePembeli);
        await Storage.set(
            AppConstants.languageKey, AppConstants.defaultLanguage);
        if (rawCookie != null) {
          final cookie = rawCookie.split(';').first;
          await Storage.set('refresh_cookie', cookie);
        }

        // Tujuan setelah login berbeda per role: pembeli TIDAK melewati menu
        // pilih-outlet milik penjual (/outlet), melainkan langsung ke menu
        // pembeli (pilih outlet penjual → belanja). ADMIN juga tidak lewat
        // pilih-outlet -- semua layar admin (grup "Akses Admin") bersifat
        // global, tidak terikat 1 outlet -- langsung ke Dashboard.
        String dest = '/outlet';
        if (loginResponse.role == AppConstants.roleBuyer) {
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
        if (mounted) {
          Toast.error(context, 'Login failed.');
        }
      }
    } catch (e) {
      if (mounted) {
        Toast.error(context, 'Login failed.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
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
              padding: const EdgeInsets.all(40),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo Okejual (mengikuti warna & desain app icon)
                    Container(
                      width: 100,
                      height: 100,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFF7A3D),
                            Color(0xFFFF4F81),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFF4F81).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.storefront,
                            size: 56,
                            color: Colors.white,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nama aplikasi
                    const Text(
                      'Okejual',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // User field
                    TextField(
                      controller: _userController,
                      decoration: const InputDecoration(
                        labelText: 'USER',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
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
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 32),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed:
                            _isLoading || !_canSubmit ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('LOGIN'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Back button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/');
                        },
                        child: const Text('BACK'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Register buyer link
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: const Text(
                          'Belum punya akun? Daftarkan akunmu segera'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
