import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/private_route.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../providers/language_provider.dart';

class AddMenuScreen extends StatefulWidget {
  const AddMenuScreen({super.key});

  @override
  State<AddMenuScreen> createState() => _AddMenuScreenState();
}

class _AddMenuScreenState extends State<AddMenuScreen> {
  final _formKey = GlobalKey<FormState>();
  final _menuController = TextEditingController();
  final _pathController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _menuController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _handleAddMenu() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await Storage.addUserMenu({
        'menu': _menuController.text,
        'path': _pathController.text,
        'iconName': 'BarChartIcon',
      });

      if (mounted) {
        Toast.success(context, 'Menu added successfully!');
        _menuController.clear();
        _pathController.clear();

        // Reload to update sidebar
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        });
      }
    } catch (e) {
      if (mounted) {
        Toast.error(context, 'Failed to add menu.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      child: Consumer<LanguageProvider>(
        builder: (context, langProvider, child) {
          return Scaffold(
            appBar: AppBarCustom(
              title: langProvider.get('Add Menu', 'Tambah Menu'),
            ),
            drawer: const AppDrawer(),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      langProvider.get(
                        'Create Custom Menu',
                        'Buat Menu Kustom',
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      langProvider.get(
                        'Add a custom menu item to your sidebar',
                        'Tambahkan item menu kustom ke sidebar Anda',
                      ),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),

                    // Menu name
                    TextFormField(
                      controller: _menuController,
                      decoration: InputDecoration(
                        labelText: langProvider.get('Menu Name', 'Nama Menu'),
                        hintText: langProvider.get('e.g., Reports', 'mis., Laporan'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return langProvider.get(
                            'Please enter menu name',
                            'Harap masukkan nama menu',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Path
                    TextFormField(
                      controller: _pathController,
                      decoration: InputDecoration(
                        labelText: langProvider.get('Path', 'Path'),
                        hintText: langProvider.get('e.g., reports', 'mis., laporan'),
                        border: const OutlineInputBorder(),
                        prefixText: '/',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return langProvider.get(
                            'Please enter path',
                            'Harap masukkan path',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleAddMenu,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(langProvider.get('ADD MENU', 'TAMBAH MENU')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
