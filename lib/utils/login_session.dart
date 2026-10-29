import 'dart:convert';

import '../models/login_response_model.dart';
import '../providers/language_provider.dart';
import '../services/staff_api.dart';
import 'constants.dart';
import 'language_pref.dart';
import 'seller_outlet_gate.dart';
import 'storage.dart';

/// Menyimpan sesi setelah login berhasil dan menentukan layar tujuannya. Dipakai bersama oleh layar Login
/// dan oleh verifikasi email lewat tautan (App Link, lihat deep_links.dart) supaya keduanya PERSIS sama.
class LoginSession {
  LoginSession._();

  /// Mengembalikan nama rute tujuan.
  static Future<String> save(
    LoginResponseModel r,
    String email, {
    String? rawCookie,
    LanguageProvider? lang,
  }) async {
    await Storage.set(AppConstants.accessTokenKey, r.bearerToken);
    await Storage.set(AppConstants.expiresAtKey, r.expiresAt.toString());
    await Storage.set(AppConstants.userNIPKey, r.username);
    await Storage.set(AppConstants.userEmail, email);
    await Storage.set(AppConstants.userRoleKey, r.role);
    await Storage.set(AppConstants.userGoldIdKey, r.goldId.toString());
    await Storage.set(AppConstants.userIsBuyerKey, r.buyerYn);
    await Storage.set(AppConstants.menuDaftarPembeliKey, r.menuDaftarPembeli);
    await Storage.set(AppConstants.menuModePembeliKey, r.menuModePembeli);
    await Storage.set(AppConstants.emailVerifiedKey, r.emailVerified.toString());
    await Storage.set(
        AppConstants.forceChangePasswordKey, r.forceChangePassword.toString());
    // Bahasa: pilihan manual di perangkat > bahasa bawaan negara akun > bawaan lama (lihat language_pref.dart).
    if (lang != null) {
      await lang.setLanguage(await languageAfterLogin(r.countryIso2),
          remember: false);
    }
    if (rawCookie != null) {
      final cookie = rawCookie.split(';').first;
      await Storage.set('refresh_cookie', cookie);
    }

    // Staff: cache menu yang TIDAK boleh diakses (dibaca app_drawer.dart).
    // Gagal fetch (network dll) -> anggap tidak ada yang ditolak, supaya
    // staff tidak tiba-tiba kehilangan semua menu. Non-staff: bersihkan
    // sisa cache akun STAFF sebelumnya di device yang sama.
    if (r.role == AppConstants.roleStaff) {
      try {
        final resp = await StaffApi().myDeniedMenus();
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          final keys = ((body['data'] ?? []) as List)
              .map((e) => e.toString())
              .toList();
          await Storage.setStaffDeniedMenuKeys(keys);
        }
      } catch (_) {
        // fail-open
      }
    } else {
      await Storage.setStaffDeniedMenuKeys([]);
    }

    // Tujuan setelah login berbeda per role: pembeli TIDAK melewati menu
    // pilih-outlet milik penjual (/outlet), melainkan langsung ke menu
    // pembeli (pilih outlet penjual → belanja). ADMIN juga tidak lewat
    // pilih-outlet -- semua layar admin (grup "Akses Admin") bersifat
    // global, tidak terikat 1 outlet -- langsung ke Dashboard.
    //
    // KECUALI email belum diverifikasi -- token yang baru saja disimpan
    // TETAP tidak bisa akses endpoint terproteksi apa pun sampai user
    // klik link verifikasi & login ULANG (lihat ValidateToken backend).
    String dest = '/outlet';
    if (!r.emailVerified) {
      dest = '/check-email';
    } else if (r.forceChangePassword == 1) {
      dest = '/ganti-password'; // password awal dari penjual: wajib diganti dulu
    } else if (r.role == AppConstants.roleBuyer) {
      final buyerOutlet = await Storage.get(AppConstants.buyerOutcodeKey);
      dest = (buyerOutlet == null || buyerOutlet.isEmpty)
          ? '/pilih-outlet'
          : '/belanja';
    } else if (r.role == AppConstants.roleAdmin) {
      dest = '/';
    } else if (r.role == AppConstants.roleSeller &&
        await SellerOutletGate.sellerNeedsTourFirst()) {
      // Penjual baru tanpa outlet: panduan pertama jalan DULU (dengan data contoh), baru wajib buat
      // outlet -- padanan alur web. Layar Dashboard cukup untuk memicu panduan.
      dest = '/';
    }
    return dest;
  }
}
