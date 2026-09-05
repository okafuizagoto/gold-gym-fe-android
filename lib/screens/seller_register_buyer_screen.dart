import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/core_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
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
    final textTheme = Theme.of(context).textTheme;
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Daftar Pembeli'),
        drawer: const AppDrawer(),
        body: PageBody(
          maxWidth: 520,
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(context.isCompact ? 24 : 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _alreadyBuyer
                            ? AppColors.successLight
                            : AppColors.tealLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _alreadyBuyer
                            ? Icons.check_circle_rounded
                            : Icons.shopping_bag_outlined,
                        size: 44,
                        color: _alreadyBuyer
                            ? AppColors.successDark
                            : AppColors.tealDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _alreadyBuyer
                        ? 'Anda sudah terdaftar sebagai pembeli'
                        : 'Apakah Anda ingin mendaftar akun pembeli?',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(fontSize: 20),
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
                        textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                  if (!_alreadyBuyer) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successDark,
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.how_to_reg_rounded, size: 20),
                        label: const Text('YA, DAFTARKAN SAYA'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
