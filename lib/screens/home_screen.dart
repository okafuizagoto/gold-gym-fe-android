import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/private_route.dart';
import '../widgets/commerce_carousel.dart';
import '../providers/user_provider.dart';
import '../providers/language_provider.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/constants.dart';
import '../extensions/string_extension.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = 'Guest';
  String _outcode = '';
  bool _isTherapy = false;
  bool _isAdmin = false;
  bool _isSeller = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await Storage.get('userNIP');
    final outletType = await Storage.get(AppConstants.outletTypeKey) ?? 'RETAIL';
    final role = await Storage.get(AppConstants.userRoleKey);
    final outcode = await Storage.get(AppConstants.outcode) ?? '';
    if (!mounted) return;

    setState(() {
      userName = name?.toTitleCase() ?? 'Guest';
      _outcode = outcode;
      _isTherapy = outletType == AppConstants.outletTherapy;
      _isAdmin = role == AppConstants.roleAdmin;
      _isSeller = role == AppConstants.roleSeller;
    });
  }

  List<_QuickAction> _actions(LanguageProvider lang) {
    final actions = <_QuickAction>[];
    if (!_isAdmin) {
      // ADMIN tidak beroperasi di outlet manapun (lihat juga
      // app_drawer.dart) -- shortcut operasional outlet disembunyikan.
      actions.add(_QuickAction(
        icon: Icons.point_of_sale_rounded,
        title: lang.get('Point of Sale', 'Penjualan'),
        desc: lang.get('Record a sale at the counter',
            'Catat transaksi di kasir'),
        route: '/penjualan',
        color: AppColors.blue,
      ));
      if (_isTherapy) {
        actions.add(_QuickAction(
          icon: Icons.event_available_rounded,
          title: lang.get('Therapy Booking', 'Booking Terapi'),
          desc: lang.get('Manage therapy slots', 'Atur jadwal terapi pelanggan'),
          route: '/booking',
          color: const Color(0xFF7C3AED),
        ));
      }
      actions.add(_QuickAction(
        icon: Icons.receipt_long_rounded,
        title: lang.get('Sales History', 'History Penjualan'),
        desc: lang.get('See past receipts', 'Lihat nota yang sudah tersimpan'),
        route: '/history-sales',
        color: AppColors.info,
      ));
      if (_isSeller) {
        actions.add(_QuickAction(
          icon: Icons.assessment_rounded,
          title: lang.get('Sales Report', 'Laporan Penjualan'),
          desc: lang.get('Daily / weekly / monthly',
              'Per hari, minggu, dan bulan'),
          route: '/laporan',
          color: AppColors.warning,
        ));
      }
      actions.add(_QuickAction(
        icon: Icons.inventory_2_rounded,
        title: lang.get('Stock', 'Stok Barang'),
        desc: lang.get('Check and add stock', 'Cek & tambah stok di outlet'),
        route: '/stock-barang',
        color: AppColors.tealDark,
      ));
      actions.add(_QuickAction(
        icon: Icons.add_box_rounded,
        title: lang.get('Add Items', 'Tambah Item'),
        desc: lang.get('Register products to sell',
            'Daftarkan produk yang dijual'),
        route: '/add-items',
        color: AppColors.success,
      ));
      actions.add(_QuickAction(
        icon: Icons.person_add_rounded,
        title: lang.get('Register Buyer', 'Daftar Pembeli'),
        desc: lang.get('Shop at other outlets',
            'Belanja di outlet penjual lain'),
        route: '/daftar-pembeli',
        color: const Color(0xFFEC4899),
      ));
    } else {
      actions.add(_QuickAction(
        icon: Icons.admin_panel_settings_rounded,
        title: lang.get('Admin Access', 'Akses Admin'),
        desc: lang.get('Manage feature access',
            'Atur akses fitur (lihat menu samping)'),
        route: '/admin-outlet-pembeli',
        color: AppColors.warning,
      ));
    }
    actions.add(_QuickAction(
      icon: Icons.info_rounded,
      title: lang.get('About Us', 'Tentang Kami'),
      desc: lang.get('Contact information', 'Informasi kontak'),
      route: '/about-us',
      color: AppColors.muted,
    ));
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Consumer2<UserProvider, LanguageProvider>(
        builder: (context, userProvider, langProvider, child) {
          final textTheme = Theme.of(context).textTheme;
          final actions = _actions(langProvider);
          final columns = context.columnsFor(minTileWidth: 160, max: 4);

          return Scaffold(
            appBar: const AppBarCustom(title: 'Dashboard'),
            drawer: const AppDrawer(),
            body: PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sambutan
                  Text(
                    langProvider.get(
                      'Welcome to Okejual POS System',
                      'Selamat Datang di Sistem POS Okejual',
                    ),
                    style: textTheme.headlineMedium?.copyWith(
                      fontSize: context.isCompact ? 24 : 30,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${langProvider.get('Hello', 'Halo')}, '),
                        TextSpan(
                          text: userName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (_outcode.isNotEmpty && !_isAdmin)
                          TextSpan(
                              text:
                                  ' · ${langProvider.get('Outlet', 'Outlet')}: $_outcode'),
                      ],
                    ),
                    style: textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 20),

                  // Banner bernuansa jual-beli/pasar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: CommerceCarousel(
                      height: context.isShort ? 150 : 210,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Aksi cepat
                  Text(
                    langProvider.get('Quick Actions', 'Aksi Cepat'),
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    langProvider.get('Tap a card to open the feature',
                        'Ketuk kartu untuk membuka fitur'),
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      // tinggi tetap (bukan rasio) supaya ikon + judul +
                      // keterangan selalu muat di HP kecil
                      mainAxisExtent: 156,
                    ),
                    itemCount: actions.length,
                    itemBuilder: (context, index) {
                      final a = actions[index];
                      return _QuickActionCard(
                        action: a,
                        onTap: () {
                          if (a.route == '/admin-outlet-pembeli') {
                            Scaffold.of(context).openDrawer();
                            return;
                          }
                          Navigator.pushNamed(context, a.route);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String title;
  final String desc;
  final String route;
  final Color color;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.desc,
    required this.route,
    required this.color,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;
  final VoidCallback onTap;

  const _QuickActionCard({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, size: 26, color: action.color),
              ),
              const SizedBox(height: 10),
              Text(
                action.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  action.desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
