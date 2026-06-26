import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/outlet_screen.dart';
import '../screens/new_outlet_screen.dart';
import '../screens/list_outlet_screen.dart';
import '../screens/home_screen.dart';
import '../screens/penjualan_screen.dart';
import '../screens/stock_barang_screen.dart';
import '../screens/about_us_screen.dart';
import '../screens/add_menu_screen.dart';
import '../screens/add_items.dart';
import '../screens/forbidden_403_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String outlet = '/outlet';
  static const String newoutlet = '/new-outlet';
  static const String listoutlet = '/list-outlet';
  static const String penjualan = '/penjualan';
  static const String stockBarang = '/stock-barang';
  static const String aboutUs = '/about-us';
  static const String addMenu = '/add-menu';
  static const String addItems = '/add-items';
  static const String forbidden = '/403';

  static Map<String, WidgetBuilder> get routes => {
        home: (context) => const HomeScreen(),
        login: (context) => const LoginScreen(),
        outlet: (context) => const OutletScreen(),
        newoutlet: (context) => const NewOutletScreen(),
        listoutlet: (context) => const ListOutletScreen(),
        penjualan: (context) => const PenjualanScreen(),
        stockBarang: (context) => const StockBarangScreen(),
        aboutUs: (context) => const AboutUsScreen(),
        addMenu: (context) => const AddMenuScreen(),
        addItems: (context) => const AddItemsScreen(),
        forbidden: (context) => const Forbidden403Screen(),
      };
}
