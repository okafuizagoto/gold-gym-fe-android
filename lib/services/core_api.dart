import 'dart:convert';

import 'package:http/http.dart' as http;
import 'api_client.dart';

class CoreApi extends ApiClient {
  // POST /gold-gym/v2/userdata/login
  Future<http.Response> login(String user, String password) async {
    final headers = await getBasicAuthHeaders(user, password);
    final url = Uri.parse('${ApiClient.baseUrl}/gold-gym/v2/userdata?type=loginuser');

  Map<String, dynamic> body = {
  "gold_email": user,
  "gold_password": password,
};
    return await http
        // .post(url, headers: headers)
        .post(url, body: jsonEncode(body))
        .timeout(ApiClient.timeout);
  }

  // GET /core/v1/users/:nip/pt
  Future<http.Response> getUserPT(String nip, Map<String, String>? params) async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('${ApiClient.baseUrl}/core/v1/users/$nip/pt')
        .replace(queryParameters: params);

    return await http
        .get(url, headers: headers)
        .timeout(ApiClient.timeout);
  }

  // GET /core/v1/users/:nip/outlet
  Future<http.Response> getUserOutlet(String nip, Map<String, String>? params) async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('${ApiClient.baseUrl}/core/v1/users/$nip/outlet')
        .replace(queryParameters: params);

    return await http
        .get(url, headers: headers)
        .timeout(ApiClient.timeout);
  }
}
