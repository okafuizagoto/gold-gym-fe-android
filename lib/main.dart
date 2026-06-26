import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'providers/user_provider.dart';
import 'providers/language_provider.dart';
import 'providers/cart_provider.dart';
import '../utils/storage.dart';
import '../utils/constants.dart';

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

  try {
    await dotenv.load(fileName: ".env.local");
  } catch (e) {
    try {
      await dotenv.load(fileName: ".env.production");
    } catch (e) {
      debugPrint('No environment file found, using defaults');
    }
  }

  // ✅ cek storage sebelum run
  final outCode = await Storage.get(AppConstants.outcode);
  final accessToken = await Storage.get(AppConstants.accessTokenKey);

  String initialRoute;
  if (accessToken == null || accessToken.isEmpty) {
    initialRoute = '/login';
  } else if (outCode == null || outCode.isEmpty) {
    initialRoute = '/outlet';
  } else {
    initialRoute = '/';
  }

  runApp(MyApp(startRoute: initialRoute));
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
      ],
      child: MaterialApp(
        title: 'Gold Gym',
        theme: AppTheme.lightTheme,
        initialRoute: startRoute, // ✅ pakai startRoute
        routes: AppRoutes.routes,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
