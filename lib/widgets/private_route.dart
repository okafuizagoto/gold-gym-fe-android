import 'package:flutter/material.dart';
import '../utils/storage.dart';
import '../utils/constants.dart';

/// Guard halaman:
/// - tanpa token → redirect ke /login
/// - [sellerOnly] true dan role BUYER → redirect ke layar belanja pembeli
///   (menu khusus penjual/admin: dashboard, POS penjual, stock, add items,
///   daftar pembeli, add menu)
class PrivateRoute extends StatefulWidget {
  final Widget child;
  final bool sellerOnly;

  const PrivateRoute({super.key, required this.child, this.sellerOnly = false});

  @override
  State<PrivateRoute> createState() => _PrivateRouteState();
}

class _PrivateRouteState extends State<PrivateRoute> {
  // Dimuat SEKALI saja di initState -- kalau dibuat ulang di build() (mis.
  // dulu lewat StatelessWidget yang panggil _loadAuth() langsung di build),
  // setiap setState() di halaman manapun yang dibungkus PrivateRoute akan
  // membuat FutureBuilder balik ke status "waiting" dan membongkar-pasang
  // ulang seluruh isi halaman (child) dari nol setiap saat -- termasuk
  // mem-batalkan BuildContext yang sedang dipegang kode lain (toast/navigasi
  // yang dipanggil setelah setState jadi gagal diam-diam).
  late final Future<Map<String, String?>> _authFuture = _loadAuth();

  Future<Map<String, String?>> _loadAuth() async {
    return {
      'token': await Storage.get(AppConstants.accessTokenKey),
      'role': await Storage.get(AppConstants.userRoleKey),
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: _authFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final token = snapshot.data?['token'];
        if (token == null || token.isEmpty) {
          // Tidak ada token -- bersihkan SELURUH stack (bukan cuma ganti
          // route teratas) supaya tombol kembali di layar login tidak bisa
          // membuka lagi layar yang butuh login (mis. dashboard) yang
          // sempat tertinggal di bawahnya.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(
                context, '/login', (route) => false);
          });
          return const SizedBox.shrink();
        }

        if (widget.sellerOnly &&
            snapshot.data?['role'] == AppConstants.roleBuyer) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/belanja');
          });
          return const SizedBox.shrink();
        }

        return widget.child;
      },
    );
  }
}
