// Membuat tangkapan layar (PNG) tiap layar pada beberapa ukuran, untuk
// dicek visual tanpa emulator. Bukan test verifikasi -- selalu dijalankan
// dengan --update-goldens supaya file PNG ditulis ulang:
//
//   flutter test test/screenshots_test.dart --update-goldens
//   hasil: test/goldens/<route>__<ukuran>.png
//
// Pilih layar/ukuran lewat --dart-define:
//   --dart-define=ROUTES=/login,/,/penjualan  --dart-define=SIZES=360x640,1280x800
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gold_gym_fe_android/config/routes.dart';
import 'package:gold_gym_fe_android/utils/constants.dart';

import 'responsive_overflow_test.dart' show buildApp, sessionPrefs, buyerRoutes;

const _routesEnv = String.fromEnvironment('ROUTES', defaultValue: '/login,/');
const _sizesEnv =
    String.fromEnvironment('SIZES', defaultValue: '360x640,1280x800');

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(rootBundle.load('assets/fonts/Inter-$f.ttf'));
  }
  await inter.load();

  // ikon Material supaya tidak tampil kotak di PNG
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final iconFile = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (iconFile.existsSync()) {
    final bytes = iconFile.readAsBytesSync();
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await icons.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    dotenv.testLoad(
      fileInput: 'ENVIRONMENT=local\nBASE_API_URL=http://127.0.0.1:9',
    );
    await initializeDateFormatting('id_ID', null);
    await _loadFonts();
  });

  final routes = _routesEnv.split(',').where((r) => r.isNotEmpty);
  final sizes = _sizesEnv.split(',').where((s) => s.isNotEmpty).map((s) {
    final parts = s.split('x');
    return Size(double.parse(parts[0]), double.parse(parts[1]));
  });

  for (final rawRoute in routes) {
    // "/#drawer" = tangkap layar dengan drawer terbuka
    final openDrawer = rawRoute.endsWith('#drawer');
    final route = openDrawer
        ? rawRoute.substring(0, rawRoute.length - '#drawer'.length)
        : rawRoute;
    for (final size in sizes) {
      final sizeName = '${size.width.toInt()}x${size.height.toInt()}';
      final baseName = route == '/' ? 'dashboard' : route.substring(1);
      final fileName =
          '$baseName${openDrawer ? '__drawer' : ''}__$sizeName.png';

      testWidgets('screenshot $route @ $sizeName', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final isBuyer = buyerRoutes.contains(route);
        SharedPreferences.setMockInitialValues(isBuyer
            ? sessionPrefs(
                role: AppConstants.roleBuyer,
                shopMode: AppConstants.shopModeBuyer,
              )
            : sessionPrefs(role: AppConstants.roleSeller));

        final errors = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = errors.add;
        try {
          await tester.pumpWidget(buildApp(
            route,
            arguments: route == AppRoutes.pesananDetail ? 'ORDER-TEST-1' : null,
          ));
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 250));
          }
          if (openDrawer) {
            final scaffold = find.byType(Scaffold).first;
            tester.firstState<ScaffoldState>(scaffold).openDrawer();
            for (var i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 200));
            }
          }
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$fileName'),
          );
        } finally {
          FlutterError.onError = previous;
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));
        }
      });
    }
  }
}
