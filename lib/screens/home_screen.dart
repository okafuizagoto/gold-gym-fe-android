import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/private_route.dart';
import '../widgets/commerce_carousel.dart';
import '../providers/user_provider.dart';
import '../providers/language_provider.dart';
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
  bool _isTherapy = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await Storage.get('userNIP');
    final outletType = await Storage.get(AppConstants.outletTypeKey) ?? 'RETAIL';
    final role = await Storage.get(AppConstants.userRoleKey);
    if (!mounted) return;

    setState(() {
      userName = name?.toTitleCase() ?? 'Guest';
      _isTherapy = outletType == AppConstants.outletTherapy;
      _isAdmin = role == AppConstants.roleAdmin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Consumer2<UserProvider, LanguageProvider>(
        builder: (context, userProvider, langProvider, child) {
          return Scaffold(
            appBar: const AppBarCustom(title: 'Dashboard'),
            drawer: const AppDrawer(),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome message
                  Text(
                    langProvider.get(
                      'Welcome to Okejual POS System',
                      'Selamat Datang di Sistem POS Okejual',
                    ),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    // userProvider.user?.email ?? 'Guest',
                    userName,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Banner bernuansa jual-beli/pasar
                  const CommerceCarousel(
                    height: 200,
                  ),
                  const SizedBox(height: 32),
                  // Quick actions
                  Text(
                    langProvider.get('Quick Actions', 'Aksi Cepat'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action cards
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      // ADMIN tidak beroperasi di outlet manapun (lihat juga
                      // app_drawer.dart) -- shortcut operasional outlet di
                      // bawah ini semua disembunyikan untuknya.
                      if (!_isAdmin) ...[
                        _QuickActionCard(
                          icon: Icons.point_of_sale,
                          title:
                              langProvider.get('Point of Sale', 'Penjualan'),
                          onTap: () {
                            Navigator.pushNamed(context, '/penjualan');
                          },
                        ),
                        if (_isTherapy)
                          _QuickActionCard(
                            icon: Icons.event_available,
                            title: langProvider.get(
                                'Therapy Booking', 'Booking Terapi'),
                            onTap: () {
                              Navigator.pushNamed(context, '/booking');
                            },
                          ),
                        _QuickActionCard(
                          icon: Icons.receipt_long,
                          title: langProvider.get(
                              'Sales History', 'History Penjualan'),
                          onTap: () {
                            Navigator.pushNamed(context, '/history-sales');
                          },
                        ),
                        _QuickActionCard(
                          icon: Icons.inventory,
                          title: langProvider.get('Stock', 'Stok Barang'),
                          onTap: () {
                            Navigator.pushNamed(context, '/stock-barang');
                          },
                        ),
                        _QuickActionCard(
                          icon: Icons.add_box,
                          title: langProvider.get('Add Items', 'Tambah Item'),
                          onTap: () {
                            Navigator.pushNamed(context, '/add-items');
                          },
                        ),
                        _QuickActionCard(
                          icon: Icons.person_add,
                          title: langProvider.get(
                              'Register Buyer', 'Daftar Pembeli'),
                          onTap: () {
                            Navigator.pushNamed(context, '/daftar-pembeli');
                          },
                        ),
                      ],
                      if (_isAdmin)
                        _QuickActionCard(
                          icon: Icons.admin_panel_settings,
                          title: langProvider.get(
                              'Admin Access', 'Akses Admin'),
                          onTap: () {
                            Scaffold.of(context).openDrawer();
                          },
                        ),
                      _QuickActionCard(
                        icon: Icons.info,
                        title: langProvider.get('About Us', 'Tentang Kami'),
                        onTap: () {
                          Navigator.pushNamed(context, '/about-us');
                        },
                      ),
                    ],
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

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).primaryColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
