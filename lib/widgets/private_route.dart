import 'package:flutter/material.dart';
import '../utils/storage.dart';
import '../utils/constants.dart';
import '../utils/subscription_state.dart';

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

  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void initState() {
    super.initState();
    _showSubscriptionBanner();
  }

  @override
  void dispose() {
    // banner milik layar ini; layar berikutnya (kalau butuh) menampilkannya lagi
    _messenger?.clearMaterialBanners();
    super.dispose();
  }

  /// Pita pemberitahuan masa percobaan / mode baca-saja (hanya penjual & staff, dan tidak
  /// di layar Langganan sendiri). Status dimuat dari cache dulu lalu disegarkan dari backend.
  Future<void> _showSubscriptionBanner() async {
    final role = await Storage.get(AppConstants.userRoleKey);
    if (role != AppConstants.roleSeller && role != AppConstants.roleStaff) {
      return;
    }
    await SubscriptionState.load();
    final fresh = await SubscriptionState.refresh();
    final s = fresh ?? SubscriptionState.current;
    if (!mounted || s == null) return;
    if (ModalRoute.of(context)?.settings.name == '/langganan') return;

    final String? text;
    final Color bg;
    if (s.readOnly) {
      text =
          'Langganan Anda sudah berakhir. Aplikasi dalam mode baca saja: data tetap bisa dilihat, tetapi tidak bisa ditambah atau diubah.';
      bg = const Color(0xFFFEE2E2);
    } else if (s.status == 'TRIAL') {
      final left = s.daysLeft ?? 0;
      text =
          'Masa percobaan gratis: sisa $left hari. Setelah itu aplikasi menjadi baca saja sampai Anda memilih paket.';
      bg = left <= 3 ? const Color(0xFFFEF3C7) : const Color(0xFFE8F1FD);
    } else {
      text = null;
      bg = Colors.transparent;
    }
    final messenger = _messenger;
    if (text == null || messenger == null) return;
    messenger
      ..clearMaterialBanners()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: bg,
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () {
                messenger.clearMaterialBanners();
                Navigator.pushNamed(context, '/langganan');
              },
              child: const Text('Lihat paket'),
            ),
            TextButton(
              onPressed: () => messenger.clearMaterialBanners(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
  }

  Future<Map<String, String?>> _loadAuth() async {
    return {
      'token': await Storage.get(AppConstants.accessTokenKey),
      'role': await Storage.get(AppConstants.userRoleKey),
      'emailVerified': await Storage.get(AppConstants.emailVerifiedKey),
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

        // Token "belum terverifikasi" ditolak backend di SEMUA endpoint
        // terproteksi -- redirect ke /check-email alih-alih biarkan layar
        // ini render lalu gagal diam-diam / 403 berulang.
        if (snapshot.data?['emailVerified'] == 'false') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(
                context, '/check-email', (route) => false);
          });
          return const SizedBox.shrink();
        }

        return widget.child;
      },
    );
  }
}
