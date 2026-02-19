import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/penjualan_screen.dart';
import '../screens/stock_barang_screen.dart';
import '../screens/about_us_screen.dart';
import '../screens/add_menu_screen.dart';
import '../screens/forbidden_403_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String penjualan = '/penjualan';
  static const String stockBarang = '/stock-barang';
  static const String aboutUs = '/about-us';
  static const String addMenu = '/add-menu';
  static const String forbidden = '/403';

  static Map<String, WidgetBuilder> get routes => {
        home: (context) => const HomeScreen(),
        login: (context) => const LoginScreen(),
        penjualan: (context) => const PenjualanScreen(),
        stockBarang: (context) => const StockBarangScreen(),
        aboutUs: (context) => const AboutUsScreen(),
        addMenu: (context) => const AddMenuScreen(),
        forbidden: (context) => const Forbidden403Screen(),
      };
}
