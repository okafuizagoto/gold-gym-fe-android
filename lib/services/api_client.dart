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

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    final url = Uri.parse("$baseUrl$endpoint");

    var response = await http
        .post(url, headers: headers, body: jsonEncode(body))
        .timeout(timeout);

    if (response.statusCode == 401) {
      final newToken = await _refreshOrLogout();
      response = await http
          .post(url, headers: _headersWith(newToken), body: jsonEncode(body))
          .timeout(timeout);
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
