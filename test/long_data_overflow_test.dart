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

  /// Ketuk tab pil (SegmentedTabs) berlabel ini sebelum memeriksa data.
  final String? tabLabel;

  /// Ketuk teks pertama yang memuat potongan ini lalu tunggu (mis. memilih outlet -> pindah layar).
  final String? tapText;

  /// Jumlah putaran tunggu awal (layar yang memuat banyak endpoint berurutan butuh lebih banyak).
  final int waits;

  /// Isi semua kolom teks dengan teks sangat panjang (uji layar form).
  final bool fill;

  /// Tekan tombol simpan/kirim utama TANPA mengisi apa pun supaya pesan validasi tampil.
  final bool submitEmpty;

  /// Tekan tiap tombol di layar (maks. [maxTaps]); dialog/sheet/layar yang terbuka diisi teks panjang, dikirim kosong, lalu ditutup.
  final bool tapAll;
  final int maxTaps;

  /// Bahasa UI ('ID' | 'EN'); teks Inggris lebih panjang -> risiko overflow berbeda.
  final String lang;

  /// Data lokal yang perlu disemai sebelum layar dibuka (mis. 'outbox' = antrean transaksi offline).
  final String? seed;
  const Case(this.route,
      {this.role = AppConstants.roleSeller,
      this.marker = 'Nama Yang Sangat',
      this.pickFirstDropdown = false,
      this.tabIndex,
      this.tabLabel,
      this.tapText,
      this.waits = 10,
      this.fill = false,
      this.submitEmpty = false,
      this.tapAll = false,
      this.maxTaps = 12,
      this.lang = 'ID',
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
  prefs[AppConstants.languageKey] = c.lang;
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
    for (var i = 0; i < c.waits; i++) {
      await tester
          .runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (c.tapText != null) {
      await tester.tap(find.textContaining(c.tapText!).first);
      for (var i = 0; i < 12; i++) {
        await tester
            .runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 250));
      }
    }
    if (c.tabLabel != null) {
      await tester.tap(find.text(c.tabLabel!).first);
      for (var i = 0; i < 10; i++) {
        await tester
            .runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 250));
      }
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
    if (c.tapAll) {
      Finder buttons() => find.byWidgetPredicate((w) =>
          w is ElevatedButton ||
          w is FilledButton ||
          w is OutlinedButton ||
          w is TextButton ||
          w is IconButton ||
          w is FloatingActionButton);
      final skip = RegExp('keluar|logout|kembali|back|pilih paket|pulihkan',
          caseSensitive: false);
      var taps = 0;
      for (var i = 0; i < 40 && taps < c.maxTaps; i++) {
        final all = buttons();
        if (i >= all.evaluate().length) break;
        final target = all.at(i);
        // lewati tombol berbahaya / navigasi keluar berdasarkan teks atau tooltip di dalamnya
        final label = find.descendant(of: target, matching: find.byType(Text));
        final txt = label.evaluate().map((e) => (e.widget as Text).data ?? '').join(' ');
        final tip = (target.evaluate().first.widget is IconButton)
            ? ((target.evaluate().first.widget as IconButton).tooltip ?? '')
            : '';
        if (skip.hasMatch(txt) || skip.hasMatch(tip)) continue;
        final before = find.byType(Scaffold).evaluate().length;
        if (Platform.environment['DBG_FORM'] != null) {
          stdout.writeln('TAP ${c.route} #$i "$txt" tip="$tip" ${target.evaluate().first.widget.runtimeType}');
        }
        try {
          await tester.ensureVisible(target);
          await tester.tap(target, warnIfMissed: false);
        } catch (_) {
          continue;
        }
        taps++;
        for (var k = 0; k < 4; k++) {
          await tester
              .runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
          await tester.pump(const Duration(milliseconds: 250));
        }
        final overlay = find.byWidgetPredicate((w) =>
            w is Dialog || w is BottomSheet || w is AlertDialog);
        final pushed = find.byType(Scaffold).evaluate().length > before;
        if (overlay.evaluate().isNotEmpty || pushed) {
          // isi kolom di lapisan atas, lalu kirim kosong untuk memunculkan validasi
          final top = overlay.evaluate().isNotEmpty ? overlay : find.byType(Scaffold).last;
          final fields = find.descendant(of: top, matching: find.byType(EditableText));
          for (var f = 0; f < fields.evaluate().length && f < 8; f++) {
            try {
              await tester.enterText(fields.at(f), _long);
              await tester.pump(const Duration(milliseconds: 100));
            } catch (_) {}
          }
          await tester.pump(const Duration(milliseconds: 300));
          final subs = find.descendant(
              of: top,
              matching: find.byWidgetPredicate(
                  (w) => w is ElevatedButton || w is FilledButton));
          if (subs.evaluate().isNotEmpty) {
            try {
              await tester.tap(subs.last, warnIfMissed: false);
              for (var k = 0; k < 3; k++) {
                await tester.runAsync(
                    () => Future.delayed(const Duration(milliseconds: 60)));
                await tester.pump(const Duration(milliseconds: 250));
              }
            } catch (_) {}
          }
          // tutup lapisan: pop sampai kembali ke layar awal
          for (var k = 0; k < 3; k++) {
            final stillOver = find.byWidgetPredicate((w) =>
                w is Dialog || w is BottomSheet || w is AlertDialog).evaluate().isNotEmpty;
            final stillPushed = find.byType(Scaffold).evaluate().length > before;
            if (!stillOver && !stillPushed) break;
            final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
            if (!nav.canPop()) break;
            await nav.maybePop();
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pump(const Duration(milliseconds: 500));
          }
        }
      }
      if (Platform.environment['DBG_FORM'] != null) {
        stdout.writeln('TAPS ${c.route} taps=$taps');
      }
    }
    if (c.submitEmpty) {
      final btn = find.byWidgetPredicate((w) =>
          w is ElevatedButton || w is FilledButton || w is OutlinedButton);
      if (btn.evaluate().isNotEmpty) {
        try {
          await tester.ensureVisible(btn.last);
          await tester.tap(btn.last, warnIfMissed: false);
        } catch (_) {}
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
              () => Future.delayed(const Duration(milliseconds: 60)));
          await tester.pump(const Duration(milliseconds: 250));
        }
      }
    }
    if (c.fill) {
      final fields = find.byType(EditableText);
      final n = fields.evaluate().length;
      for (var i = 0; i < n && i < 14; i++) {
        try {
          await tester.ensureVisible(fields.at(i));
          await tester.enterText(fields.at(i), _long);
          await tester.pump(const Duration(milliseconds: 100));
        } catch (_) {}
      }
      await tester.pump(const Duration(milliseconds: 400));
      if (Platform.environment['DBG_FORM'] != null) {
        stdout.writeln(
            'FORM ${c.route} fields=$n filled=${find.textContaining('Nama Yang Sangat').evaluate().length}');
      }
    }
    if (c.submitEmpty && Platform.environment['DBG_FORM'] != null) {
      final errs = find.byWidgetPredicate((w) =>
          w is Text &&
          RegExp('wajib|harus|tidak boleh|isi |pilih|minimal', caseSensitive: false)
              .hasMatch(w.data ?? ''));
      stdout.writeln('SUBMIT ${c.route} pesan=${errs.evaluate().length}');
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
    // widget yang baru dibangun saat digulir (mis. di dasar daftar) bisa memulai request -> beri waktu selesai
    for (var i = 0; i < 4; i++) {
      await tester
          .runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (Platform.environment['DBG_REQS'] != null) {
      stdout.writeln('REQS ${c.route}: ${_reqLog.toSet().toList()}');
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

/// Plugin platform yang tidak ada di lingkungan tes (kamera/galeri, penagihan Play, buka tautan, berbagi,
/// lokasi): dijawab null supaya tombol yang memanggilnya tidak melempar MissingPluginException.
void mockPlatformPlugins() {
  for (final name in const [
    'plugins.flutter.io/image_picker',
    'plugins.flutter.io/in_app_purchase',
    'plugins.flutter.io/url_launcher',
    'dev.fluttercommunity.plus/share',
    'flutter.baseflow.com/geolocator',
    'plugins.flutter.io/file_selector',
    'flutter_blue_plus/methods',
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(name), (call) async => null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // flutter_test memblokir HTTP (selalu 400); pakai HttpClient asli supaya server lokal terjangkau.
    HttpOverrides.global = null;
    mockSecureStorage();
    mockPathProvider();
    mockPlatformPlugins();
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
    Case('/laporan', tabLabel: 'Per Minggu', marker: 'Minggu Yang Labelnya'),
    Case('/laporan', tabLabel: 'Per Bulan', marker: 'Oktober 2026'),
    Case('/laporan', tabLabel: 'Tren'),
    Case('/pesanan-masuk', marker: 'NAMA YANG SANGAT'),
    Case('/pesanan-saya',
        role: AppConstants.roleBuyer, marker: 'NAMA YANG SANGAT'),
    Case('/pilih-outlet', role: AppConstants.roleBuyer),
    Case('/pilih-outlet',
        role: AppConstants.roleBuyer, tapText: 'Nama Yang Sangat'),
    Case('/admin-outlet-pembeli', role: AppConstants.roleAdmin),
    Case('/admin-pos-customer', role: AppConstants.roleAdmin),
    Case('/', marker: ''),
    Case('/403', marker: ''),
    Case('/outlet', marker: ''),
    Case('/about-us', marker: ''),
    Case('/add-items'),
    Case('/add-menu', marker: ''),
    Case('/list-barang'),
    Case('/tambah-kas'),
    Case('/tarik-kas'),
    Case('/tambah-meja', marker: ''),
    Case('/tambah-area', marker: ''),
    Case('/new-outlet', marker: ''),
    Case('/edit-profil', marker: 'email.yang.sangat'),
    Case('/ganti-password', marker: ''),
    Case('/keamanan-akun', marker: ''),
    Case('/langganan', marker: 'Paket Yang Namanya'),
    Case('/storage'),
    Case('/thermal-printer', marker: ''),
    Case('/qris-saya', marker: ''),
    Case('/request-fitur'),
    Case('/request-aplikasi-baru', marker: ''),
    Case('/absen', marker: ''),
    Case('/daftar-pembeli', marker: ''),
    Case('/booking', marker: '2/3'),
    Case('/antrian-saya', role: AppConstants.roleBuyer, marker: ''),
    Case('/daftar-penjual', role: AppConstants.roleBuyer, marker: ''),
    Case('/admin-akses-daftar-pembeli', role: AppConstants.roleAdmin, marker: ''),
    Case('/admin-akses-mode-pembeli', role: AppConstants.roleAdmin, marker: ''),
    Case('/admin-backup', role: AppConstants.roleAdmin, marker: 'PRODUCTION-LINGKUNGAN'),
    Case('/admin-langganan-tampilan', role: AppConstants.roleAdmin, marker: ''),
    Case('/admin-outlet-type-settings', role: AppConstants.roleAdmin, marker: ''),
    Case('/admin-payment-report', role: AppConstants.roleAdmin),
    Case('/admin-plan-features', role: AppConstants.roleAdmin, marker: ''),
    Case('/admin-plan-pricing', role: AppConstants.roleAdmin, marker: ''),
    Case('/admin-proof-access', role: AppConstants.roleAdmin, marker: ''),
    Case('/admin-registration-mode', role: AppConstants.roleAdmin, marker: ''),
    Case('/admin-statistik-pengguna',
        role: AppConstants.roleAdmin, marker: 'Tanggal daftar tidak tercatat'),
    Case('/admin-storage-usage',
        role: AppConstants.roleAdmin, marker: 'PAKET-DENGAN'),
    // ---- audit FORM: kolom diisi teks sangat panjang / tombol simpan ditekan kosong (pesan validasi) ----
    Case('/add-items', marker: '', fill: true),
    Case('/add-items', marker: '', submitEmpty: true),
    Case('/add-menu', marker: '', fill: true),
    Case('/add-menu', marker: '', submitEmpty: true),
    Case('/tambah-kas', marker: '', fill: true),
    Case('/tambah-kas', marker: '', submitEmpty: true),
    Case('/tarik-kas', marker: '', fill: true),
    Case('/tarik-kas', marker: '', submitEmpty: true),
    Case('/tambah-meja', marker: '', fill: true),
    Case('/tambah-meja', marker: '', submitEmpty: true),
    Case('/tambah-area', marker: '', fill: true),
    Case('/tambah-area', marker: '', submitEmpty: true),
    Case('/new-outlet', marker: '', fill: true),
    Case('/new-outlet', marker: '', submitEmpty: true),
    Case('/edit-profil', marker: '', fill: true),
    Case('/edit-profil', marker: '', submitEmpty: true),
    Case('/ganti-password', marker: '', fill: true),
    Case('/ganti-password', marker: '', submitEmpty: true),
    Case('/keamanan-akun', marker: '', fill: true),
    Case('/keamanan-akun', marker: '', submitEmpty: true),
    Case('/request-fitur', marker: '', fill: true),
    Case('/request-fitur', marker: '', submitEmpty: true),
    Case('/request-aplikasi-baru', marker: '', fill: true),
    Case('/request-aplikasi-baru', marker: '', submitEmpty: true),
    Case('/daftar-customer', marker: '', fill: true),
    Case('/daftar-customer', marker: '', submitEmpty: true),
    Case('/customer-type', marker: '', fill: true),
    Case('/customer-type', marker: '', submitEmpty: true),
    Case('/expense', marker: '', fill: true),
    Case('/expense', marker: '', submitEmpty: true),
    Case('/diskon', marker: '', fill: true),
    Case('/diskon', marker: '', submitEmpty: true),
    Case('/qris-outlet', marker: '', fill: true),
    Case('/qris-outlet', marker: '', submitEmpty: true),
    Case('/lokasi-kantor', marker: '', fill: true),
    Case('/lokasi-kantor', marker: '', submitEmpty: true),
    Case('/transfer-stok', marker: '', fill: true),
    Case('/transfer-stok', marker: '', submitEmpty: true),
    Case('/penjualan', marker: '', fill: true),
    Case('/penjualan', marker: '', submitEmpty: true),
    Case('/booking', marker: '', fill: true),
    Case('/booking', marker: '', submitEmpty: true),
    Case('/login', marker: '', fill: true),
    Case('/login', marker: '', submitEmpty: true),
    Case('/register', marker: '', fill: true),
    Case('/register', marker: '', submitEmpty: true),
    Case('/lupa-password', marker: '', fill: true),
    Case('/lupa-password', marker: '', submitEmpty: true),
    Case('/check-email', marker: '', fill: true),
    Case('/check-email', marker: '', submitEmpty: true),
    Case('/thermal-printer', marker: '', fill: true),
    Case('/thermal-printer', marker: '', submitEmpty: true),
    Case('/daftar-pembeli', marker: '', fill: true),
    Case('/daftar-pembeli', marker: '', submitEmpty: true),
    Case('/daftar-penjual', role: AppConstants.roleBuyer, marker: '', fill: true),
    Case('/daftar-penjual', role: AppConstants.roleBuyer, marker: '', submitEmpty: true),
    Case('/admin-plan-pricing', role: AppConstants.roleAdmin, marker: '', fill: true),
    Case('/admin-plan-pricing', role: AppConstants.roleAdmin, marker: '', submitEmpty: true),
    Case('/admin-plan-features', role: AppConstants.roleAdmin, marker: '', fill: true),
    Case('/admin-plan-features', role: AppConstants.roleAdmin, marker: '', submitEmpty: true),
    Case('/admin-akun', role: AppConstants.roleAdmin, marker: '', fill: true),
    Case('/admin-akun', role: AppConstants.roleAdmin, marker: '', submitEmpty: true),
    Case('/admin-langganan-tampilan', role: AppConstants.roleAdmin, marker: '', fill: true),
    Case('/admin-langganan-tampilan', role: AppConstants.roleAdmin, marker: '', submitEmpty: true),
    // ---- audit TOMBOL: tiap tombol ditekan, dialog/sheet diisi teks panjang lalu ditutup ----
    Case('/add-items', marker: '', tapAll: true),
    Case('/tambah-kas', marker: '', tapAll: true),
    Case('/tarik-kas', marker: '', tapAll: true),
    Case('/tambah-meja', marker: '', tapAll: true),
    Case('/tambah-area', marker: '', tapAll: true),
    Case('/list-outlet', marker: '', tapAll: true),
    Case('/daftar-customer', marker: '', tapAll: true),
    Case('/customer-type', marker: '', tapAll: true),
    Case('/daftar-staff', marker: '', tapAll: true),
    Case('/meja-area', marker: '', tapAll: true),
    Case('/expense', marker: '', tapAll: true),
    Case('/stock-barang', marker: '', tapAll: true),
    Case('/kelola-meja', marker: '', tapAll: true),
    Case('/penjualan', marker: '', tapAll: true),
    Case('/cashier-shift', marker: '', tapAll: true),
    Case('/kas-history', marker: '', tapAll: true),
    Case('/laporan', marker: '', tapAll: true),
    Case('/qris-outlet', marker: '', tapAll: true),
    Case('/lokasi-kantor', marker: '', tapAll: true),
    Case('/history-sales', marker: '', tapAll: true),
    Case('/diskon', marker: '', tapAll: true),
    Case('/riwayat-refund', marker: '', tapAll: true),
    Case('/transfer-stok', marker: '', tapAll: true),
    Case('/akses-staff', marker: '', tapAll: true),
    Case('/izin-transfer-staff', marker: '', tapAll: true),
    Case('/absen-staff', marker: '', tapAll: true),
    Case('/booking', marker: '', tapAll: true),
    Case('/langganan', marker: '', tapAll: true),
    Case('/storage', marker: '', tapAll: true),
    Case('/request-fitur', marker: '', tapAll: true),
    Case('/keamanan-akun', marker: '', tapAll: true),
    Case('/edit-profil', marker: '', tapAll: true),
    Case('/thermal-printer', marker: '', tapAll: true),
    Case('/qris-saya', marker: '', tapAll: true),
    Case('/outlet', marker: '', tapAll: true),
    Case('/', marker: '', tapAll: true),
    Case('/admin-outlet-pembeli', role: AppConstants.roleAdmin, marker: '', tapAll: true),
    Case('/admin-pos-customer', role: AppConstants.roleAdmin, marker: '', tapAll: true),
    Case('/admin-proof-access', role: AppConstants.roleAdmin, marker: '', tapAll: true),
    Case('/admin-registration-mode', role: AppConstants.roleAdmin, marker: '', tapAll: true),
    Case('/admin-outlet-type-settings', role: AppConstants.roleAdmin, marker: '', tapAll: true),
    Case('/admin-langganan-tampilan', role: AppConstants.roleAdmin, marker: '', tapAll: true),
    Case('/admin-plan-pricing', role: AppConstants.roleAdmin, marker: '', tapAll: true),
    Case('/admin-plan-features', role: AppConstants.roleAdmin, marker: '', tapAll: true),
    Case('/admin-storage-usage', role: AppConstants.roleAdmin, marker: '', tapAll: true),
    Case('/admin-statistik-pengguna', role: AppConstants.roleAdmin, marker: '', tapAll: true),
    Case('/admin-akun', role: AppConstants.roleAdmin, marker: '', tapAll: true),
    Case('/admin-request-fitur', role: AppConstants.roleAdmin, marker: '', tapAll: true),
    Case('/admin-backup', role: AppConstants.roleAdmin, marker: '', tapAll: true),
    Case('/admin-payment-report', role: AppConstants.roleAdmin, marker: '', tapAll: true),
    Case('/admin-akses-daftar-pembeli', role: AppConstants.roleAdmin, marker: '', tapAll: true),
    Case('/admin-akses-mode-pembeli', role: AppConstants.roleAdmin, marker: '', tapAll: true),
    Case('/pesanan-saya', role: AppConstants.roleBuyer, marker: '', tapAll: true),
    Case('/pilih-outlet', role: AppConstants.roleBuyer, marker: '', tapAll: true),
    Case('/antrian-saya', role: AppConstants.roleBuyer, marker: '', tapAll: true),
    Case('/daftar-penjual', role: AppConstants.roleBuyer, marker: '', tapAll: true),
  ];

  // Kasus dasar (tanpa isi form/tombol) juga diuji di HP kecil LANDSCAPE dan dalam bahasa Inggris.
  bool isBase(Case c) => !c.fill && !c.submitEmpty && !c.tapAll;
  final enCases = [
    for (final c in cases)
      if (isBase(c) && c.tabLabel == null && c.seed == null)
        Case(c.route,
            role: c.role,
            marker: '',
            pickFirstDropdown: c.pickFirstDropdown,
            tabIndex: c.tabIndex,
            lang: 'EN'),
  ];
  const landscape =
      ScreenSize('hp-kecil-landscape-640x360', Size(640, 360));

  for (final c in [...cases, ...enCases]) {
    final sizesForCase = [
      ...sizes,
      if (isBase(c)) landscape,
    ];
    group(
        '${c.route} [data panjang]${c.tapAll ? ' [tap]' : c.fill ? ' [isi]' : c.submitEmpty ? ' [kosong]' : c.lang == 'EN' ? ' [EN]' : ''}',
        () {
      for (final scale in [1.0, 1.3]) {
        for (final s in sizesForCase) {
          testWidgets('tidak ada overflow @ ${s.name} font ${scale}x',
              timeout: const Timeout(Duration(seconds: 90)), (tester) async {
            final r = await renderWithData(tester, c, s.size, scale);
            // landscape sangat pendek: data bisa di luar layar; yang diperiksa hanya overflow
            expect(r.sawMarker || s.name == landscape.name, isTrue,
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
