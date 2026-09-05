import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/core_api.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

/// Menu Daftar Pembeli (penjual/admin): satu pertanyaan konfirmasi —
/// "Apakah Anda ingin mendaftar akun pembeli?". Setelah dikonfirmasi,
/// flag gold_buyer_yn = Y tersimpan di database; menu "Mode Pembeli"
/// muncul di drawer dan menu Daftar Pembeli ini hilang.
class SellerRegisterBuyerScreen extends StatefulWidget {
  const SellerRegisterBuyerScreen({super.key});

  @override
  State<SellerRegisterBuyerScreen> createState() =>
      _SellerRegisterBuyerScreenState();
}

class _SellerRegisterBuyerScreenState extends State<SellerRegisterBuyerScreen> {
  final _coreApi = CoreApi();
  bool _isLoading = false;
  bool _alreadyBuyer = false;

  @override
  void initState() {
    super.initState();
    _loadFlag();
  }

  Future<void> _loadFlag() async {
    final flag = await Storage.get(AppConstants.userIsBuyerKey) ?? 'N';
    if (mounted) setState(() => _alreadyBuyer = flag == 'Y');
  }

  Future<void> _handleConfirm() async {
    setState(() => _isLoading = true);
    try {
      final response = await _coreApi.registerAsBuyer();
      if (response.statusCode == 200) {
        await Storage.set(AppConstants.userIsBuyerKey, 'Y');
        if (!mounted) return;
        setState(() => _alreadyBuyer = true);
        await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Berhasil'),
            content: const Text(
                'Akun Anda kini terdaftar sebagai pembeli. Menu "Mode Pembeli" '
                'sudah tersedia di menu samping untuk mulai berbelanja.'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (mounted) {
          // kembali ke dashboard; drawer akan menampilkan menu Mode Pembeli
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
      } else {
        String message = 'Gagal mendaftar sebagai pembeli';
        try {
          message = jsonDecode(response.body)['error'] ?? message;
        } catch (_) {}
        if (mounted) Toast.error(context, message);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal mendaftar sebagai pembeli');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Daftar Pembeli')),
        drawer: const AppDrawer(),
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
                    Icon(
                      _alreadyBuyer
                          ? Icons.check_circle
                          : Icons.shopping_bag_outlined,
                      size: 56,
                      color: _alreadyBuyer ? Colors.green : Colors.teal,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _alreadyBuyer
                          ? 'Anda sudah terdaftar sebagai pembeli'
                          : 'Apakah Anda ingin mendaftar akun pembeli?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _alreadyBuyer
                          ? 'Gunakan menu "Mode Pembeli" di menu samping untuk '
                              'mulai berbelanja di outlet penjual lain.'
                          : 'Setelah terdaftar, menu "Mode Pembeli" akan muncul '
                              'dan Anda bisa berbelanja di outlet penjual lain.',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    if (!_alreadyBuyer)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleConfirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
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
                              : const Text('YA, DAFTARKAN SAYA'),
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
