import 'package:flutter/material.dart';
import 'dart:convert';
import '../config/theme.dart';
import '../services/outlet_api.dart';
import '../models/outlet_model.dart';
import '../utils/storage.dart';
import '../utils/constants.dart';
import '../services/core_api.dart';
import '../utils/toast.dart';

class OutletScreen extends StatefulWidget {
  const OutletScreen({super.key});

  @override
  State<OutletScreen> createState() => _OutletScreenState();
}

class _OutletScreenState extends State<OutletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  // final List<String> _types = ['stock', 'shiatsu'];
  final _coreApi = CoreApi();

  List<OutletResponse> _types = [];

  ValueNotifier<OutletPagination?> outletsPaginationNotifier =
      ValueNotifier(null);

  bool _isLoading = false;

  String? _selectedType;

  @override
  void initState() {
    super.initState();

    loadItemsOnStart();
  }

  Future<void> loadItemsOnStart() async {
    if (outletsPaginationNotifier.value == null ||
        outletsPaginationNotifier.value!.data.isEmpty) {
      await getAllOutlet("", 0, 0);
    }
  }

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

  Future<void> getAllOutlet(String name, int page, int length) async {
    try {
      // final email = await Storage.get('userEmail') ?? "";

      final outletsApi = OutletsApi();
      final response =
          await outletsApi.getAllOutlet(name, "ACTIVE", page, length);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // final List items = data["data"];

        final pagination = OutletPagination.fromJson(data);

        outletsPaginationNotifier.value = pagination;
        if (_types.length == 0) {
          setState(() {
            // _types = pagination.data.map((item) => item.outlet_name).toList();
            setState(() {
              _types = pagination.data; // ✅ simpan semua field
            });
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to fetch items"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error fetching itemss"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    try {
      final response = await _coreApi.logout();
      if (response.statusCode == 200) {
        if (mounted) {
          Storage.clear();
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        Toast.error(context, 'Login failed.');
      }
    } catch (e) {
      Toast.error(context, 'Login failed.');
    }
  }

  Future<void> _handleOutlet() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select an outlet"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await Storage.set('outcode', _selectedType!);
    Navigator.pushReplacementNamed(context, '/');
  }

  Future<void> _handleNewOutlet() async {
    Navigator.pushReplacementNamed(context, '/new-outlet');
  }

  Future<void> _handleListOutlet() async {
    Navigator.pushReplacementNamed(context, '/list-outlet');
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
                    // // Logo
                    // Image.asset(
                    //   'assets/images/logo.png',
                    //   width: 100,
                    //   height: 100,
                    //   errorBuilder: (context, error, stackTrace) {
                    //     return const Icon(
                    //       Icons.fitness_center,
                    //       size: 100,
                    //       color: AppTheme.primaryBlue,
                    //     );
                    //   },
                    // ),
                    // const SizedBox(height: 32),

                    // Title
                    const Text(
                      'Choose Outlet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // // User field
                    // TextField(
                    //   controller: _userController,
                    //   decoration: const InputDecoration(
                    //     labelText: 'USER',
                    //     border: OutlineInputBorder(),
                    //   ),
                    //   textInputAction: TextInputAction.next,
                    //   onChanged: (_) => setState(() {}),
                    // ),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: _types.map((type) {
                        return DropdownMenuItem<String>(
                          value: type.outlet_code,
                          child: Text(type.outlet_name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // // Password field
                    // TextField(
                    //   controller: _passwordController,
                    //   decoration: const InputDecoration(
                    //     labelText: 'Password',
                    //     border: OutlineInputBorder(),
                    //   ),
                    //   obscureText: true,
                    //   textInputAction: TextInputAction.done,
                    //   onChanged: (_) => setState(() {}),
                    //   onSubmitted: (_) => _handleLogin(),
                    // ),
                    // const SizedBox(height: 32),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        // onPressed:
                        //     _isLoading || !_canSubmit ? null : _handleLogin,
                        onPressed: _handleOutlet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors
                              .green.shade600, // button background, #43A047
                          foregroundColor: Colors.white, // text & icon color
                          disabledBackgroundColor:
                              Colors.grey.shade300, // when onPressed is null
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
                            : const Text('CONFIRM'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        // onPressed:
                        //     _isLoading || !_canSubmit ? null : _handleLogin,
                        onPressed: _handleListOutlet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600, // #1E88E5
                          foregroundColor: Colors.white, // text & icon color
                          disabledBackgroundColor:
                              Colors.grey.shade300, // when onPressed is null
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
                            : const Text('LIST OUTLET'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        // onPressed:
                        //     _isLoading || !_canSubmit ? null : _handleLogin,
                        onPressed: _handleNewOutlet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700, // #F57C00
                          foregroundColor: Colors.white, // text & icon color
                          disabledBackgroundColor:
                              Colors.grey.shade300, // when onPressed is null
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
                            : const Text('NEW OUTLET'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Back button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          _handleLogout();
                        },
                        child: const Text('LOGOUT'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700, // #F57C00
                          foregroundColor: Colors.white, // text & icon color
                          disabledBackgroundColor:
                              Colors.grey.shade300, // when onPressed is null
                          disabledForegroundColor: Colors.grey.shade500,
                        ),
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
