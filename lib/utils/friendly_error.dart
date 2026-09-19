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
const msgServer = 'Terjadi kesalahan pada server. Silakan coba lagi nanti.';

final _code = RegExp(r'^[A-Z0-9_]+$'); // kode seperti TOKEN_EXPIRED -- dibiarkan
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

String friendlyErrorMessage(String raw, {bool? production}) {
  if (!(production ?? Env.isProduction)) return raw;
  final m = raw.trim().replaceFirst(_prefix, '');
  if (m.isEmpty) return msgServer;
  if (_code.hasMatch(m)) return m;

  final isLogin = _loginTag.hasMatch(m) || _credPhrase.hasMatch(m);
  if (_networkKw.hasMatch(m)) {
    return _serverNetKw.hasMatch(m) ? msgServer : msgNetwork;
  }
  if (isLogin) {
    // Login gagal: email tidak ada ATAU password salah -> SATU pesan yang sama
    // (tidak membocorkan email mana yang terdaftar). Kalau penyebabnya
    // masalah server (DB/redis mati) tampilkan pesan server.
    return _internalKw.hasMatch(m) &&
            !_notFoundTech.hasMatch(m) &&
            !_credPhrase.hasMatch(m)
        ? msgServer
        : msgLoginFailed;
  }
  if (_notFoundTech.hasMatch(m)) return msgNotFound;
  if (_layerTag.hasMatch(m) || _internalKw.hasMatch(m)) return msgServer;
  return m;
}
