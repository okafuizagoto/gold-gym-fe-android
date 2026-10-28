import 'dart:convert';

import '../models/outlet_model.dart';
import '../services/onboarding_api.dart';
import '../services/outlet_api.dart';
import 'constants.dart';
import 'navigation.dart';
import 'onboarding_steps.dart';
import 'storage.dart';

/// Outlet DUMMY panduan penjual baru (2026-10-28) -- padanan web utils/outletDummy.ts dan backend
/// internal/entity/outlet DummyOutletPrefix. Dibuat otomatis sebelum panduan pertama (supaya tombol yang butuh
/// outlet, mis. ANTRIAN, bisa disorot) dan dihapus saat panduan selesai. Dikenali lewat KODE: "ADM-" + 10
/// karakter, bentuk yang tidak mungkin dihasilkan generator kode outlet biasa.
const String dummyOutletPrefix = 'ADM-';

bool isDummyOutletCode(String code) =>
    code.length == 14 && code.startsWith(dummyOutletPrefix);

/// Jumlah outlet ASLI (bukan dummy, belum dihapus). 0 = penjual belum punya outlet sama sekali.
int countRealOutlets(List<OutletResponse> outlets) => outlets
    .where((o) => !o.deleted && !isDummyOutletCode(o.outlet_code))
    .length;

/// Gerbang penjual (2026-10-28), padanan web components/SellerOutletGate.tsx: penjual yang BELUM punya outlet
/// asli tidak boleh membuka layar ber-drawer mana pun -- diarahkan ke /outlet (hanya NEW OUTLET dan LOGOUT yang
/// aktif). Pengecualian: selama panduan pertama BELUM selesai penjual baru boleh masuk ke Dashboard, karena
/// panduan itulah yang membuat outlet dummy dan menjelaskan cara membuat outlet.
class SellerOutletGate {
  SellerOutletGate._();

  // Penjual yang sudah terbukti punya outlet asli tidak dicek lagi selama aplikasi hidup.
  static String? _verifiedGoldId;

  static Future<bool> _isSellerView() async {
    final role = await Storage.get(AppConstants.userRoleKey) ?? '';
    final shopMode = await Storage.get(AppConstants.shopModeKey) ?? '';
    return role == AppConstants.roleSeller &&
        shopMode != AppConstants.shopModeBuyer;
  }

  /// Jumlah outlet asli penjual; null kalau gagal memuat (jangan mengunci penjual karena jaringan).
  static Future<int?> realOutletCount() async {
    try {
      final resp = await OutletsApi().getAllOutlet('', 'ACTIVE', 0, 0);
      if (resp.statusCode != 200) return null;
      return countRealOutlets(
          OutletPagination.fromJson(jsonDecode(resp.body)).data);
    } catch (_) {
      return null;
    }
  }

  /// Dipakai login_screen: penjual tanpa outlet asli yang BELUM melihat panduan diarahkan ke Dashboard
  /// (panduan jalan dulu), bukan langsung ke /outlet.
  static Future<bool> sellerNeedsTourFirst() async {
    if (await realOutletCount() != 0) return false;
    return !(await OnboardingApi().isSeen(onboardingRoleSeller));
  }

  /// Dipanggil dari tiap layar ber-drawer (AppBarCustom).
  static Future<void> check() async {
    if (!await _isSellerView()) return;
    final goldId = await Storage.get(AppConstants.userGoldIdKey) ?? '';
    if (goldId.isNotEmpty && _verifiedGoldId == goldId) return;
    final real = await realOutletCount();
    if (real == null) return; // gagal cek -> jangan mengunci
    if (real > 0) {
      _verifiedGoldId = goldId;
      return;
    }
    if (!await OnboardingApi().isSeen(onboardingRoleSeller)) {
      return; // panduan pertama akan jalan dan membuat outlet dummy
    }
    // Sudah melihat panduan tapi tetap tanpa outlet asli: bersihkan dummy yang mungkin tertinggal, lalu paksa ke /outlet.
    try {
      await OutletsApi().clearDummyOutlet();
    } catch (_) {}
    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/outlet', (route) => false);
  }
}
