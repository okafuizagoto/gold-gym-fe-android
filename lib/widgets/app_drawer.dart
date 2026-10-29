import 'dart:convert';
import '../services/sales_api.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../utils/storage.dart';
import '../utils/constants.dart';
import '../utils/subscription_state.dart';
import '../services/core_api.dart';
import '../services/feature_request_api.dart';
import '../utils/toast.dart';
import 'brand_logo.dart';
import 'onboarding_tour.dart';

/// Dua bendera dari SERVER yang memengaruhi isi drawer. Dulu drawer menunggu keduanya (2 request berurutan)
/// SEBELUM menggambar satu menu pun -> tiap membuka drawer terasa macet. Sekarang dipakai nilai terakhir yang
/// diketahui (memori, lalu penyimpanan lokal), menu langsung tampil, dan bendera disegarkan di latar belakang.
class _DrawerFlags {
  static bool? requestApp; // menu "Request Aplikasi Baru" boleh tampil
  static bool? proof; // fitur bukti bayar/QRIS aktif untuk akun ini
  static DateTime? _lastRefresh;
  static String? _owner; // cache hanya berlaku untuk akun ini (bendera ini per akun)
  static Future<bool>? _inflight;

  static const _kRequestApp = 'drawer_flag_request_app';
  static const _kProof = 'drawer_flag_proof';

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getString(AppConstants.userGoldIdKey) ?? '';
    if (_owner == owner) return;
    // akun berganti (login/logout): buang nilai akun sebelumnya
    _owner = owner;
    _lastRefresh = null;
    final a = prefs.getString(_kRequestApp);
    final b = prefs.getString(_kProof);
    requestApp = a == null ? null : a == 'Y';
    proof = b == null ? null : b == 'Y';
  }

  static bool get known => requestApp != null && proof != null;

  /// Segarkan kedua bendera PARALEL (dengan batas waktu). true = ada yang berubah. Dibatasi 1x/45 dtk
  /// kecuali [force] (pertama kali belum ada nilai sama sekali).
  static Future<bool> refresh({bool force = false}) {
    final last = _lastRefresh;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 45)) {
      return Future.value(false);
    }
    return _inflight ??= _doRefresh().whenComplete(() => _inflight = null);
  }

  static Future<bool> _doRefresh() async {
    var changed = false;
    final r = await Future.wait<Object?>([
      FeatureRequestApi()
          .getEnabled()
          .timeout(const Duration(seconds: 5), onTimeout: () => true),
      () async {
        try {
          final res = await SalesApi()
              .getProofVisibility('')
              .timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            return jsonDecode(res.body)['enabled'] != false;
          }
        } catch (_) {}
        return null; // gagal: pertahankan nilai lama
      }(),
    ]);
    _lastRefresh = DateTime.now();
    final a = r[0] as bool;
    final b = r[1] as bool?;
    if (requestApp != a) {
      requestApp = a;
      changed = true;
      await (await SharedPreferences.getInstance())
          .setString(_kRequestApp, a ? 'Y' : 'N');
    }
    if (b != null && proof != b) {
      proof = b;
      changed = true;
      await (await SharedPreferences.getInstance())
          .setString(_kProof, b ? 'Y' : 'N');
    } else if (proof == null) {
      proof = false; // belum pernah berhasil dicek -> sembunyikan (sama seperti perilaku lama)
    }
    return changed;
  }
}

/// Menu samping (web: Sidebar): latar putih, logo bergradasi, item aktif
/// disorot biru muda, grup menu bisa dibuka-tutup, Logout merah di bawah.
/// Daftar menu & aturan role/outlet/mode di [_loadMenuItems] TIDAK berubah.
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  List<MenuItem> menuItems = [];

  final _coreApi = CoreApi();

  // Panduan Penggunaan (2026-10-22): GlobalKey per judul menu top-level supaya
  // OnboardingTour bisa menyorot menu drawer asli (lihat widgets/onboarding_tour.dart).
  final Map<String, GlobalKey> _tourKeys = {};
  GlobalKey _tourKey(String title) =>
      _tourKeys.putIfAbsent(title, () => GlobalKey(debugLabel: 'tour-$title'));

  GlobalKey? _keyForTour(String title) => _tourKeys[title];

  // Grup menu (mis. "Kas") menyembunyikan anak-anaknya saat tertutup: panduan perlu membukanya dulu supaya
  // anak yang disorot (Kas History, Tarik Kas, Tambah Kas) ada di layar. Kunci grup per judul grup.
  final Map<String, GlobalKey<_DrawerGroupState>> _groupKeys = {};

  /// Buka grup yang memuat menu berjudul [title]; true kalau ada grup yang dibuka.
  bool _expandGroupFor(String title) {
    for (final item in menuItems) {
      final kids = item.children;
      if (kids == null || !kids.any((c) => c.title == title)) continue;
      final st = _groupKeys[item.title]?.currentState;
      if (st == null) return false;
      st.expand();
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    OnboardingTour.drawerKeyFor = _keyForTour;
    OnboardingTour.drawerExpandFor = _expandGroupFor;
    _loadMenuItems();
  }

  @override
  void dispose() {
    if (OnboardingTour.drawerKeyFor == _keyForTour) {
      OnboardingTour.drawerKeyFor = null;
    }
    if (OnboardingTour.drawerExpandFor == _expandGroupFor) {
      OnboardingTour.drawerExpandFor = null;
    }
    super.dispose();
  }

  Future<void> _loadMenuItems({bool refreshFlags = true}) async {
    // Menu menyesuaikan role (ADMIN/SELLER/BUYER), tipe outlet, dan MODE:
    // penjual/admin bisa beralih ke "mode pembeli" (berbelanja di outlet lain
    // sebagai pembeli — nota menampilkan nama toko miliknya) lalu kembali.
    // - Mode penjual : dashboard, booking terapi, POS, sales history, stock,
    //                  add items, daftar pembeli, ganti outlet, about us
    // - Mode pembeli / role BUYER : booking terapi, Point of Sale (belanja),
    //                  List Barang, riwayat belanja, about us
    final role =
        await Storage.get(AppConstants.userRoleKey) ?? AppConstants.roleSeller;
    final outletType =
        await Storage.get(AppConstants.outletTypeKey) ?? 'RETAIL';
    final shopMode = await Storage.get(AppConstants.shopModeKey) ?? '';
    // flag akun sudah mendaftar sebagai pembeli (gold_buyer_yn)
    final isRegisteredBuyer =
        (await Storage.get(AppConstants.userIsBuyerKey) ?? 'N') == 'Y';
    // flag ADMIN: paksa sembunyikan menu Daftar Pembeli / Mode Pembeli
    // (default 'Y' = tampil, lihat layar admin Akses Daftar/Mode Pembeli)
    final menuDaftarPembeliEnabled =
        (await Storage.get(AppConstants.menuDaftarPembeliKey) ?? 'Y') == 'Y';
    final menuModePembeliEnabled =
        (await Storage.get(AppConstants.menuModePembeliKey) ?? 'Y') == 'Y';
    // flag ADMIN global: sembunyikan menu Request Aplikasi Baru dari semua user (app_settings,
    // dicek langsung ke server tiap layar ini dibuka -- bukan dicache saat login seperti 2 flag
    // di atas, karena ini bukan bagian respons login).
    await _DrawerFlags.restore();
    if (!_DrawerFlags.known) {
      await _DrawerFlags.refresh(force: true); // hanya pertama kali di perangkat ini
    } else if (refreshFlags) {
      // menu langsung digambar dari nilai terakhir; kalau di server ternyata berubah, bangun ulang
      _DrawerFlags.refresh().then((changed) {
        if (changed && mounted) _loadMenuItems(refreshFlags: false);
      });
    }
    final menuRequestAplikasiBaruEnabled = _DrawerFlags.requestApp ?? true;
    // Fitur foto bukti bayar + QRIS (Akses Admin > Visibilitas Bukti Pembayaran): menu QRIS Outlet
    // ikut hilang kalau dimatikan untuk user ini.
    final proofFeatureEnabled = _DrawerFlags.proof ?? false;
    final isRealBuyer = role == AppConstants.roleBuyer;
    final isAdmin = role == AppConstants.roleAdmin;
    // penjual (retail & therapy sama-sama SELLER; dibedakan outlet_type)
    final isSeller = role == AppConstants.roleSeller;
    // karyawan yang didaftarkan owner (lihat menu Staff) -- lewat middleware
    // backend, data yang diakses staff otomatis data milik owner-nya
    final isStaff = role == AppConstants.roleStaff;
    // tampilan pembeli: role BUYER asli, atau penjual/admin dalam mode pembeli
    final buyerView = isRealBuyer || shopMode == AppConstants.shopModeBuyer;
    final isTherapy = outletType == AppConstants.outletTherapy;

    // Static routes
    final staticRoutes = <MenuItem>[
      if (!buyerView)
        MenuItem(
          title: 'Dashboard',
          icon: Icons.dashboard,
          route: '/',
        ),
      // menu wajib staff -- clock-in/out sendiri, TIDAK PERNAH ikut filter
      // denied-menu (lihat penggabungan di bawah)
      if (isStaff)
        MenuItem(
          title: 'Absen',
          icon: Icons.fingerprint,
          route: '/absen',
        ),
      // ADMIN tidak mengoperasikan outlet manapun -- menu operasional
      // outlet (Booking Terapi, POS, dst.) di bawah ini semua digerbang
      // "&& !isAdmin" supaya drawer admin hanya berisi menu yang benar-benar
      // berhubungan dengan tugas admin (grup "Akses Admin").
      if (isTherapy && !isAdmin)
        MenuItem(
          title: 'Booking Terapi',
          icon: Icons.event_available,
          route: '/booking',
          feature: 'booking',
        ),
      if (!buyerView && !isAdmin)
        MenuItem(
          title: 'Point of Sale',
          icon: Icons.point_of_sale,
          route: '/penjualan',
        ),
      // Sesi Kasir (2026-10-10): buka/tutup shift + rekonsiliasi kas, sama kondisi tampil dgn POS.
      // Semua menu terkait kas dijadikan satu grup "Kas" (2026-10-28): Sesi Kasir, Kas History, Tarik Kas, Tambah Kas.
      // Staff: anak grup difilter denied_menu_keys seperti menu lain; Sesi Kasir selalu tampil.
      if (!buyerView && !isAdmin)
        MenuItem(
          title: 'Kas',
          icon: Icons.account_balance_wallet_rounded,
          route: '',
          children: [
            MenuItem(
                title: 'Sesi Kasir',
                icon: Icons.point_of_sale_outlined,
                route: '/cashier-shift'),
            if (isSeller || isStaff) ...[
              MenuItem(
                  title: 'Kas History',
                  icon: Icons.account_balance_wallet_rounded,
                  route: '/kas-history'),
              MenuItem(
                  title: 'Tarik Kas',
                  icon: Icons.savings_rounded,
                  route: '/tarik-kas'),
              MenuItem(
                  title: 'Tambah Kas',
                  icon: Icons.add_card_rounded,
                  route: '/tambah-kas'),
            ],
          ],
        ),
      // Printer Thermal (2026-10-10): pilih/ingat printer Bluetooth untuk cetak struk
      // ESC/POS langsung, sama kondisi tampil dgn POS.
      if (!buyerView && !isAdmin)
        MenuItem(
          title: 'Printer Thermal',
          icon: Icons.print_outlined,
          route: '/thermal-printer',
        ),
      // mode pembeli: pilih outlet penjual dulu, lalu pesan barang
      if (buyerView)
        MenuItem(
          title: 'Pilih Outlet',
          icon: Icons.store_mall_directory,
          route: '/pilih-outlet',
        ),
      if (buyerView)
        MenuItem(
          title: 'Pesan Barang',
          icon: Icons.shopping_bag,
          route: '/belanja',
        ),
      // dashboard pesanan pembeli (status & detail)
      if (buyerView)
        MenuItem(
          title: 'Pesanan Saya',
          icon: Icons.receipt_long,
          route: '/pesanan-saya',
        ),
      // menu penjual: menampung pesanan masuk pembeli (outlet non-THERAPY saja)
      if (!buyerView && !isTherapy && !isAdmin)
        MenuItem(
          title: 'Pesanan Masuk',
          icon: Icons.inbox,
          route: '/pesanan-masuk',
        ),
      if (!buyerView && !isAdmin)
        MenuItem(
          title: 'Sales History',
          icon: Icons.receipt_long,
          route: '/history-sales',
        ),
      // Riwayat Refund (2026-10-28): penjual dan staff yang diizinkan penjual (menu_key "/riwayat-refund").
      if (!buyerView && !isAdmin && (isSeller || isStaff))
        MenuItem(
          title: 'Riwayat Refund',
          icon: Icons.replay_rounded,
          route: '/riwayat-refund',
        ),
      // Antrean Transaksi: nota offline yang menunggu dikirim (offline-first).
      if (!buyerView && !isAdmin && (isSeller || isStaff))
        MenuItem(
          title: 'Antrean Transaksi',
          icon: Icons.sync,
          route: '/antrean-transaksi',
        ),
      // Antrian POS: papan nomor antrian, aktif/nonaktifkan dari Daftar Outlet (2026-09-30).
      if (!buyerView && !isAdmin && (isSeller || isStaff))
        MenuItem(
          title: 'Antrian POS',
          icon: Icons.format_list_numbered_rounded,
          route: '/antrian-pos',
        ),
      if (buyerView)
        MenuItem(
          title: 'Antrian Saya',
          icon: Icons.format_list_numbered_rounded,
          route: '/antrian-saya',
        ),
      // PENJUAL (retail & therapy): satu menu laporan penjualan; per hari /
      // minggu / bulan dipilih lewat TAB di dalam layarnya.
      if (!buyerView && (isSeller || isStaff))
        MenuItem(
          title: 'Laporan Penjualan',
          icon: Icons.assessment,
          route: '/laporan',
        ),
      // Pencatatan Pengeluaran: ledger biaya operasional per outlet
      // (sewa/listrik/gaji/dst), berdampingan dengan Laporan Penjualan.
      // Sama seperti Stock/Items, staff yang bekerja untuk penjual ikut
      // bisa mencatat -- hapus tetap dibatasi pemilik outlet asli
      // (lihat requireRealSeller di backend).
      if (!buyerView && (isSeller || isStaff))
        MenuItem(
          title: 'Pencatatan Pengeluaran',
          icon: Icons.payments_outlined,
          route: '/expense',
          feature: 'expenses',
        ),
      // ADMIN: grup "Akses Admin" yang bisa di-show/hide (ExpansionTile).
      // Isinya menu pengaturan akses fitur yang khusus admin:
      // - Outlet untuk Pembeli        : outlet mana yang boleh dilihat & dipesan pembeli
      // - POS Tanpa Customer          : penjual RETAIL yang boleh POS tanpa isi customer
      // - Visibilitas Bukti Pembayaran: aktif/nonaktifkan fitur upload & lihat
      //   foto bukti transfer (global / per outlet / per user)
      // - Daftar Akun: batasi mode pendaftaran mandiri (Daftar Akun) jadi
      //   pembeli saja / penjual saja / bisa memilih keduanya
      if (!buyerView && isAdmin)
        MenuItem(
          title: 'Akses Admin',
          icon: Icons.admin_panel_settings,
          route: '',
          children: [
            MenuItem(
              title: 'Outlet untuk Pembeli',
              icon: Icons.storefront,
              route: '/admin-outlet-pembeli',
            ),
            MenuItem(
              title: 'POS Tanpa Customer',
              icon: Icons.person_off,
              route: '/admin-pos-customer',
            ),
            MenuItem(
              title: 'Visibilitas Bukti Pembayaran',
              icon: Icons.image_outlined,
              route: '/admin-proof-access',
            ),
            MenuItem(
              title: 'Daftar Akun',
              icon: Icons.how_to_reg,
              route: '/admin-registration-mode',
            ),
            MenuItem(
              title: 'Tipe Outlet',
              icon: Icons.category_rounded,
              route: '/admin-outlet-type-settings',
            ),
            MenuItem(
              title: 'Tampilan Langganan',
              icon: Icons.workspace_premium_outlined,
              route: '/admin-langganan-tampilan',
            ),
            MenuItem(
              title: 'Harga & Diskon Paket',
              icon: Icons.sell_outlined,
              route: '/admin-plan-pricing',
            ),
            MenuItem(
              title: 'Fitur per Paket',
              icon: Icons.tune_rounded,
              route: '/admin-plan-features',
            ),
            MenuItem(
              title: 'Akses Daftar Pembeli',
              icon: Icons.person_add_alt,
              route: '/admin-akses-daftar-pembeli',
            ),
            MenuItem(
              title: 'Akses Mode Pembeli',
              icon: Icons.swap_horizontal_circle_outlined,
              route: '/admin-akses-mode-pembeli',
            ),
            MenuItem(
              title: 'Laporan Pembayaran QRIS',
              icon: Icons.receipt_long_outlined,
              route: '/admin-payment-report',
            ),
            MenuItem(
              title: 'Penggunaan Storage (B2)',
              icon: Icons.data_usage,
              route: '/admin-storage-usage',
            ),
            MenuItem(
              title: 'Statistik Pengguna',
              icon: Icons.insights_outlined,
              route: '/admin-statistik-pengguna',
            ),
            MenuItem(
              title: 'Kelola Akun (Ban)',
              icon: Icons.block,
              route: '/admin-akun',
            ),
            MenuItem(
              title: 'Daftar Request Fitur',
              icon: Icons.feedback_outlined,
              route: '/admin-request-fitur',
            ),
            MenuItem(
              title: 'Backup Data Harian',
              icon: Icons.backup_outlined,
              route: '/admin-backup',
            ),
          ],
        ),
      // Atur Meja: khusus penjual retail (non-THERAPY) -- kelola area
      // (indoor/outdoor), meja per area, dan kosongkan meja yang sudah
      // selesai dipakai.
      if (!buyerView && (isSeller || isStaff) && !isTherapy)
        MenuItem(
          title: 'Atur Meja',
          icon: Icons.table_restaurant,
          route: '',
          children: [
            MenuItem(
                title: 'Meja & Area',
                icon: Icons.table_bar,
                route: '/meja-area'),
            MenuItem(
                title: 'Kelola Meja',
                icon: Icons.event_seat,
                route: '/kelola-meja'),
          ],
        ),
      // Lokasi Kantor untuk STAFF yang diizinkan owner (menu_key "/lokasi-kantor" lewat Akses Staff;
      // difilter denied_menu_keys di bawah seperti menu lain). Owner mengaksesnya dari grup Staff.
      if (!buyerView && isStaff)
        MenuItem(
          title: 'Lokasi Kantor',
          icon: Icons.place_outlined,
          route: '/lokasi-kantor',
        ),
      // Staff: khusus owner penjual (retail & therapy) -- kelola akun staff,
      // akses menu tiap staff, dan pantau absensi. Staff sendiri TIDAK
      // pernah melihat grup ini.
      if (!buyerView && isSeller && !isStaff)
        MenuItem(
          title: 'Staff',
          icon: Icons.badge_outlined,
          route: '',
          children: [
            MenuItem(
                title: 'Daftar Staff',
                icon: Icons.people_alt_outlined,
                route: '/daftar-staff',
                feature: 'staff_management'),
            MenuItem(
                title: 'Akses Staff',
                icon: Icons.checklist_outlined,
                route: '/akses-staff',
                feature: 'staff_management'),
            MenuItem(
                title: 'Absen Staff',
                icon: Icons.event_note_outlined,
                route: '/absen-staff',
                feature: 'staff_management'),
            MenuItem(
                title: 'Lokasi Kantor',
                icon: Icons.place_outlined,
                route: '/lokasi-kantor',
                feature: 'staff_management'),
            if (!isTherapy)
              MenuItem(
                  title: 'Izin Transfer Stok',
                  icon: Icons.rule,
                  route: '/izin-transfer-staff',
                  feature: 'staff_management'),
          ],
        ),
      if (!buyerView && !isAdmin)
        MenuItem(
          title: 'Stock',
          icon: Icons.inventory,
          route: '/stock-barang',
        ),
      // Transfer Stok: kirim stok antar outlet + surat jalan (retail saja).
      if (!buyerView && !isAdmin && !isTherapy && (isSeller || isStaff))
        MenuItem(
          title: 'Transfer Stok',
          icon: Icons.local_shipping_outlined,
          route: '/transfer-stok',
        ),
      if (!buyerView && !isAdmin)
        MenuItem(
          title: 'Items',
          icon: Icons.inventory,
          route: '',
          children: [
            MenuItem(
                title: 'Add Items', icon: Icons.add_box, route: '/add-items'),
            MenuItem(
                title: 'Diskon',
                icon: Icons.percent,
                route: '/diskon',
                feature: 'discount_voucher'),
          ],
        ),
      // penjual: kelola daftar customer (tabel customer) — tambah 1 / massal
      if (!buyerView && !isAdmin)
        MenuItem(
          title: 'Daftar Customer',
          icon: Icons.contacts,
          route: '/daftar-customer',
        ),
      // Tipe Pelanggan: kategori opsional pelanggan (mis. Reguler/Member/Grosir) per outlet.
      if (!buyerView && !isAdmin)
        MenuItem(
          title: 'Tipe Pelanggan',
          icon: Icons.label_outline_rounded,
          route: '/customer-type',
          feature: 'customers',
        ),
      // Daftar Pembeli hanya tampil sebelum akun terdaftar sebagai pembeli;
      // setelah konfirmasi, menu ini hilang dan Mode Pembeli muncul.
      // Bisa juga dipaksa sembunyi oleh admin (menuDaftarPembeliEnabled).
      // ADMIN tidak butuh berbelanja sebagai pembeli, jadi menu ini juga
      // tidak relevan untuknya.
      if (!buyerView &&
          !isRegisteredBuyer &&
          menuDaftarPembeliEnabled &&
          !isAdmin)
        MenuItem(
          title: 'Daftar Pembeli',
          icon: Icons.person_add,
          route: '/daftar-pembeli',
        ),
      // penjual bisa pindah outlet tanpa logout. ADMIN tidak beroperasi di
      // 1 outlet manapun (semua layar admin bersifat global), jadi menu
      // ini tidak berpengaruh untuknya dan disembunyikan.
      if (!buyerView && !isAdmin)
        MenuItem(
          title: 'Ganti Outlet',
          icon: Icons.store,
          route: '/outlet',
        ),
      // beralih mode penjual <-> pembeli (khusus penjual yang SUDAH
      // terdaftar sebagai pembeli lewat menu Daftar Pembeli). Bisa juga
      // dipaksa sembunyi oleh admin (menuModePembeliEnabled). Tidak relevan
      // untuk ADMIN.
      if (!isRealBuyer &&
          !buyerView &&
          isRegisteredBuyer &&
          menuModePembeliEnabled &&
          !isAdmin &&
          !isStaff)
        MenuItem(
          title: 'Mode Pembeli',
          icon: Icons.swap_horiz,
          route: '/switch-buyer',
        ),
      // Daftar Penjual (2026-10-07, kebalikan Daftar Pembeli): hanya untuk akun yang BENAR-BENAR
      // BUYER (bukan SELLER yang sedang buyerView) -- upgrade gold_role jadi SELLER, tetap bisa
      // pakai Mode Pembeli setelahnya.
      if (isRealBuyer)
        MenuItem(
          title: 'Daftar Penjual',
          icon: Icons.storefront_outlined,
          route: '/daftar-penjual',
        ),
      if (!isRealBuyer && buyerView && !isAdmin && !isStaff)
        MenuItem(
          title: 'Mode Penjual',
          icon: Icons.swap_horiz,
          route: '/switch-seller',
        ),
      // Langganan: paket, batas outlet/pengguna, dan fitur akun (penjual & staff).
      if (!buyerView && !isAdmin && !isRealBuyer)
        MenuItem(
          title: 'Langganan',
          icon: Icons.workspace_premium_outlined,
          route: '/langganan',
        ),
      // Storage: daftar & hapus foto (item katalog + bukti pembayaran) milik
      // akun sendiri, dengan kuota 30MB -- semua role KECUALI ADMIN (admin
      // tidak punya kuota storage).
      if (!isAdmin)
        MenuItem(
          title: 'Storage',
          icon: Icons.sd_storage_outlined,
          route: '/storage',
        ),
      // Request Fitur: kotak saran -- ide fitur baru atau laporan
      // perbaikan pada 1 menu. Semua role non-admin (penjual retail &
      // therapy, pembeli, staff) boleh mengajukan; admin punya menu
      // terpisah "Daftar Request Fitur" di grup Akses Admin di bawah.
      if (!isAdmin)
        MenuItem(
          title: 'Request Fitur',
          icon: Icons.feedback_outlined,
          route: '/request-fitur',
        ),
      // Request Aplikasi Baru: ide APLIKASI terpisah (bukan fitur di dalam
      // Okejual), mis. "aplikasi kas harian". Semua role non-admin; admin
      // lihat hasilnya di "Daftar Request Fitur" (filter tipe Aplikasi Baru).
      if (!isAdmin && menuRequestAplikasiBaruEnabled)
        MenuItem(
          title: 'Request Aplikasi Baru',
          icon: Icons.apps_outlined,
          route: '/request-aplikasi-baru',
        ),
      // QRIS Outlet (2026-09-25): menggantikan QRIS Saya per-akun.
      if (!buyerView && isSeller && !isStaff && proofFeatureEnabled)
        MenuItem(
          title: 'QRIS Outlet',
          icon: Icons.qr_code_2,
          route: '/qris-outlet',
        ),
      MenuItem(
        title: 'Edit Profil',
        icon: Icons.account_circle_outlined,
        route: '/edit-profil',
      ),
      MenuItem(
        title: 'Keamanan Akun',
        icon: Icons.lock_person_outlined,
        route: '/keamanan-akun',
      ),
      MenuItem(
        title: 'About Us',
        icon: Icons.info,
        route: '/about-us',
      ),
      // Panduan Penggunaan (2026-10-22): ulangi tour tooltip dari awal. Bukan
      // untuk ADMIN -- admin punya Quick Menu Admin sendiri di Dashboard.
      if (!isAdmin)
        MenuItem(
          title: 'Panduan Penggunaan',
          icon: Icons.tour_rounded,
          route: '/panduan-penggunaan',
        ),
    ];

    // Custom routes from storage
    final customMenus = await Storage.getUserMenus();
    final customRoutes = customMenus.map((menu) {
      return MenuItem(
        title: menu['menu'] ?? '',
        icon: _getIconFromName(menu['iconName']),
        route: '/${menu['path']}',
      );
    }).toList();

    // Fitur paket: yang belum ada di paket tampil dengan gembok dan mengarah ke layar
    // Langganan. Hanya penjual/staff (pembeli & admin tidak dibatasi paket).
    await SubscriptionState.load();
    MenuItem gateByPlan(MenuItem it) {
      if (it.children != null) {
        return MenuItem(
          title: it.title,
          icon: it.icon,
          route: it.route,
          children: it.children!.map(gateByPlan).toList(),
        );
      }
      if (!isAdmin &&
          !buyerView &&
          it.feature != null &&
          !SubscriptionState.hasFeature(it.feature!)) {
        return MenuItem(
          title: it.title,
          icon: it.icon,
          route: '/langganan',
          feature: it.feature,
          locked: true,
        );
      }
      return it;
    }

    var allItems = [...staticRoutes.map(gateByPlan), ...customRoutes];

    // Staff: sembunyikan menu (termasuk anak grup) yang route-nya ada di
    // denied_menu_keys milik akun ini (cache diisi saat login, lihat
    // login_screen.dart) -- KECUALI About Us & Absen, selalu tampil apa pun
    // izinnya.
    if (isStaff) {
      final denied = await Storage.getStaffDeniedMenuKeys();
      bool allowed(String route) =>
          route == '/about-us' ||
          route == '/absen' ||
          route == '/panduan-penggunaan' ||
          !denied.contains(route);
      allItems = allItems
          .where((item) => allowed(item.route))
          .map((item) {
            if (item.children == null) return item;
            final children =
                item.children!.where((c) => allowed(c.route)).toList();
            return MenuItem(
              title: item.title,
              icon: item.icon,
              route: item.route,
              children: children,
              feature: item.feature,
              locked: item.locked,
            );
          })
          .where((item) => item.children == null || item.children!.isNotEmpty)
          .toList();
    }

    if (!mounted) return;
    setState(() {
      menuItems = allItems;
    });
  }

  IconData _getIconFromName(String? iconName) {
    switch (iconName) {
      case 'DashboardIcon':
        return Icons.dashboard;
      case 'InfoIcon':
        return Icons.info;
      case 'BarChartIcon':
        return Icons.bar_chart;
      default:
        return Icons.circle;
    }
  }

  // Navigasi saat menu (atau anak menu di grup) ditekan. Dipisah jadi helper
  // supaya dipakai ulang oleh ListTile biasa maupun anak ExpansionTile.
  Future<void> _onMenuTap(MenuItem item) async {
    if (item.route == '/panduan-penggunaan') {
      // tutup drawer dulu; tour membukanya lagi sendiri untuk tiap langkah menu
      Navigator.pop(context);
      await Future.delayed(const Duration(milliseconds: 350));
      await OnboardingTour.start();
      return;
    }
    Navigator.pop(context); // Close drawer
    if (item.route == '/outlet') {
      // ganti outlet: bersihkan stack supaya layar lama
      // (dengan data outlet sebelumnya) tidak tersisa
      Navigator.pushNamedAndRemoveUntil(context, '/outlet', (route) => false);
    } else if (item.route == '/switch-buyer') {
      // penjual/admin beralih berbelanja sebagai pembeli;
      // wajib pilih outlet dulu jika belum pernah memilih
      await Storage.set(AppConstants.shopModeKey, AppConstants.shopModeBuyer);
      if (!mounted) return;
      // selalu mulai dari Pilih Outlet: layar itu memulihkan
      // outlet tersimpan ke keranjang pesanan sebelum belanja
      Navigator.pushNamedAndRemoveUntil(
          context, '/pilih-outlet', (route) => false);
    } else if (item.route == '/switch-seller') {
      // kembali ke mode penjual
      await Storage.set(AppConstants.shopModeKey, '');
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } else if (item.locked) {
      // fitur belum ada di paket: arahkan ke Langganan dengan penanda fiturnya
      Navigator.pushNamed(context, '/langganan', arguments: item.feature);
    } else {
      Navigator.pushNamed(context, item.route);
    }
  }

  Future<void> _logout() async {
    try {
      final response = await _coreApi.logout();
      if (response.statusCode == 200) {
        Storage.clear();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        Toast.error(context, 'Login failed.');
      }
    } catch (e) {
      Toast.error(context, 'Login failed.');
    }
  }

  bool _isActive(String currentRoute, String route) {
    if (route.isEmpty) return false;
    if (route == '/') return currentRoute == '/';
    return currentRoute == route || currentRoute.startsWith('$route/');
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '';
    final textTheme = Theme.of(context).textTheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header logo (web: Sidebar header)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                children: [
                  const BrandLogo(size: 64),
                  const SizedBox(height: 10),
                  Text(
                    AppConstants.appName,
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.blue,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    'v${AppConstants.version}',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(),

            // Menu Items
            Expanded(
              child: ListView.builder(
                // render semua menu (bukan cuma yang kelihatan) supaya GlobalKey
                // panduan tooltip punya context untuk menu di luar layar
                cacheExtent: 4000,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: menuItems.length,
                itemBuilder: (context, index) {
                  final item = menuItems[index];
                  // Menu grup (punya children) -> tampil sebagai ExpansionTile
                  // yang bisa di-show/hide. Contoh: "Akses Admin".
                  if (item.children != null && item.children!.isNotEmpty) {
                    final childActive = item.children!
                        .any((c) => _isActive(currentRoute, c.route));
                    return _DrawerGroup(
                      key: _groupKeys.putIfAbsent(item.title,
                          () => GlobalKey<_DrawerGroupState>()),
                      tourKey: _tourKey(item.title),
                      childKeyFor: _tourKey,
                      item: item,
                      initiallyExpanded: childActive,
                      childActive: childActive,
                      isActive: (route) => _isActive(currentRoute, route),
                      onTap: _onMenuTap,
                    );
                  }
                  return _DrawerTile(
                    tourKey: _tourKey(item.title),
                    icon: item.icon,
                    title: item.title,
                    active: !item.locked && _isActive(currentRoute, item.route),
                    locked: item.locked,
                    onTap: () => _onMenuTap(item),
                  );
                },
              ),
            ),

            // Logout Button
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _DrawerTile(
                icon: Icons.logout_rounded,
                title: 'Logout',
                color: AppColors.error,
                onTap: _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool active;
  final Color? color;
  final double indent;
  final VoidCallback onTap;

  /// fitur belum ada di paket: tampil dengan gembok
  final bool locked;

  /// target panduan tooltip (OnboardingTour), hanya untuk menu top-level
  final GlobalKey? tourKey;

  const _DrawerTile({
    this.tourKey,
    required this.icon,
    required this.title,
    required this.onTap,
    this.active = false,
    this.color,
    this.indent = 0,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color ?? (active ? AppColors.blue : AppColors.ink);
    final iconColor = color ?? (active ? AppColors.blue : AppColors.muted);
    return Padding(
      key: tourKey,
      padding: EdgeInsets.fromLTRB(12 + indent, 2, 12, 2),
      child: ListTile(
        dense: true,
        minLeadingWidth: 22,
        horizontalTitleGap: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        selected: active,
        selectedTileColor: AppColors.blue.withValues(alpha: 0.10),
        leading: Icon(icon, color: iconColor, size: 22),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: fg,
          ),
        ),
        trailing: locked
            ? const Icon(Icons.lock_rounded,
                size: 16, color: AppColors.disabled)
            : null,
        onTap: onTap,
      ),
    );
  }
}

class _DrawerGroup extends StatefulWidget {
  final MenuItem item;
  final bool initiallyExpanded;
  final bool childActive;
  final bool Function(String route) isActive;
  final Future<void> Function(MenuItem item) onTap;
  final GlobalKey? tourKey;

  /// kunci sorot panduan untuk anak grup (per judul)
  final GlobalKey Function(String title)? childKeyFor;

  const _DrawerGroup({
    super.key,
    this.tourKey,
    this.childKeyFor,
    required this.item,
    required this.initiallyExpanded,
    required this.childActive,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_DrawerGroup> createState() => _DrawerGroupState();
}

class _DrawerGroupState extends State<_DrawerGroup> {
  late bool _open = widget.initiallyExpanded;

  /// dipakai panduan: buka grup supaya anak-anaknya terender
  void expand() {
    if (!_open) setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.childActive ? AppColors.blue : AppColors.ink;
    final iconColor = widget.childActive ? AppColors.blue : AppColors.muted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          key: widget.tourKey,
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
          child: ListTile(
            dense: true,
            minLeadingWidth: 22,
            horizontalTitleGap: 12,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            leading: Icon(widget.item.icon, color: iconColor, size: 22),
            title: Text(
              widget.item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            trailing: Icon(
              _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 20,
              color: AppColors.muted,
            ),
            onTap: () => setState(() => _open = !_open),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState:
              _open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final child in widget.item.children!)
                _DrawerTile(
                  tourKey: widget.childKeyFor?.call(child.title),
                  icon: child.icon,
                  title: child.title,
                  active: !child.locked && widget.isActive(child.route),
                  indent: 16,
                  locked: child.locked,
                  onTap: () => widget.onTap(child),
                ),
            ],
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class MenuItem {
  final String title;
  final IconData icon;
  final String route;
  final List<MenuItem>? children;

  /// kunci fitur paket langganan yang dibutuhkan (lihat utils/subscription_state.dart)
  final String? feature;

  /// true kalau fitur belum ada di paket -> tampil dengan gembok & mengarah ke /langganan
  final bool locked;

  MenuItem({
    required this.title,
    required this.icon,
    required this.route,
    this.children,
    this.feature,
    this.locked = false,
  });
}
