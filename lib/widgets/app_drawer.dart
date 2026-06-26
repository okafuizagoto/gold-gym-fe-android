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
    // Static routes
    final staticRoutes = [
      MenuItem(
        title: 'Dashboard',
        icon: Icons.dashboard,
        route: '/',
      ),
      MenuItem(
        title: 'Point of Sale',
        icon: Icons.point_of_sale,
        route: '/penjualan',
      ),
      MenuItem(
        title: 'Stock',
        icon: Icons.inventory,
        route: '/stock-barang',
      ),
      MenuItem(
        title: 'Add Items',
        icon: Icons.inventory,
        route: '/add-items',
      ),
      MenuItem(
        title: 'About Us',
        icon: Icons.info,
        route: '/about-us',
      ),
      // MenuItem(
      //   title: 'Add Menu',
      //   icon: Icons.add_circle,
      //   route: '/add-menu',
      // ),
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
                      Icons.fitness_center,
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
                return ListTile(
                  leading: Icon(item.icon, color: Colors.white),
                  title: Text(
                    item.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    Navigator.pushNamed(context, item.route);
                  },
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
