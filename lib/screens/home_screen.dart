import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/private_route.dart';
import '../widgets/image_carousel.dart';
import '../providers/user_provider.dart';
import '../providers/language_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
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
                      'Welcome to Gold Gym POS System',
                      'Selamat Datang di Sistem POS Gold Gym',
                    ),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userProvider.user?.email ?? 'Guest',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Image carousel
                  const ImageCarousel(
                    images: [
                      'assets/images/banners/gym.jpg',
                      'assets/images/banners/gym1.jpg',
                      'assets/images/banners/gym2.jpg',
                    ],
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
                      _QuickActionCard(
                        icon: Icons.point_of_sale,
                        title: langProvider.get('Point of Sale', 'Penjualan'),
                        onTap: () {
                          Navigator.pushNamed(context, '/penjualan');
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
                        icon: Icons.add_circle,
                        title: langProvider.get('Add Menu', 'Tambah Menu'),
                        onTap: () {
                          Navigator.pushNamed(context, '/add-menu');
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
