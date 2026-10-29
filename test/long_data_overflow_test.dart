// Audit layar dengan DATA PANJANG (nama/alamat/email sangat panjang) pada HP kecil + font besar.
// Audit responsive_overflow_test.dart memakai data kosong sehingga bug jenis "nama panjang meluap"
// lolos. Di sini sebuah server HTTP lokal palsu mengisi layar dengan data uji panjang, lalu test GAGAL
// kalau ada "RenderFlex overflowed".
//
// Jalankan: flutter test test/long_data_overflow_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gold_gym_fe_android/services/offline/connectivity_monitor.dart';
import 'package:gold_gym_fe_android/services/offline/sales_outbox.dart';
import 'package:gold_gym_fe_android/utils/constants.dart';

import 'fake_api_data.dart';
import 'responsive_overflow_test.dart'
    show buildApp, loadAppFonts, sessionPrefs, ScreenSize;

const _long =
    'Nama Yang Sangat Panjang Sekali Sampai Melebihi Lebar Layar HP Kecil Berukuran 360 Dp Tanpa Spasi-Putus';

/// Satu kasus: layar [route] diisi data dari [FakeApi].
class Case {
  final String route;
  final String role;

  /// Potongan teks data uji yang HARUS tampil -- memastikan layar benar-benar menerima data
  /// (bukan lolos karena kosong).
  final String marker;

  /// Buka dropdown pertama lalu pilih item pertama (layar yang menampilkan data hanya setelah memilih).
  final bool pickFirstDropdown;

  /// Buka tab ke-n (layar ber-TabBar) sebelum memeriksa data.
  final int? tabIndex;

  /// Data lokal yang perlu disemai sebelum layar dibuka (mis. 'outbox' = antrean transaksi offline).
  final String? seed;
  const Case(this.route,
      {this.role = AppConstants.roleSeller,
      this.marker = 'Nama Yang Sangat',
      this.pickFirstDropdown = false,
      this.tabIndex,
      this.seed});
}

Future<({List<String> overflows, bool sawMarker})> renderWithData(
  WidgetTester tester,
  Case c,
  Size size,
  double scale,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  late HttpServer server;
  await tester.runAsync(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      _reqLog.add('${req.method} ${req.uri.path}');
      final body = FakeApi.respond(
          req.method, req.uri.path, req.uri.queryParameters, _long);
      req.response.statusCode = 200;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(body));
      await req.response.close();
    });
  });
  dotenv.testLoad(
      fileInput:
          'ENVIRONMENT=local\nBASE_API_URL=http://127.0.0.1:${server.port}');
  final prefs = sessionPrefs(role: c.role);
  _secure
    ..clear()
    ..[AppConstants.accessTokenKey] =
        prefs[AppConstants.accessTokenKey] as String;
  SharedPreferences.setMockInitialValues(prefs);

  final overflows = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (d) {
    if (!d.exceptionAsString().contains('overflowed')) return;
    // Deskripsi widget penyebab dihitung SEKARANG (pohon widget masih hidup); setelah dibongkar gagal.
    String loc = '';
    try {
      loc = RegExp(r'lib/[A-Za-z0-9_/]+\.dart:\d+:\d+')
              .firstMatch(d.toString())
              ?.group(0) ??
          '';
    } catch (_) {}
    overflows.add(
        '${d.exceptionAsString().split('\n').first}${loc.isEmpty ? '' : ' @ $loc'}');
  };
  var sawMarker = false;
  if (c.seed == 'outbox') {
    await tester.runAsync(() async {
      // offline -> submit() hanya mengantre; tandai sebagai ditolak dengan pesan panjang
      ConnectivityMonitor.instance.reportNetworkFailure();
      await SalesOutbox.instance.submit({
        'data': {
          'header': {
            'sale_outcode': 'OUT01',
            'sale_transtotal': 123456789.0,
            'sale_salescustomer': _long,
          },
          'detail': [
            {'sale_stockid': '1', 'sale_stockname': _long, 'sale_qty': 1}
          ],
        }
      });
      for (final e in SalesOutbox.instance.items) {
        e.status = OutboxStatus.failed;
        e.error = _long;
      }
    });
  }
  try {
    await tester.pumpWidget(buildApp(c.route, textScale: scale));
    for (var i = 0; i < 10; i++) {
      await tester
          .runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (c.tabIndex != null) {
      await tester.tap(find.byType(Tab).at(c.tabIndex!));
      for (var i = 0; i < 8; i++) {
        await tester
            .runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 250));
      }
    }
    if (c.pickFirstDropdown) {
      final dd = find.byType(DropdownButtonFormField<int>);
      final dd2 = find.byWidgetPredicate((w) => w is DropdownButtonFormField);
      final target = dd.evaluate().isNotEmpty ? dd.first : dd2.first;
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 400));
      await tester
          .tap(find.byWidgetPredicate((w) => w is DropdownMenuItem).last);
      for (var i = 0; i < 8; i++) {
        await tester
            .runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 250));
      }
    }
    sawMarker = find.textContaining(c.marker).evaluate().isNotEmpty;
    // Telusuri layar ke bawah: item list dibangun malas (lazy), jadi yang di luar layar baru dirender
    // (dan baru bisa meluap) saat di-scroll.
    for (var i = 0;
        i < 6 && find.byType(Scrollable).evaluate().isNotEmpty;
        i++) {
      try {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -350));
      } catch (_) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 300));
      sawMarker =
          sawMarker || find.textContaining(c.marker).evaluate().isNotEmpty;
    }
    if (!sawMarker) {
      stdout.writeln(
          'DBG texts: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).take(12).toList()}');
      stdout.writeln('DBG reqs: $_reqLog');
    }
  } finally {
    FlutterError.onError = previous;
    await tester.pumpWidget(const SizedBox.shrink());
    ConnectivityMonitor.instance.stop();
    SalesOutbox.instance.stop();
    // biarkan request yang masih berjalan selesai/kedaluwarsa (Timer .timeout(10s) milik ApiClient)
    await tester
        .runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(
        seconds: 65)); // melewati idleTimeout 60 dtk HttpClient bersama
    // init() async singleton bisa membuat Timer SETELAH stop() pertama -> hentikan lagi sesudah menunggu
    ConnectivityMonitor.instance.stop();
    SalesOutbox.instance.stop();
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => server.close(force: true));
  }
  return (overflows: overflows, sawMarker: sawMarker);
}

/// flutter_secure_storage tidak ada di lingkungan tes: tiru dengan Map di memori supaya token sesi
/// (Storage.get('access_token')) terbaca dan ApiClient mengirim request sungguhan.
final Map<String, String> _secure = {};
final List<String> _reqLog = [];

void mockSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      final key = (call.arguments as Map?)?['key'] as String?;
      switch (call.method) {
        case 'read':
          return _secure[key];
        case 'write':
          _secure[key!] = (call.arguments as Map)['value'] as String;
          return null;
        case 'delete':
          _secure.remove(key);
          return null;
        case 'deleteAll':
          _secure.clear();
          return null;
        case 'containsKey':
          return _secure.containsKey(key);
        case 'readAll':
          return Map<String, String>.from(_secure);
      }
      return null;
    },
  );
}

/// path_provider (dipakai OfflineStore untuk cache stok / keranjang parkir) tidak ada di lingkungan tes:
/// arahkan ke folder sementara.
void mockPathProvider() {
  final dir = Directory.systemTemp.createTempSync('okejual_test_');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => dir.path,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // flutter_test memblokir HTTP (selalu 400); pakai HttpClient asli supaya server lokal terjangkau.
    HttpOverrides.global = null;
    mockSecureStorage();
    mockPathProvider();
    await initializeDateFormatting('id_ID', null);
    await loadAppFonts();
  });

  const sizes = [
    ScreenSize('hp-kecil-360x640', Size(360, 640)),
    ScreenSize('hp-umum-412x915', Size(412, 915)),
  ];
  const cases = [
    // Antrean Transaksi memakai singleton SalesOutbox: HARUS pertama, sebelum layar POS menginisialisasinya.
    Case('/antrean-transaksi', seed: 'outbox'),
    Case('/admin-akun'),
    Case('/list-outlet'),
    Case('/daftar-customer'),
    Case('/customer-type'),
    Case('/daftar-staff'),
    Case('/meja-area'),
    Case('/expense'),
    Case('/stock-barang'),
    Case('/antrian-pos', marker: 'MENUNGGU'),
    Case('/admin-request-fitur'),
    Case('/kelola-meja'),
    Case('/penjualan'),
    Case('/cashier-shift'),
    Case('/kas-history'),
    Case('/laporan'),
    Case('/qris-outlet'),
    Case('/lokasi-kantor'),
    Case('/history-sales'),
    Case('/diskon', tabIndex: 1),
    Case('/riwayat-refund'),
    Case('/transfer-stok'),
    Case('/akses-staff', pickFirstDropdown: true),
    Case('/izin-transfer-staff', pickFirstDropdown: true),
    Case('/absen-staff', pickFirstDropdown: true),
  ];

  for (final c in cases) {
    group('${c.route} [data panjang]', () {
      for (final scale in [1.0, 1.3]) {
        for (final s in sizes) {
          testWidgets('tidak ada overflow @ ${s.name} font ${scale}x',
              timeout: const Timeout(Duration(seconds: 90)), (tester) async {
            final r = await renderWithData(tester, c, s.size, scale);
            expect(r.sawMarker, isTrue,
                reason:
                    '${c.route}: data uji tidak tampil -- tes tidak bermakna');
            expect(r.overflows, isEmpty,
                reason:
                    '${c.route} meluap @ ${s.name} font ${scale}x:\n${r.overflows.join('\n')}');
          });
        }
      }
    });
  }
}
