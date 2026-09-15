import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/item_model.dart';
import 'api_client.dart';
import 'dart:convert';

class ItemsApi extends ApiClient {
  Future<http.Response> insertItems(Map<String, dynamic> data) async {
    final ApiClient client = ApiClient();
    return client.post(
      "/gold-gym/v2/items?type=insertitems",
      data,
    );
  }

  // GET /gold-gym/v2/userdata?type=getonestock&stockcode=XXX
  Future<http.Response> getAllItems(
      String name, String outcode, int page, int length) async {
    final ApiClient client = ApiClient();
    final queryParams = {
      "type": "getallitems",
      "code": outcode,
      "page": page.toString(),
      "length": length.toString(),
    };

    if (name.isNotEmpty) {
      queryParams["name"] = name;
    }
    return client.get("/gold-gym/v2/items", queryParams: queryParams);
  }

  Future<http.Response> updateItems(Map<String, dynamic> data) async {
    final ApiClient client = ApiClient();
    return client.put(
      "/gold-gym/v2/items?type=updateitems",
      data,
    );
  }

  Future<http.Response> deleteItems(int id, String outcode) async {
    final ApiClient client = ApiClient();
    return client.delete(
      "/gold-gym/v2/items?type=deleteitems&id=$id&code=$outcode",
    );
  }

  /// Ambil bytes foto item (untuk ditampilkan di Daftar Barang / POS).
  /// 2026-09-16: backend sekarang simpan foto di Backblaze B2 (bukan disk
  /// lokal) dan endpoint ini balikin JSON {url: presignedUrl} (berlaku 15
  /// menit), bukan bytes langsung -- jadi diambil 2 langkah: (1) minta
  /// presigned URL dari backend (butuh token), (2) fetch bytes dari URL itu
  /// langsung (B2, TIDAK butuh header auth -- presigned URL sudah jadi
  /// satu-satunya akses yang diperlukan).
  Future<Uint8List?> getItemPhoto(int itemId) async {
    final url = await itemPhotoUrl(itemId);
    if (url == null) return null;
    final response = await http.get(Uri.parse(url)).timeout(ApiClient.timeout);
    if (response.statusCode == 200) return response.bodyBytes;
    return null;
  }

  /// Presigned URL (B2, berlaku 15 menit) foto item -- dipakai
  /// FutureNetworkImage (bukan Image.network langsung, URL-nya perlu
  /// ditanya dulu ke backend, tidak bisa dibentuk sinkron seperti dulu).
  Future<String?> itemPhotoUrl(int itemId) async {
    final client = ApiClient();
    final response = await client.get(
      '/gold-gym/v2/items',
      queryParams: {'type': 'itemphoto', 'id': itemId.toString()},
    );
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['url'] as String?;
  }

  /// Upload foto item (multipart, maks 2 MB, divalidasi juga di backend).
  Future<http.Response> uploadItemPhoto(int itemId, File file) async {
    final headers = await getAuthHeaders();
    final uri = Uri.parse(
        '${ApiClient.baseUrl}/gold-gym/v2/items?type=uploadphoto&item_id=$itemId');
    final request = http.MultipartRequest('POST', uri);
    if (headers['Authorization'] != null) {
      request.headers['Authorization'] = headers['Authorization']!;
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send().timeout(ApiClient.timeout);
    return http.Response.fromStream(streamed);
  }

  // GET /gold-gym/v2/userdata?type=getallstock
  Future<http.Response> getAllStockHeader() async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('${ApiClient.baseUrl}/gold-gym/v2/userdata').replace(
      queryParameters: {'type': 'getallstock'},
    );

    return await http.get(url, headers: headers).timeout(ApiClient.timeout);
  }
}
