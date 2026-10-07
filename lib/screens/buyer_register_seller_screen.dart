import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/login_response_model.dart';
import '../services/core_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

/// Menu Daftar Penjual (pembeli, 2026-10-07): kebalikan seller_register_buyer_screen.dart.
/// Satu pertanyaan konfirmasi -- "Apakah Anda ingin mendaftar akun penjual?". Setelah
/// dikonfirmasi, gold_role akun berubah jadi SELLER (gold_buyer_yn TETAP Y -- akun tetap bisa
/// pakai Mode Pembeli) dan backend menerbitkan token baru, jadi app langsung dapat akses
/// penjual tanpa perlu logout-login manual.
class BuyerRegisterSellerScreen extends StatefulWidget {
  const BuyerRegisterSellerScreen({super.key});

  @override
  State<BuyerRegisterSellerScreen> createState() =>
      _BuyerRegisterSellerScreenState();
}

class _BuyerRegisterSellerScreenState extends State<BuyerRegisterSellerScreen> {
  final _coreApi = CoreApi();
  bool _isLoading = false;

  Future<void> _handleConfirm() async {
    setState(() => _isLoading = true);
    try {
      final response = await _coreApi.upgradeToSeller();
      if (response.statusCode == 200) {
        // Respons berbentuk sama seperti login (data+metadata, lihat
        // UpgradeToSellerGin) -- simpan ulang sesi dengan token BARU supaya
        // role SELLER langsung berlaku tanpa logout-login manual.
        final loginResponse =
            LoginResponseModel.fromJson(jsonDecode(response.body));
        await Storage.set(
            AppConstants.accessTokenKey, loginResponse.bearerToken);
        await Storage.set(
            AppConstants.expiresAtKey, loginResponse.expiresAt.toString());
        await Storage.set(AppConstants.userRoleKey, loginResponse.role);
        await Storage.set(
            AppConstants.userGoldIdKey, loginResponse.goldId.toString());
        await Storage.set(AppConstants.userIsBuyerKey, loginResponse.buyerYn);
        await Storage.set(
            AppConstants.menuDaftarPembeliKey, loginResponse.menuDaftarPembeli);
        await Storage.set(
            AppConstants.menuModePembeliKey, loginResponse.menuModePembeli);
        final rawCookie = response.headers['set-cookie'];
        if (rawCookie != null) {
          await Storage.set('refresh_cookie', rawCookie.split(';').first);
        }

        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Berhasil'),
            content: const Text(
                'Akun Anda kini terdaftar sebagai penjual. Anda tetap bisa '
                'belanja lewat "Mode Pembeli" seperti biasa.'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (mounted) {
          // kembali ke dashboard sebagai penjual; drawer akan menampilkan
          // menu penjual (dashboard, POS, stock, dll).
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
      } else {
        String message = 'Gagal mendaftar sebagai penjual';
        try {
          message = jsonDecode(response.body)['error'] ?? message;
        } catch (_) {}
        if (mounted) Toast.error(context, message);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal mendaftar sebagai penjual');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PrivateRoute(
      buyerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Daftar Penjual'),
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
                      decoration: const BoxDecoration(
                        color: AppColors.tealLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.storefront_outlined,
                        size: 44,
                        color: AppColors.tealDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Apakah Anda ingin mendaftar akun penjual?',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Setelah terdaftar, Anda bisa membuat outlet dan mulai '
                    'berjualan. Anda tetap bisa belanja lewat "Mode Pembeli" '
                    'seperti biasa -- akun ini tidak hilang kemampuan belanjanya.',
                    textAlign: TextAlign.center,
                    style:
                        textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
