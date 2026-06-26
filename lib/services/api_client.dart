import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/storage.dart';
import '../config/env.dart';

class ApiClient {
  static String get baseUrl => Env.baseApiUrl;
  static const Duration timeout = Duration(seconds: 10);

  Future<String?> getToken() async {
    return await Storage.get('access_token');
  }

  Future<String?> getRefreshToken() async {
    return await Storage.get('refresh_token');
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      'Authorization': token ?? '',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, String>> getBasicAuthHeaders(
      String user, String password) async {
    final credentials = base64Encode(utf8.encode('$user:$password'));
    return {
      'Authorization': 'Basic $credentials',
      'Content-Type': 'application/json',
    };
  }

  Future<String?> refreshAccessToken() async {
    final cookie = await Storage.get('refresh_cookie');

    final response = await http.post(
      Uri.parse('${ApiClient.baseUrl}/gold-gym/v2/auth/refreshtoken'),
      headers: {"Cookie": cookie ?? "", "Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newToken = data['access_token'];

      await Storage.set('access_token', newToken);

      return newToken;
    }

    return null;
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final headers = await getAuthHeaders();

    final url = Uri.parse("$baseUrl$endpoint");

    var response = await http
        .post(
          url,
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(timeout);

    /// token expired
    if (response.statusCode == 401) {
      final newToken = await refreshAccessToken();

      if (newToken != null) {
        response = await http
            .post(
              url,
              headers: {
                "Authorization": "Bearer $newToken",
                "Content-Type": "application/json"
              },
              body: jsonEncode(body),
            )
            .timeout(timeout);
      }
    }

    return response;
  }

  Future<http.Response> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    final headers = await getAuthHeaders();

    final uri = Uri.parse("$baseUrl$endpoint").replace(
      queryParameters: queryParams,
    );

    var response = await http.get(uri, headers: headers).timeout(timeout);

    /// jika token expired
    if (response.statusCode == 401) {
      final newToken = await refreshAccessToken();

      if (newToken != null) {
        response = await http.get(
          uri,
          headers: {
            "Authorization": "Bearer $newToken",
            "Content-Type": "application/json",
          },
        ).timeout(timeout);
      } else {
        throw Exception("Session expired");
      }
    }

    return response;
  }

  Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final headers = await getAuthHeaders();

    final uri = Uri.parse("$baseUrl$endpoint");

    var response = await http
        .put(
          uri,
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(timeout);

    /// token expired
    if (response.statusCode == 401) {
      final newToken = await refreshAccessToken();

      if (newToken != null) {
        response = await http
            .put(
              uri,
              headers: {
                "Authorization": "Bearer $newToken",
                "Content-Type": "application/json",
              },
              body: jsonEncode(body),
            )
            .timeout(timeout);
      } else {
        throw Exception("Session expired");
      }
    }

    return response;
  }

  Future<http.Response> delete(String endpoint,
      {Map<String, String>? queryParams}) async {
    final headers = await getAuthHeaders();

    final uri = Uri.parse("$baseUrl$endpoint").replace(
      queryParameters: queryParams,
    );

    var response = await http.delete(uri, headers: headers).timeout(timeout);

    /// token expired
    if (response.statusCode == 401) {
      final newToken = await refreshAccessToken();

      if (newToken != null) {
        response = await http.delete(
          uri,
          headers: {
            "Authorization": "Bearer $newToken",
            "Content-Type": "application/json",
          },
        ).timeout(timeout);
      } else {
        throw Exception("Session expired");
      }
    }

    return response;
  }
}
