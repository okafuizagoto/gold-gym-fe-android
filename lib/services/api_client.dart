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

  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      'Authorization': token ?? '',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, String>> getBasicAuthHeaders(String user, String password) async {
    final credentials = base64Encode(utf8.encode('$user:$password'));
    return {
      'Authorization': 'Basic $credentials',
      'Content-Type': 'application/json',
    };
  }
}
