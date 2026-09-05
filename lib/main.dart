import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'providers/user_provider.dart';
import 'providers/language_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/buyer_cart_provider.dart';
import 'providers/buyer_order_provider.dart';
import '../utils/storage.dart';
import '../utils/constants.dart';
import '../utils/navigation.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   // Load environment variables
//   try {
//     await dotenv.load(fileName: ".env.local");
//   } catch (e) {
//     // If .env.local not found, try .env.production
//     try {
//       await dotenv.load(fileName: ".env.production");
//     } catch (e) {
//       // Fallback to default values if no env file found
//       debugPrint('No environment file found, using defaults');
//     }
//   }

//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => UserProvider()),
//         ChangeNotifierProvider(create: (_) => LanguageProvider()),
//         ChangeNotifierProvider(create: (_) => CartProvider()),
//       ],
//       child: MaterialApp(
//         title: 'Gold Gym',
//         theme: AppTheme.lightTheme,
//         initialRoute: AppRoutes.home,
//         routes: AppRoutes.routes,
//         debugShowCheckedModeBanner: false,
//       ),
//     );
//   }
// }
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final envFiles = kReleaseMode
      ? [".env.production"]
      : [".env.local", ".env.production"];
  for (final file in envFiles) {
    try {
      await dotenv.load(fileName: file);
      break;
    } catch (e) {
      if (file == envFiles.last) {
        debugPrint('No environment file found, using defaults');
      }
    }
  }

  // inisialisasi data locale Indonesia untuk DateFormat(..., 'id_ID')
  // (dipakai laporan penjualan: nama hari & bulan berbahasa Indonesia)
  await initializeDateFormatting('id_ID', null);

  // ✅ cek storage sebelum run
  final outCode = await Storage.get(AppConstants.outcode);
  final accessToken = await Storage.get(AppConstants.accessTokenKey);
  final role = await Storage.get(AppConstants.userRoleKey);
  final shopMode = await Storage.get(AppConstants.shopModeKey);

  String initialRoute;
  if (accessToken == null || accessToken.isEmpty) {
    initialRoute = '/login';
  } else if (outCode == null || outCode.isEmpty) {
    initialRoute = '/outlet';
  } else if (role == AppConstants.roleBuyer ||
      shopMode == AppConstants.shopModeBuyer) {
    // mode pembeli: wajib pilih outlet penjual dulu; jika sudah pernah
    // memilih, langsung ke layar belanja
    final buyerOutlet = await Storage.get(AppConstants.buyerOutcodeKey);
    initialRoute = (buyerOutlet == null || buyerOutlet.isEmpty)
        ? '/pilih-outlet'
        : '/belanja';
  } else {
    initialRoute = '/';
  }

  // Selalu mulai dari halaman login setiap kali aplikasi dijalankan.
  // (Logika `initialRoute` berbasis token di atas sengaja diabaikan; navigasi
  // ke home/outlet/belanja diserahkan ke LoginScreen setelah login berhasil.)
  runApp(const MyApp(startRoute: '/login'));
}

class MyApp extends StatelessWidget {
  final String startRoute; // ✅ ganti nama dari initialRoute

  const MyApp({super.key, required this.startRoute});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => BuyerCartProvider()),
        ChangeNotifierProvider(create: (_) => BuyerOrderProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey, // ✅ untuk paksa ke /login saat sesi habis
        title: 'Okejual',
        theme: AppTheme.lightTheme,
        initialRoute: startRoute, // ✅ pakai startRoute
        // Bangun HANYA satu halaman awal (startRoute), jangan biarkan Flutter
        // menumpuk halaman '/' (home) di bawahnya seperti perilaku bawaannya.
        onGenerateInitialRoutes: (initialRouteName) {
          final builder = AppRoutes.routes[initialRouteName] ??
              AppRoutes.routes[AppRoutes.login]!;
          return [
            MaterialPageRoute(
              settings: RouteSettings(name: initialRouteName),
              builder: builder,
            ),
          ];
        },
        routes: AppRoutes.routes,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
