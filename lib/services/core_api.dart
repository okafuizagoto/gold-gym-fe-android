import 'dart:convert';

import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../utils/storage.dart';

class CoreApi extends ApiClient {
  // POST /gold-gym/v2/userdata/login
  Future<http.Response> login(String user, String password) async {
    final headers = await getBasicAuthHeaders(user, password);
    final url =
        Uri.parse('${ApiClient.baseUrl}/gold-gym/v2/userdata?type=loginuser');
    print("url : ${ApiClient.baseUrl}");
    Map<String, dynamic> body = {
      "gold_email": user,
      "gold_password": password,
    };
    return await http
        // .post(url, headers: headers)
        .post(url, body: jsonEncode(body))
        .timeout(ApiClient.timeout);
  }

  // PUT /gold-gym/v2/userdata/buyer (wajib token) — konfirmasi "daftar
  // sebagai pembeli": set flag gold_buyer_yn = Y di akun sendiri.
  Future<http.Response> registerAsBuyer() async {
    final ApiClient client = ApiClient();
    return client.put("/gold-gym/v2/userdata/buyer", {});
  }

  // PUT /gold-gym/v2/userdata/toko (wajib token) — simpan nama toko akun
  // sendiri; saat belanja sebagai pembeli, nota menampilkan nama toko ini.
  Future<http.Response> setToko(String toko) async {
    final ApiClient client = ApiClient();
    return client.put("/gold-gym/v2/userdata/toko", {"gold_toko": toko});
  }

  // POST /gold-gym/v2/userdata?type=registerbuyer (public, tanpa token)
  // role: BUYER (default) / SELLER. toko: nama toko (khusus pembeli yang
  // didaftarkan lewat menu penjual — tampil di nota).
  Future<http.Response> registerBuyer({
    required String nama,
    required String email,
    required String password,
    required String nomorHp,
    String role = 'BUYER',
    String toko = '',
  }) async {
    final url = Uri.parse(
        '${ApiClient.baseUrl}/gold-gym/v2/userdata?type=registerbuyer');
    final body = {
      "gold_nama": nama,
      "gold_email": email,
      "gold_password": password,
      "gold_nomorhp": nomorHp,
      "gold_role": role,
      "gold_toko": toko,
    };
    return await http
        .post(url, body: jsonEncode(body))
        .timeout(ApiClient.timeout);
  }

  // GET /gold-gym/v2/userdata?type=getregistrationmode (public, tanpa token)
  // Dipanggil layar Register sebelum login, jadi TIDAK pakai ApiClient().get()
  // (itu wajib token & akan memaksa balik ke /login kalau belum ada sesi).
  // Mode: BOTH (default) / BUYER_ONLY / SELLER_ONLY.
  Future<http.Response> getRegistrationMode() async {
    final url = Uri.parse(
        '${ApiClient.baseUrl}/gold-gym/v2/userdata?type=getregistrationmode');
    return await http.get(url).timeout(ApiClient.timeout);
  }

  // PUT /gold-gym/v2/userdata/registrationmode (wajib token + role ADMIN) —
  // atur mode pendaftaran mandiri lewat menu Akses Admin -> Daftar Akun.
  Future<http.Response> updateRegistrationMode(String mode) async {
    final client = ApiClient();
    return client.put('/gold-gym/v2/userdata/registrationmode', {"mode": mode});
  }

  Future<http.Response> logout() async {
    final cookie = await Storage.get('refresh_cookie');
    final headers = {
      "Cookie": cookie ?? "",
      "Content-Type": "application/json"
    };

    final url = Uri.parse('${ApiClient.baseUrl}/gold-gym/v2/auth/logout');

    return await http
        // .post(url, headers: headers)
        .post(url, headers: headers)
        .timeout(ApiClient.timeout);
  }

  // Future<String?> logoutR() async {
  //   final cookie = await Storage.get('refresh_cookie');

  //   final response = await http.post(
  //     Uri.parse('${ApiClient.baseUrl}/gold-gym/v2/auth/logout'),
  //     headers: {"Cookie": cookie ?? "", "Content-Type": "application/json"},
  //   );

  //   // if (response.statusCode == 200) {
  //   //   final data = jsonDecode(response.body);
  //   //   final newToken = data['access_token'];

  //   //   await Storage.set('access_token', newToken);

  //   //   return newToken;
  //   // }

  //   return null;
  // }

  // GET /core/v1/users/:nip/pt
  Future<http.Response> getUserPT(
      String nip, Map<String, String>? params) async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('${ApiClient.baseUrl}/core/v1/users/$nip/pt')
        .replace(queryParameters: params);

    return await http.get(url, headers: headers).timeout(ApiClient.timeout);
  }

  // GET /core/v1/users/:nip/outlet
  Future<http.Response> getUserOutlet(
      String nip, Map<String, String>? params) async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('${ApiClient.baseUrl}/core/v1/users/$nip/outlet')
        .replace(queryParameters: params);

    return await http.get(url, headers: headers).timeout(ApiClient.timeout);
  }
}
