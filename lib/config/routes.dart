import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/outlet_screen.dart';
import '../screens/new_outlet_screen.dart';
import '../screens/list_outlet_screen.dart';
import '../screens/home_screen.dart';
import '../screens/penjualan_screen.dart';
import '../screens/sales_history_screen.dart';
import '../screens/stock_barang_screen.dart';
import '../screens/about_us_screen.dart';
import '../screens/add_menu_screen.dart';
import '../screens/add_items.dart';
import '../screens/discount_screen.dart';
import '../screens/forbidden_403_screen.dart';
import '../screens/register_screen.dart';
import '../screens/booking_screen.dart';
import '../screens/seller_register_buyer_screen.dart';
import '../screens/buyer_catalog_screen.dart';
import '../screens/buyer_choose_outlet_screen.dart';
import '../screens/buyer_order_shop_screen.dart';
import '../screens/buyer_orders_screen.dart';
import '../screens/buyer_order_detail_screen.dart';
import '../screens/seller_orders_screen.dart';
import '../screens/admin_buyer_outlets_screen.dart';
import '../screens/admin_pos_customer_screen.dart';
import '../screens/admin_proof_access_screen.dart';
import '../screens/admin_registration_mode_screen.dart';
import '../screens/seller_menu_access_screen.dart';
import '../screens/customer_list_screen.dart';
import '../screens/laporan_screen.dart';
import '../screens/storage_screen.dart';
import '../screens/meja_area_screen.dart';
import '../screens/area_form_screen.dart';
import '../screens/meja_form_screen.dart';
import '../screens/kelola_meja_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String outlet = '/outlet';
  static const String newoutlet = '/new-outlet';
  static const String listoutlet = '/list-outlet';
  static const String penjualan = '/penjualan';
  static const String salesHistory = '/history-sales';
  static const String stockBarang = '/stock-barang';
  static const String aboutUs = '/about-us';
  static const String addMenu = '/add-menu';
  static const String addItems = '/add-items';
  static const String diskon = '/diskon';
  static const String forbidden = '/403';
  static const String register = '/register';
  static const String booking = '/booking';
  static const String belanja = '/belanja';
  static const String daftarPembeli = '/daftar-pembeli';
  static const String listBarang = '/list-barang';
  static const String pilihOutlet = '/pilih-outlet';
  static const String pesananSaya = '/pesanan-saya';
  static const String pesananDetail = '/pesanan-detail';
  static const String pesananMasuk = '/pesanan-masuk';
  static const String adminOutletPembeli = '/admin-outlet-pembeli';
  static const String adminPosCustomer = '/admin-pos-customer';
  static const String adminProofAccess = '/admin-proof-access';
  static const String adminRegistrationMode = '/admin-registration-mode';
  static const String adminAksesDaftarPembeli = '/admin-akses-daftar-pembeli';
  static const String adminAksesModePembeli = '/admin-akses-mode-pembeli';
  static const String daftarCustomer = '/daftar-customer';
  static const String laporan = '/laporan';
  static const String storage = '/storage';
  static const String mejaArea = '/meja-area';
  static const String tambahArea = '/tambah-area';
  static const String tambahMeja = '/tambah-meja';
  static const String kelolaMeja = '/kelola-meja';

  static Map<String, WidgetBuilder> get routes => {
        home: (context) => const HomeScreen(),
        login: (context) => const LoginScreen(),
        outlet: (context) => const OutletScreen(),
        newoutlet: (context) => const NewOutletScreen(),
        listoutlet: (context) => const ListOutletScreen(),
        penjualan: (context) => const PenjualanScreen(),
        salesHistory: (context) => const SalesHistoryScreen(),
        stockBarang: (context) => const StockBarangScreen(),
        aboutUs: (context) => const AboutUsScreen(),
        addMenu: (context) => const AddMenuScreen(),
        addItems: (context) => const AddItemsScreen(),
        diskon: (context) => const DiscountScreen(),
        forbidden: (context) => const Forbidden403Screen(),
        register: (context) => const RegisterScreen(),
        booking: (context) => const BookingScreen(),
        belanja: (context) => const BuyerOrderShopScreen(),
        daftarPembeli: (context) => const SellerRegisterBuyerScreen(),
        listBarang: (context) => const BuyerCatalogScreen(),
        pilihOutlet: (context) => const BuyerChooseOutletScreen(),
        pesananSaya: (context) => const BuyerOrdersScreen(),
        pesananDetail: (context) => const BuyerOrderDetailScreen(),
        pesananMasuk: (context) => const SellerOrdersScreen(),
        adminOutletPembeli: (context) => const AdminBuyerOutletsScreen(),
        adminPosCustomer: (context) => const AdminPosCustomerScreen(),
        adminProofAccess: (context) => const AdminProofAccessScreen(),
        adminRegistrationMode: (context) => const AdminRegistrationModeScreen(),
        adminAksesDaftarPembeli: (context) => const SellerMenuAccessScreen(
            target: SellerMenuAccessTarget.daftarPembeli),
        adminAksesModePembeli: (context) => const SellerMenuAccessScreen(
            target: SellerMenuAccessTarget.modePembeli),
        daftarCustomer: (context) => const CustomerListScreen(),
        laporan: (context) => const LaporanScreen(),
        storage: (context) => const StorageScreen(),
        mejaArea: (context) => const MejaAreaScreen(),
        tambahArea: (context) => const AreaFormScreen(),
        tambahMeja: (context) => const MejaFormScreen(),
        kelolaMeja: (context) => const KelolaMejaScreen(),
      };
}
