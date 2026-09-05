import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/storage.dart';
import '../utils/constants.dart';
import '../services/core_api.dart';
import '../utils/toast.dart';
import 'brand_logo.dart';

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

    if (!mounted) return;
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
                      item: item,
                      initiallyExpanded: childActive,
                      childActive: childActive,
                      isActive: (route) => _isActive(currentRoute, route),
                      onTap: _onMenuTap,
                    );
                  }
                  return _DrawerTile(
                    icon: item.icon,
                    title: item.title,
                    active: _isActive(currentRoute, item.route),
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

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.active = false,
    this.color,
    this.indent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color ?? (active ? AppColors.blue : AppColors.ink);
    final iconColor = color ?? (active ? AppColors.blue : AppColors.muted);
    return Padding(
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

  const _DrawerGroup({
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

  @override
  Widget build(BuildContext context) {
    final fg = widget.childActive ? AppColors.blue : AppColors.ink;
    final iconColor = widget.childActive ? AppColors.blue : AppColors.muted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
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
                  icon: child.icon,
                  title: child.title,
                  active: widget.isActive(child.route),
                  indent: 16,
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

  MenuItem({
    required this.title,
    required this.icon,
    required this.route,
    this.children,
  });
}
