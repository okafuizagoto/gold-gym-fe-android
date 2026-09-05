import 'package:flutter/material.dart';
import 'dart:convert';
import '../config/theme.dart';
import '../services/outlet_api.dart';
import '../models/outlet_model.dart';
import '../utils/storage.dart';
import '../utils/constants.dart';
import '../services/core_api.dart';
import '../utils/toast.dart';
import '../widgets/auth_card.dart';

class OutletScreen extends StatefulWidget {
  const OutletScreen({super.key});

  @override
  State<OutletScreen> createState() => _OutletScreenState();
}

class _OutletScreenState extends State<OutletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _coreApi = CoreApi();

  List<OutletResponse> _types = [];

  ValueNotifier<OutletPagination?> outletsPaginationNotifier =
      ValueNotifier(null);

  bool _isLoadingOutlets = true;
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

  Future<void> getAllOutlet(String name, int page, int length) async {
    try {
      final outletsApi = OutletsApi();
      final response =
          await outletsApi.getAllOutlet(name, "ACTIVE", page, length);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pagination = OutletPagination.fromJson(data);

        outletsPaginationNotifier.value = pagination;
        if (_types.isEmpty) {
          setState(() {
            _types = pagination.data; // simpan semua field
          });
        }
      } else {
        Toast.error(context, 'Gagal memuat daftar outlet.');
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal memuat daftar outlet.');
    } finally {
      if (mounted) setState(() => _isLoadingOutlets = false);
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
        Toast.error(context, 'Logout gagal.');
      }
    } catch (e) {
      Toast.error(context, 'Logout gagal.');
    }
  }

  Future<void> _handleOutlet() async {
    if (_selectedType == null) {
      Toast.error(context, 'Pilih outlet terlebih dahulu.');
      return;
    }

    await Storage.set(AppConstants.outcode, _selectedType!);
    // simpan tipe outlet supaya menu (Booking Terapi vs Belanja) menyesuaikan
    final selected = _types.where((o) => o.outlet_code == _selectedType);
    await Storage.set(AppConstants.outletTypeKey,
        selected.isNotEmpty ? selected.first.outlet_type : 'RETAIL');
    // pembeli langsung ke layar belanja; penjual/admin ke dashboard
    final role = await Storage.get(AppConstants.userRoleKey);
    if (!mounted) return;
    Navigator.pushReplacementNamed(
        context, role == AppConstants.roleBuyer ? '/belanja' : '/');
  }

  Future<void> _handleNewOutlet() async {
    Navigator.pushReplacementNamed(context, '/new-outlet');
  }

  Future<void> _handleListOutlet() async {
    Navigator.pushReplacementNamed(context, '/list-outlet');
  }

  @override
  Widget build(BuildContext context) {
    return AuthCard(
      title: 'Pilih Outlet',
      subtitle: 'Pilih outlet yang akan Anda operasikan sekarang',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Outlet',
                prefixIcon: const Icon(Icons.storefront_rounded),
                helperText: _isLoadingOutlets
                    ? 'Memuat daftar outlet...'
                    : (_types.isEmpty
                        ? 'Belum ada outlet aktif -- buat lewat NEW OUTLET'
                        : null),
              ),
              items: _types.map((type) {
                return DropdownMenuItem<String>(
                  value: type.outlet_code,
                  child: Text(
                    type.outlet_name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value;
                });
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _handleOutlet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successDark,
                ),
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text('CONFIRM'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _handleListOutlet,
                icon: const Icon(Icons.list_alt_rounded, size: 20),
                label: const Text('LIST OUTLET'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _handleNewOutlet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warningDark,
                ),
                icon: const Icon(Icons.add_business_rounded, size: 20),
                label: const Text('NEW OUTLET'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.5)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('LOGOUT'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
