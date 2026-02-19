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

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _userController.text.isNotEmpty && _passwordController.text.isNotEmpty;
  }

  Future<void> _handleLogin() async {
    if (!_canSubmit) return;

    setState(() => _isLoading = true);

    try {
      final response = await _coreApi.login(
        _userController.text,
        _passwordController.text,
      );
      // final data = jsonDecode(response.body);
      print("statusCode: ${response}");
      print("statusCode2: ${response.statusCode}");
// print("statuscode3: $data");
      if (response.statusCode == 200) {
        print("masok1");
        final loginResponse = LoginResponseModel.fromJson(
          jsonDecode(response.body),
        );
        print("masok2");

        // Save to storage
        await Storage.set(AppConstants.accessTokenKey, loginResponse.bearerToken);
        await Storage.set(AppConstants.expiresAtKey, loginResponse.expiresAt.toString());
        await Storage.set(AppConstants.userNIPKey, loginResponse.username);
        await Storage.set(AppConstants.languageKey, AppConstants.defaultLanguage);
        print("masok3");

        // Update user provider
        if (mounted) {
        print("masok4");
          Provider.of<UserProvider>(context, listen: false)
              .setUserFromToken(loginResponse.bearerToken);
        print("masok5");

          // Navigate to home
          Navigator.pushReplacementNamed(context, '/');
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
                    // Logo
                    Image.asset(
                      'assets/images/logo.png',
                      width: 100,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.fitness_center,
                          size: 100,
                          color: AppTheme.primaryBlue,
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'Gold Gym Login',
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
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
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
                        onPressed: _isLoading || !_canSubmit ? null : _handleLogin,
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
