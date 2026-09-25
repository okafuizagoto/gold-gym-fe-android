import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../utils/storage.dart';

class CoreApi extends ApiClient {
  // POST /gold-gym/v2/userdata/login
  Future<http.Response> login(String user, String password,
      {String? totpCode}) async {
    final headers = await getBasicAuthHeaders(user, password);
    final url =
        Uri.parse('${ApiClient.baseUrl}/gold-gym/v2/userdata?type=loginuser');
    print("url : ${ApiClient.baseUrl}");
    Map<String, dynamic> body = {
      "gold_email": user,
      "gold_password": password,
      if (totpCode != null && totpCode.isNotEmpty) "totp_code": totpCode,
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

  // POST /gold-gym/v2/userdata?type=resendverification (public, tanpa
  // token) -- kirim ulang email verifikasi (dipanggil dari
  // CheckEmailScreen, bukan lewat link -- itu selalu dibuka di browser).
  Future<http.Response> resendVerification(String email) async {
    final url = Uri.parse(
        '${ApiClient.baseUrl}/gold-gym/v2/userdata?type=resendverification');
    return await http
        .post(url, body: jsonEncode({"gold_email": email}))
        .timeout(ApiClient.timeout);
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

  // --- QRIS Saya (2026-09-16): foto QRIS statis milik penjual sendiri,
  // dipakai menu "Simpan QRIS Saya" & tombol "Tampilkan QRIS" di POS. BEDA
  // dari pembayaran QRIS Midtrans otomatis (lihat qris midtrans di
  // services lain) -- itu tidak pernah butuh foto sama sekali.

  /// Upload/ganti foto QRIS milik akun sendiri (multipart, maks 2 MB).
  Future<http.Response> uploadQrisPhoto(File file) async {
    final headers = await getAuthHeaders();
    final uri =
        Uri.parse('${ApiClient.baseUrl}/gold-gym/v2/userdata/qris-photo');
    final request = http.MultipartRequest('POST', uri);
    if (headers['Authorization'] != null) {
      request.headers['Authorization'] = headers['Authorization']!;
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send().timeout(ApiClient.timeout);
    return http.Response.fromStream(streamed);
  }

  /// Hapus foto QRIS milik akun sendiri.
  Future<http.Response> deleteQrisPhoto() async {
    final client = ApiClient();
    return client.delete('/gold-gym/v2/userdata/qris-photo');
  }

  /// Presigned URL (B2, berlaku 15 menit) foto QRIS. sellerGoldId kosong =
  /// punya sendiri (butuh token); diisi = lihat QRIS penjual lain saat
  /// checkout (endpoint publik di backend, tapi tetap lewat ApiClient
  /// supaya token ikut terkirim kalau ada -- tidak masalah kalau tidak
  /// ada, backend tidak mewajibkannya untuk route ini).
  Future<String?> getQrisPhotoUrl({int? sellerGoldId}) async {
    final client = ApiClient();
    final endpoint = sellerGoldId != null
        ? '/gold-gym/v2/userdata/$sellerGoldId/qris-photo'
        : '/gold-gym/v2/userdata/qris-photo';
    final response = await client.get(endpoint);
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['url'] as String?;
  }

  // --- QRIS per OUTLET (2026-09-25): menggantikan "QRIS Saya" per-akun di atas -- satu
  // penjual bisa punya banyak outlet, tiap outlet foto QRIS sendiri. Tetap tercatat sebagai
  // transfer bank di POS, cuma cara tampil kode QR ke pembeli.

  /// Upload/ganti foto QRIS milik satu outlet (multipart, maks 2 MB).
  Future<http.Response> uploadOutletQrisPhoto(String outletCode, File file) async {
    final headers = await getAuthHeaders();
    final uri = Uri.parse(
        '${ApiClient.baseUrl}/gold-gym/v2/userdata/outlet/$outletCode/qris-photo');
    final request = http.MultipartRequest('POST', uri);
    if (headers['Authorization'] != null) {
      request.headers['Authorization'] = headers['Authorization']!;
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send().timeout(ApiClient.timeout);
    return http.Response.fromStream(streamed);
  }

  /// Hapus foto QRIS milik satu outlet.
  Future<http.Response> deleteOutletQrisPhoto(String outletCode) async {
    final client = ApiClient();
    return client.delete('/gold-gym/v2/userdata/outlet/$outletCode/qris-photo');
  }

  /// Presigned URL (B2, berlaku 15 menit) foto QRIS outlet. sellerGoldId kosong = outlet milik
  /// sendiri (butuh token); diisi = lihat QRIS outlet penjual lain saat checkout.
  Future<String?> getOutletQrisPhotoUrl(String outletCode,
      {int? sellerGoldId}) async {
    final client = ApiClient();
    final endpoint = sellerGoldId != null
        ? '/gold-gym/v2/userdata/$sellerGoldId/outlet/$outletCode/qris-photo'
        : '/gold-gym/v2/userdata/outlet/$outletCode/qris-photo';
    final response = await client.get(endpoint);
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['url'] as String?;
  }

  /// Pakai foto QRIS outlet lain untuk outlet ini, tanpa upload ulang (disimpan ke database,
  /// tetap ada setelah logout/login).
  Future<http.Response> copyOutletQrisPhoto(
      String toOutletCode, String fromOutletCode) async {
    final client = ApiClient();
    return client.post(
      '/gold-gym/v2/userdata/outlet/$toOutletCode/qris-photo/copy',
      {'from_outlet_code': fromOutletCode},
    );
  }
}
