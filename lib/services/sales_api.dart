import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class SalesApi extends ApiClient {
  final ApiClient _client = ApiClient();

  /// Insert sales: seluruh item cart dikirim sekali sebagai array `detail`,
  /// backend memasukkan request ke antrian Kafka lalu diproses async.
  Future<http.Response> insertSales(Map<String, dynamic> data) {
    return _client.post("/gold-gym/v2/sales?type=insertsales", data);
  }

  /// Daftar bukti pembayaran transfer milik satu nota (Sales History).
  Future<http.Response> getPaymentProofs(String saleId) {
    return _client.get("/gold-gym/v2/sales", queryParams: {
      "type": "proofs",
      "saleid": saleId,
    });
  }

  /// Ambil bytes foto bukti pembayaran (untuk ditampilkan / disimpan galeri).
  Future<Uint8List?> getProofPhoto(int proofId) async {
    final headers = await getAuthHeaders();
    final uri = Uri.parse(
        '${ApiClient.baseUrl}/gold-gym/v2/sales?type=proofphoto&proofid=$proofId');
    final response =
        await http.get(uri, headers: headers).timeout(ApiClient.timeout);
    if (response.statusCode == 200) return response.bodyBytes;
    return null;
  }

  /// Upload foto bukti pembayaran transfer bank (multipart, maks 5 MB).
  /// Backend menyimpan file di server + metadata di tabel payment_proof;
  /// ditolak dengan pesan "hubungi admin" jika kuota global 10 GB penuh.
  Future<http.Response> uploadPaymentProof(String saleId, File file) async {
    final headers = await getAuthHeaders();
    final uri = Uri.parse(
        '${ApiClient.baseUrl}/gold-gym/v2/sales?type=uploadproof&saleid=$saleId');
    final request = http.MultipartRequest('POST', uri);
    if (headers['Authorization'] != null) {
      request.headers['Authorization'] = headers['Authorization']!;
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send().timeout(ApiClient.timeout);
    return http.Response.fromStream(streamed);
  }

  /// POS: apakah outlet ini wajib mengisi nama customer.
  Future<http.Response> customerRequired(String outcode) {
    return _client.get("/gold-gym/v2/sales",
        queryParams: {"type": "customerrequired", "code": outcode});
  }

  /// ADMIN: daftar outlet RETAIL + alamat + penanda akses POS-tanpa-customer.
  /// name mencocokkan nama ATAU alamat outlet.
  Future<http.Response> getPosOutletsAdmin(String name) {
    final params = {"type": "posoutlets"};
    if (name.isNotEmpty) params["name"] = name;
    return _client.get("/gold-gym/v2/sales", queryParams: params);
  }

  /// ADMIN: simpan akses POS-tanpa-customer untuk sekumpulan outlet yang tampil.
  Future<http.Response> savePosCustomerAccess(List<Map<String, dynamic>> items) {
    return _client
        .post("/gold-gym/v2/sales?type=savecustomeraccess", {"items": items});
  }

  /// Apakah fitur bukti pembayaran (upload di POS/belanja, tombol lihat di
  /// Sales History) tampil untuk user ini. outcode boleh kosong (mis. pembeli
  /// belum pilih outlet) — gerbang outlet otomatis dilewati backend.
  Future<http.Response> getProofVisibility(String outcode) {
    final params = {"type": "proofvisibility"};
    if (outcode.isNotEmpty) params["code"] = outcode;
    return _client.get("/gold-gym/v2/sales", queryParams: params);
  }

  /// ADMIN: status gerbang GLOBAL fitur bukti pembayaran.
  Future<http.Response> getProofAccessGlobal() {
    return _client
        .get("/gold-gym/v2/sales", queryParams: {"type": "proofglobal"});
  }

  /// ADMIN: nyalakan/matikan fitur bukti pembayaran untuk SEMUA user.
  Future<http.Response> saveProofAccessGlobal(bool enabled) {
    return _client.post(
        "/gold-gym/v2/sales?type=saveproofglobal", {"enabled": enabled});
  }

  /// ADMIN: daftar SEMUA outlet (RETAIL & THERAPY) + status aktif/nonaktif
  /// fitur bukti pembayaran. name mencocokkan nama ATAU alamat outlet.
  Future<http.Response> getProofAccessOutlets(String name) {
    final params = {"type": "proofoutlets"};
    if (name.isNotEmpty) params["name"] = name;
    return _client.get("/gold-gym/v2/sales", queryParams: params);
  }

  /// ADMIN: simpan status aktif/nonaktif fitur bukti pembayaran untuk
  /// sekumpulan outlet yang sedang tampil.
  Future<http.Response> saveProofAccessOutlets(
      List<Map<String, dynamic>> items) {
    return _client
        .post("/gold-gym/v2/sales?type=saveproofoutlets", {"items": items});
  }

  /// ADMIN: daftar user (penjual retail/therapy & pembeli) + status
  /// aktif/nonaktif fitur bukti pembayaran. name mencocokkan nama ATAU email.
  Future<http.Response> getProofAccessUsers(String name) {
    final params = {"type": "proofusers"};
    if (name.isNotEmpty) params["name"] = name;
    return _client.get("/gold-gym/v2/sales", queryParams: params);
  }

  /// ADMIN: simpan status aktif/nonaktif fitur bukti pembayaran untuk
  /// sekumpulan user yang sedang tampil.
  Future<http.Response> saveProofAccessUsers(
      List<Map<String, dynamic>> items) {
    return _client
        .post("/gold-gym/v2/sales?type=saveproofusers", {"items": items});
  }

  Future<http.Response> getAllSales(
      String name, String outcode, int page, int length) {
    final queryParams = {
      "type": "getallsales",
      "code": outcode,
      "page": page.toString(),
      "length": length.toString(),
    };
    if (name.isNotEmpty) {
      queryParams["name"] = name;
    }
    return _client.get("/gold-gym/v2/sales", queryParams: queryParams);
  }

  /// Laporan penjualan penjual: mode = day/week/month, date = YYYY-MM-DD
  /// (untuk month boleh YYYY-MM). Scope outlet aktif (outcode).
  Future<http.Response> getSalesReport(
      String mode, String date, String outcode) {
    return _client.get("/gold-gym/v2/sales", queryParams: {
      "type": "salesreport",
      "mode": mode,
      "date": date,
      "code": outcode,
    });
  }

  Future<http.Response> getSaleDetail(String saleId) {
    return _client.get("/gold-gym/v2/sales", queryParams: {
      "type": "getsaledetail",
      "saleid": saleId,
    });
  }

  /// Admin/penjual menandai transaksi BELUM LUNAS menjadi LUNAS.
  Future<http.Response> markPaid(String saleId) {
    return _client.put(
        "/gold-gym/v2/sales?type=markpaid&saleid=$saleId", {});
  }

  /// Ambil nota PDF dari backend. Return null jika belum tersedia/gagal.
  Future<Uint8List?> getReceiptPdf(String saleId) async {
    final response = await _client.get("/gold-gym/v2/sales", queryParams: {
      "type": "receipt",
      "saleid": saleId,
    });
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }

  /// Insert sales async lewat Kafka: nota mungkin belum ada sesaat setelah
  /// simpan, jadi coba beberapa kali sebelum menyerah.
  Future<Uint8List?> getReceiptPdfWithRetry(String saleId,
      {int maxRetry = 6}) async {
    for (var i = 0; i < maxRetry; i++) {
      final bytes = await getReceiptPdf(saleId);
      if (bytes != null) return bytes;
      await Future.delayed(const Duration(seconds: 1));
    }
    return null;
  }
}
