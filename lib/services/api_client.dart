import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/storage.dart';
import '../utils/navigation.dart';
import '../config/env.dart';
import '../config/routes.dart';

/// Dilempar saat sesi benar-benar habis (token tidak ada & refresh gagal).
/// Saat ini dilempar setelah aplikasi otomatis diarahkan kembali ke /login.
class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException([this.message = 'Sesi berakhir, silakan login lagi']);
  @override
  String toString() => message;
}

/// Dilempar oleh service ADMIN-only (backup/feature-request/dll) saat
/// backend balas 403 -- dibedakan dari error lain (500/timeout) supaya
/// layar bisa tampilkan "Khusus admin" HANYA untuk kasus akses ditolak,
/// bukan untuk error server biasa (QA audit 2026-09-18, bug #1.1/#1.4).
class ForbiddenException implements Exception {
  final String message;
  ForbiddenException([this.message = 'Khusus admin']);
  @override
  String toString() => message;
}

/// Baca pesan error dari body JSON backend (`{"error": "..."}`), fallback
/// ke [fallback] kalau body bukan JSON atau tidak punya field itu -- pola
/// yang sudah dipakai di laporan_tren_view.dart, disatukan di sini supaya
/// tidak diulang-ulang di tiap service.
String extractErrorMessage(http.Response response, String fallback) {
  try {
    final body = jsonDecode(response.body);
    if (body is Map && body['error'] is String) return body['error'];
  } catch (_) {}
  return fallback;
}

/// Lempar [ForbiddenException] untuk 403, atau [Exception] dengan pesan
/// backend untuk status non-200 lainnya. Dipakai service yang perlu
/// membedakan "khusus admin" dari error biasa (backup, feature-request).
void throwOnErrorStatus(http.Response response, String fallbackMessage) {
  if (response.statusCode == 403) {
    throw ForbiddenException();
  }
  if (response.statusCode != 200) {
    throw Exception(extractErrorMessage(response, fallbackMessage));
  }
}

class ApiClient {
  static String get baseUrl => Env.baseApiUrl;
  static const Duration timeout = Duration(seconds: 10);

  // Cegah beberapa request paralel memicu logout/navigasi berkali-kali.
  static bool _loggingOut = false;

  Future<String?> getToken() async {
    return await Storage.get('access_token');
  }

  Future<String?> getRefreshToken() async {
    return await Storage.get('refresh_token');
  }

  /// Pastikan token selalu ber-prefix "Bearer " agar konsisten dipakai di header.
  String _bearer(String raw) {
    final t = raw.trim();
    if (t.toLowerCase().startsWith('bearer ')) return t;
    return 'Bearer $t';
  }

  Future<Map<String, String>> getBasicAuthHeaders(
      String user, String password) async {
    final credentials = base64Encode(utf8.encode('$user:$password'));
    return {
      'Authorization': 'Basic $credentials',
      'Content-Type': 'application/json',
    };
  }

  /// Alias publik dipakai service turunan (SalesApi, StockApi, dll) yang
  /// membangun request http-nya sendiri — ikut dapat perilaku refresh/logout.
  Future<Map<String, String>> getAuthHeaders() => _authHeaders();

  /// Ambil header auth. Jika token TIDAK ADA (null/kosong) -> coba refresh dulu.
  /// Jika refresh gagal -> paksa kembali ke /login dan lempar SessionExpired.
  Future<Map<String, String>> _authHeaders() async {
    var token = await getToken();
    if (token == null || token.isEmpty) {
      token = await refreshAccessToken();
      if (token == null || token.isEmpty) {
        await forceLogout();
        throw SessionExpiredException();
      }
    }
    return {
      'Authorization': token,
      'Content-Type': 'application/json',
    };
  }

  /// Header untuk retry setelah 401 memakai token baru hasil refresh.
  Map<String, String> _headersWith(String token) => {
        'Authorization': token,
        'Content-Type': 'application/json',
      };

  /// Panggil saat menerima 401: coba refresh; kalau gagal -> paksa logout.
  /// Mengembalikan token baru (ber-prefix Bearer) atau melempar SessionExpired.
  Future<String> _refreshOrLogout() async {
    final newToken = await refreshAccessToken();
    if (newToken == null || newToken.isEmpty) {
      await forceLogout();
      throw SessionExpiredException();
    }
    return newToken;
  }

  Future<String?> refreshAccessToken() async {
    final cookie = await Storage.get('refresh_cookie');
    if (cookie == null || cookie.isEmpty) {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/gold-gym/v2/auth/refreshtoken'),
        headers: {"Cookie": cookie, "Content-Type": "application/json"},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = (data['access_token'] ?? '') as String;
        if (raw.isEmpty) return null;

        final token = _bearer(raw);
        await Storage.set('access_token', token);
        return token;
      }
      // Sesi ini digantikan login di perangkat lain ("1 akun 1 device", login
      // terakhir menang): tandai supaya layar login menampilkan alasannya.
      if (response.statusCode == 401) {
        final data = jsonDecode(response.body);
        if (data is Map && data['error'] == 'SESSION_REPLACED') {
          await Storage.set('session_replaced', '1');
        }
      }
    } catch (_) {
      // gagal jaringan / parsing -> anggap refresh gagal
    }

    return null;
  }

  /// Hapus sesi lokal dan arahkan aplikasi kembali ke layar login,
  /// membuang semua route sebelumnya.
  Future<void> forceLogout() async {
    await Storage.delete('access_token');
    await Storage.delete('refresh_cookie');

    if (_loggingOut) return;
    _loggingOut = true;

    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
    // beri jeda singkat lalu buka lagi guard supaya login berikutnya normal
    Future.delayed(const Duration(milliseconds: 500), () {
      _loggingOut = false;
    });
  }

  // KOREKSI 2026-09-18 (QA audit, mirror dari bug Next.js #2.3): dulu SEMUA
  // POST -- termasuk trigger backup manual yang memicu mysqldump+gzip+
  // upload B2 SINKRON di server -- terikat ke `timeout` global (10s).
  // Timeout klien yang terlalu pendek untuk operasi server berat bisa
  // membunuh proses backup di tengah jalan murni karena timeout klien,
  // bukan masalah nyata di server. `timeoutOverride` opsional, default
  // null = perilaku lama (semua caller lain tidak berubah).
  Future<http.Response> post(String endpoint, Map<String, dynamic> body,
      {Duration? timeoutOverride}) async {
    final effectiveTimeout = timeoutOverride ?? timeout;
    final headers = await _authHeaders();
    final url = Uri.parse("$baseUrl$endpoint");

    var response = await http
        .post(url, headers: headers, body: jsonEncode(body))
        .timeout(effectiveTimeout);

    if (response.statusCode == 401) {
      final newToken = await _refreshOrLogout();
      response = await http
          .post(url, headers: _headersWith(newToken), body: jsonEncode(body))
          .timeout(effectiveTimeout);
    }

    return response;
  }

  Future<http.Response> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    final headers = await _authHeaders();
    final uri = Uri.parse("$baseUrl$endpoint").replace(
      queryParameters: queryParams,
    );

    var response = await http.get(uri, headers: headers).timeout(timeout);

    if (response.statusCode == 401) {
      final newToken = await _refreshOrLogout();
      response =
          await http.get(uri, headers: _headersWith(newToken)).timeout(timeout);
    }

    return response;
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    final uri = Uri.parse("$baseUrl$endpoint");

    var response = await http
        .put(uri, headers: headers, body: jsonEncode(body))
        .timeout(timeout);

    if (response.statusCode == 401) {
      final newToken = await _refreshOrLogout();
      response = await http
          .put(uri, headers: _headersWith(newToken), body: jsonEncode(body))
          .timeout(timeout);
    }

    return response;
  }

  Future<http.Response> patch(
      String endpoint, Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    final uri = Uri.parse("$baseUrl$endpoint");

    var response = await http
        .patch(uri, headers: headers, body: jsonEncode(body))
        .timeout(timeout);

    if (response.statusCode == 401) {
      final newToken = await _refreshOrLogout();
      response = await http
          .patch(uri, headers: _headersWith(newToken), body: jsonEncode(body))
          .timeout(timeout);
    }

    return response;
  }

  Future<http.Response> delete(String endpoint,
      {Map<String, String>? queryParams}) async {
    final headers = await _authHeaders();
    final uri = Uri.parse("$baseUrl$endpoint").replace(
      queryParameters: queryParams,
    );

    var response = await http.delete(uri, headers: headers).timeout(timeout);

    if (response.statusCode == 401) {
      final newToken = await _refreshOrLogout();
      response = await http
          .delete(uri, headers: _headersWith(newToken))
          .timeout(timeout);
    }

    return response;
  }
}
