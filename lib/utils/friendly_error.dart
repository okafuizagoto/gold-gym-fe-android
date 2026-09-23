import '../config/env.dart';

/// Pesan error yang aman & ramah untuk user. HANYA aktif di production
/// (Env.isProduction) -- di staging/local pesan backend ditampilkan apa adanya
/// supaya mudah debug. Detail asli TETAP ada di backend (log/trace Grafana) --
/// ini hanya mengubah apa yang DILIHAT user di layar.
///
/// Aturan sama persis dengan utils/friendlyError.ts (Next.js) -- ubah
/// keduanya bersamaan.
const msgLoginFailed = 'Email/username atau password salah.';
const msgNotFound = 'Data tidak ditemukan.';
const msgNetwork =
    'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';

/// Error di sisi server (production): pesan profesional + KODE GALAT supaya admin bisa menelusuri di
/// log/Grafana. Kode diturunkan dari tag lapisan backend, mis.
/// "[Service][RegisterBuyer][sendVerificationEmail]" -> "ERR-REGISTERBUYER-SENDVERIFICATIONEMAIL"
/// (lapisan pertama Service/Data/... dibuang). Tanpa tag: "ERR-SERVER". Detail teknis lain TIDAK ikut tampil.
/// Sama dengan serverErrorCode/serverErrorMessage di utils/friendlyError.ts.
String serverErrorCode(String raw) {
  final tags = RegExp(r'\[([A-Za-z_]+)\]')
      .allMatches(raw)
      .map((t) => t.group(1)!)
      .toList();
  final parts = tags.length >= 2 ? tags.skip(1).take(3).toList() : <String>[];
  return 'ERR-${parts.isEmpty ? 'SERVER' : parts.join('-').toUpperCase()}';
}

String serverErrorMessage(String raw) =>
    'Mohon maaf, terjadi kendala pada sistem kami. Silakan coba kembali beberapa saat lagi. '
    'Apabila kendala berlanjut, mohon hubungi admin dan sertakan kode galat: ${serverErrorCode(raw)}.';

final _code =
    RegExp(r'^[A-Z0-9_]+$'); // kode seperti TOKEN_EXPIRED -- dibiarkan
final _layerTag = RegExp(
    r'\[[A-Za-z_]+\]\[[A-Za-z_]+\]|\[(service|data|repository|repo|delivery|handler)\]',
    caseSensitive: false);
final _loginTag = RegExp(r'\[(loginuser|login)\]', caseSensitive: false);
final _credPhrase = RegExp(
    r'(password did not match|invalid password|invalid credentials|wrong password)',
    caseSensitive: false);
final _networkKw = RegExp(
    r'(network error|timeout of|timeout exceeded|econnaborted|failed to fetch|socketexception|clientexception|failed host lookup|dial tcp|connection refused|no such host|i/o timeout|context deadline|context canceled)',
    caseSensitive: false);
final _serverNetKw = RegExp(
    r'dial tcp|connection refused|no such host|deadline|canceled|i/o timeout',
    caseSensitive: false);
final _internalKw = RegExp(
    r"(sql|gorm|mysql|mariadb|duplicate entry|error 1\d{3}|unknown column|redis|kafka|elasticsearch|mongo|panic|runtime error|nil pointer|goroutine|json: |cannot unmarshal|invalid character|unexpected end of json|unexpected eof|strconv\.|key: '|field validation|\.go:\d|rpc error|x509|tls:)",
    caseSensitive: false);
final _notFoundTech =
    RegExp(r'(record not found|no rows in result set)', caseSensitive: false);
final _prefix = RegExp(r'^(Error|Exception):\s*', caseSensitive: false);

/// Kode error langganan/batas/sesi dari backend -> pesan yang jelas untuk user. Berlaku di
/// SEMUA environment (ini pesan produk, bukan detail teknis), dan dikenali walau kodenya
/// terbungkus di dalam pesan lain (mis. "[Service]...: OUTLET_LOCKED").
/// Sama dengan PLAN_MESSAGES di utils/friendlyError.ts.
const _planMessages = <String, String>{
  'SUBSCRIPTION_EXPIRED':
      'Langganan Anda sudah berakhir, aplikasi dalam mode baca saja. Pilih paket di menu Langganan untuk melanjutkan.',
  'PLAN_UPGRADE_REQUIRED':
      'Fitur ini belum termasuk di paket Anda. Lihat paket di menu Langganan.',
  'PLAN_LIMIT_OUTLETS':
      'Batas jumlah outlet paket Anda sudah tercapai. Naikkan paket di menu Langganan untuk menambah outlet.',
  'PLAN_LIMIT_USERS':
      'Batas jumlah pengguna paket Anda sudah tercapai. Naikkan paket di menu Langganan untuk menambah karyawan.',
  'OUTLET_LOCKED':
      'Outlet ini terkunci karena melebihi batas paket Anda. Naikkan paket di menu Langganan.',
  'PLAY_NOT_CONFIGURED':
      'Pembayaran langganan belum tersedia. Coba lagi nanti.',
  'PLAY_ACCOUNT_MISMATCH': 'Pembelian ini terikat ke akun lain.',
  'PLAY_TOKEN_IN_USE': 'Pembelian ini sudah dipakai oleh akun lain.',
  'PLAY_PAYMENT_PENDING':
      'Pembayaran masih diproses. Langganan aktif otomatis setelah selesai.',
  'PLAY_UNKNOWN_PRODUCT': 'Produk langganan tidak dikenali.',
  'SESSION_REPLACED':
      'Akun Anda sedang dipakai di perangkat lain. Silakan masuk lagi.',
};

String friendlyErrorMessage(String raw, {bool? production}) {
  for (final e in _planMessages.entries) {
    if (raw.contains(e.key)) return e.value;
  }
  if (!(production ?? Env.isProduction)) return raw;
  final m = raw.trim().replaceFirst(_prefix, '');
  if (m.isEmpty) return serverErrorMessage('');
  if (_code.hasMatch(m)) return m;

  final isLogin = _loginTag.hasMatch(m) || _credPhrase.hasMatch(m);
  if (_networkKw.hasMatch(m)) {
    return _serverNetKw.hasMatch(m) ? serverErrorMessage(m) : msgNetwork;
  }
  if (isLogin) {
    // Login gagal: email tidak ada ATAU password salah -> SATU pesan yang sama
    // (tidak membocorkan email mana yang terdaftar). Kalau penyebabnya
    // masalah server (DB/redis mati) tampilkan pesan server.
    return _internalKw.hasMatch(m) &&
            !_notFoundTech.hasMatch(m) &&
            !_credPhrase.hasMatch(m)
        ? serverErrorMessage(m)
        : msgLoginFailed;
  }
  if (_notFoundTech.hasMatch(m)) return msgNotFound;
  if (_layerTag.hasMatch(m) || _internalKw.hasMatch(m)) {
    return serverErrorMessage(m);
  }
  return m;
}
