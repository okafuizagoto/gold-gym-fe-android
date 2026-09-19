// Audit otomatis: setiap layar di-render pada berbagai ukuran layar Android
// (HP kecil, HP umum, tablet, portrait & landscape) dan test GAGAL kalau ada
// widget yang meluap ("RenderFlex overflowed") -- artinya ada komponen yang
// terpotong/tidak terlihat di ukuran tersebut.
//
// Jalankan: flutter test test/responsive_overflow_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gold_gym_fe_android/config/routes.dart';
import 'package:gold_gym_fe_android/config/theme.dart';
import 'package:gold_gym_fe_android/providers/buyer_cart_provider.dart';
import 'package:gold_gym_fe_android/providers/buyer_order_provider.dart';
import 'package:gold_gym_fe_android/providers/cart_provider.dart';
import 'package:gold_gym_fe_android/providers/language_provider.dart';
import 'package:gold_gym_fe_android/providers/user_provider.dart';
import 'package:gold_gym_fe_android/utils/constants.dart';
import 'package:gold_gym_fe_android/utils/navigation.dart';

class ScreenSize {
  final String name;
  final Size size;
  const ScreenSize(this.name, this.size);
}

/// Ukuran yang WAJIB bersih (permintaan: HP kecil, HP umum, tablet, landscape)
const screenSizes = [
  ScreenSize('hp-kecil-360x640', Size(360, 640)),
  ScreenSize('hp-kecil-landscape-640x360', Size(640, 360)),
  ScreenSize('hp-umum-412x915', Size(412, 915)),
  ScreenSize('hp-umum-landscape-915x412', Size(915, 412)),
  ScreenSize('tablet-800x1280', Size(800, 1280)),
  ScreenSize('tablet-landscape-1280x800', Size(1280, 800)),
];

/// Route yang hanya masuk akal untuk sesi PEMBELI (mode belanja).
const buyerRoutes = {
  AppRoutes.belanja,
  AppRoutes.listBarang,
  AppRoutes.pilihOutlet,
  AppRoutes.pesananSaya,
  AppRoutes.pesananDetail,
};

/// Route yang butuh argumen navigasi -- diuji terpisah dengan argumen dummy.
const routesWithArguments = {
  AppRoutes.pesananDetail,
};

String fakeJwt() {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = b64({'alg': 'HS256', 'typ': 'JWT'});
  final payload = b64({
    'iss': 'GOLD-GYM-BE',
    'sub': 'tester',
    'user': 'tester',
    'email': 'tester@okejual.com',
    'role': AppConstants.roleSeller,
    'gold_id': 1,
    'iat': 1700000000,
    'exp': 4102444800,
  });
  return '$header.$payload.signature';
}

Map<String, Object> sessionPrefs({required String role, String shopMode = ''}) {
  return {
    AppConstants.accessTokenKey: 'Bearer ${fakeJwt()}',
    AppConstants.expiresAtKey: '4102444800',
    AppConstants.userNIPKey: 'tester',
    AppConstants.userEmail: 'tester@okejual.com',
    AppConstants.userRoleKey: role,
    AppConstants.userGoldIdKey: '1',
    AppConstants.userIsBuyerKey: 'Y',
    AppConstants.menuDaftarPembeliKey: 'Y',
    AppConstants.menuModePembeliKey: 'Y',
    AppConstants.languageKey: 'ID',
    AppConstants.outcode: 'OUT01',
    AppConstants.outletTypeKey: 'RETAIL',
    AppConstants.shopModeKey: shopMode,
    AppConstants.buyerOutcodeKey: 'OUT02',
    AppConstants.buyerOutletNameKey: 'Toko Contoh',
    AppConstants.buyerOutletGoldIdKey: '2',
  };
}

Future<void> loadAppFonts() async {
  final loader = FontLoader('Inter');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Inter-$f.ttf'));
  }
  await loader.load();
}

Widget buildApp(String route, {Object? arguments}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => UserProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ChangeNotifierProvider(create: (_) => CartProvider()),
      ChangeNotifierProvider(create: (_) => BuyerCartProvider()),
      ChangeNotifierProvider(create: (_) => BuyerOrderProvider()),
    ],
    child: MaterialApp(
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: route,
      onGenerateInitialRoutes: (name) => [
        MaterialPageRoute(
          settings: RouteSettings(name: name, arguments: arguments),
          builder: AppRoutes.routes[name]!,
        ),
      ],
      routes: AppRoutes.routes,
    ),
  );
}

/// Render [route] pada [size], kumpulkan error layout, kembalikan daftar
/// pesan overflow (kosong = bersih).
Future<List<String>> renderAndCollectOverflows(
  WidgetTester tester,
  String route,
  Size size, {
  required Map<String, Object> prefs,
  Object? arguments,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues(prefs);

  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await tester.pumpWidget(buildApp(route, arguments: arguments));
    // beri waktu Storage/FutureBuilder/HTTP (gagal cepat di test) selesai
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  } finally {
    FlutterError.onError = previous;
    // bongkar tree supaya timer/animasi (carousel, spinner) berhenti
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  return errors
      .where((e) => e.exceptionAsString().contains('overflowed'))
      .map((e) => e.exceptionAsString().split('\n').first)
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    dotenv.testLoad(
      fileInput: 'ENVIRONMENT=local\nBASE_API_URL=http://127.0.0.1:9',
    );
    await initializeDateFormatting('id_ID', null);
    await loadAppFonts();
  });

  group(AppRoutes.pesananDetail, () {
    for (final s in screenSizes) {
      testWidgets('tidak ada overflow @ ${s.name}', (tester) async {
        final overflows = await renderAndCollectOverflows(
          tester,
          AppRoutes.pesananDetail,
          s.size,
          prefs: sessionPrefs(
            role: AppConstants.roleBuyer,
            shopMode: AppConstants.shopModeBuyer,
          ),
          arguments: 'ORDER-TEST-1',
        );
        expect(overflows, isEmpty,
            reason: 'Layar pesanan-detail meluap di ${s.name}:\n'
                '${overflows.join('\n')}');
      });
    }
  });

  for (final entry in AppRoutes.routes.entries) {
    final route = entry.key;
    if (routesWithArguments.contains(route)) continue;
    final isBuyer = buyerRoutes.contains(route);
    final prefs = isBuyer
        ? sessionPrefs(
            role: AppConstants.roleBuyer,
            shopMode: AppConstants.shopModeBuyer,
          )
        : sessionPrefs(role: AppConstants.roleSeller);

    group(route, () {
      for (final s in screenSizes) {
        testWidgets('tidak ada overflow @ ${s.name}', (tester) async {
          final overflows = await renderAndCollectOverflows(
            tester,
            route,
            s.size,
            prefs: prefs,
          );
          expect(
            overflows,
            isEmpty,
            reason: 'Layar $route meluap di ${s.name}:\n${overflows.join('\n')}',
          );
        });
      }
    });
  }
}
