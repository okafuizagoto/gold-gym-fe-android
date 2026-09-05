import 'package:flutter/material.dart';
import '../utils/storage.dart';
import '../utils/constants.dart';
import '../providers/language_provider.dart';
import '../services/core_api.dart';
import '../utils/toast.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  List<MenuItem> menuItems = [];

  final _coreApi = CoreApi();

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  Future<void> _loadMenuItems() async {
    // Menu menyesuaikan role (ADMIN/SELLER/BUYER), tipe outlet, dan MODE:
    // penjual/admin bisa beralih ke "mode pembeli" (berbelanja di outlet lain
    // sebagai pembeli — nota menampilkan nama toko miliknya) lalu kembali.
    // - Mode penjual : dashboard, booking terapi, POS, sales history, stock,
    //                  add items, daftar pembeli, ganti outlet, about us
    // - Mode pembeli / role BUYER : booking terapi, Point of Sale (belanja),
    //                  List Barang, riwayat belanja, about us
    final role = await Storage.get(AppConstants.userRoleKey) ??
        AppConstants.roleSeller;
    final outletType = await Storage.get(AppConstants.outletTypeKey) ??
        'RETAIL';
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
    final isRealBuyer = role == AppConstants.roleBuyer;
    final isAdmin = role == AppConstants.roleAdmin;
    // penjual (retail & therapy sama-sama SELLER; dibedakan outlet_type)
    final isSeller = role == AppConstants.roleSeller;
    // tampilan pembeli: role BUYER asli, atau penjual/admin dalam mode pembeli
    final buyerView =
        isRealBuyer || shopMode == AppConstants.shopModeBuyer;
    final isTherapy = outletType == AppConstants.outletTherapy;

    // Static routes
    final staticRoutes = <MenuItem>[
      if (!buyerView)
        MenuItem(
          title: 'Dashboard',
          icon: Icons.dashboard,
          route: '/',
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
        ),
      if (!buyerView && !isAdmin)
        MenuItem(
          title: 'Point of Sale',
          icon: Icons.point_of_sale,
          route: '/penjualan',
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
      // PENJUAL (retail & therapy): satu menu laporan penjualan; per hari /
      // minggu / bulan dipilih lewat TAB di dalam layarnya.
      if (!buyerView && isSeller)
        MenuItem(
          title: 'Laporan Penjualan',
          icon: Icons.assessment,
          route: '/laporan',
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
              title: 'Akses Daftar Pembeli',
              icon: Icons.person_add_alt,
              route: '/admin-akses-daftar-pembeli',
            ),
            MenuItem(
              title: 'Akses Mode Pembeli',
              icon: Icons.swap_horizontal_circle_outlined,
              route: '/admin-akses-mode-pembeli',
            ),
          ],
        ),
      // Atur Meja: khusus penjual retail (non-THERAPY) -- kelola area
      // (indoor/outdoor), meja per area, dan kosongkan meja yang sudah
      // selesai dipakai.
      if (!buyerView && isSeller && !isTherapy)
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
      if (!buyerView && !isAdmin)
        MenuItem(
          title: 'Stock',
          icon: Icons.inventory,
          route: '/stock-barang',
        ),
      if (!buyerView && !isAdmin)
        MenuItem(
          title: 'Items',
          icon: Icons.inventory,
          route: '',
          children: [
            MenuItem(
                title: 'Add Items', icon: Icons.add_box, route: '/add-items'),
            MenuItem(title: 'Diskon', icon: Icons.percent, route: '/diskon'),
          ],
        ),
      // penjual: kelola daftar customer (tabel customer) — tambah 1 / massal
      if (!buyerView && !isAdmin)
        MenuItem(
          title: 'Daftar Customer',
          icon: Icons.contacts,
          route: '/daftar-customer',
        ),
      // Daftar Pembeli hanya tampil sebelum akun terdaftar sebagai pembeli;
      // setelah konfirmasi, menu ini hilang dan Mode Pembeli muncul.
      // Bisa juga dipaksa sembunyi oleh admin (menuDaftarPembeliEnabled).
      // ADMIN tidak butuh berbelanja sebagai pembeli, jadi menu ini juga
      // tidak relevan untuknya.
      if (!buyerView && !isRegisteredBuyer && menuDaftarPembeliEnabled && !isAdmin)
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
          !isAdmin)
        MenuItem(
          title: 'Mode Pembeli',
          icon: Icons.swap_horiz,
          route: '/switch-buyer',
        ),
      if (!isRealBuyer && buyerView && !isAdmin)
        MenuItem(
          title: 'Mode Penjual',
          icon: Icons.swap_horiz,
          route: '/switch-seller',
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
      MenuItem(
        title: 'About Us',
        icon: Icons.info,
        route: '/about-us',
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

    setState(() {
      menuItems = [...staticRoutes, ...customRoutes];
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

  // Future<void> _logout() async {
  //   await Storage.clear();
  //   if (mounted) {
  //     Navigator.pushReplacementNamed(context, '/login');
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF6DBAB9), // primaryTeal
      child: Column(
        children: [
          // Header
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF6DBAB9),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 100,
                  height: 100,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.storefront,
                      size: 100,
                      color: Colors.white,
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '${AppConstants.appName} v${AppConstants.version}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                // Menu grup (punya children) -> tampil sebagai ExpansionTile
                // yang bisa di-show/hide. Contoh: "Akses Admin".
                if (item.children != null && item.children!.isNotEmpty) {
                  return Theme(
                    // hilangkan garis pemisah bawaan ExpansionTile
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: Icon(item.icon, color: Colors.white),
                      title: Text(
                        item.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      iconColor: Colors.white,
                      collapsedIconColor: Colors.white,
                      childrenPadding: const EdgeInsets.only(left: 16),
                      children: item.children!
                          .map(
                            (child) => ListTile(
                              leading: Icon(child.icon, color: Colors.white),
                              title: Text(
                                child.title,
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () => _onMenuTap(child),
                            ),
                          )
                          .toList(),
                    ),
                  );
                }
                return ListTile(
                  leading: Icon(item.icon, color: Colors.white),
                  title: Text(
                    item.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () => _onMenuTap(item),
                );
              },
            ),
          ),

          // Logout Button
          const Divider(color: Colors.white54),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.white),
            ),
            onTap: _logout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class MenuItem {
  final String title;
  final IconData icon;
  final String route;
  final List<MenuItem>? children;

  MenuItem({
    required this.title,
    required this.icon,
    required this.route,
    this.children,
  });
}
