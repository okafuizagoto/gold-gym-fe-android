import 'package:http/http.dart' as http;
import 'api_client.dart';

class MejaApi extends ApiClient {
  Future<http.Response> getMeja(String outcode) async {
    final ApiClient client = ApiClient();
    return client.get(
      "/gold-gym/v2/meja",
      queryParams: {"type": "listmeja", "outcode": outcode},
    );
  }

  Future<http.Response> insertMeja(Map<String, dynamic> data) async {
    final ApiClient client = ApiClient();
    return client.post(
      "/gold-gym/v2/meja?type=insertmeja",
      data,
    );
  }

  Future<http.Response> reserveMeja(String outcode, List<int> mejaIds) async {
    final ApiClient client = ApiClient();
    return client.put(
      "/gold-gym/v2/meja?type=reservemeja",
      {"outcode": outcode, "meja_ids": mejaIds},
    );
  }

  Future<http.Response> releaseMeja(String outcode, List<int> mejaIds) async {
    final ApiClient client = ApiClient();
    return client.put(
      "/gold-gym/v2/meja?type=releasemeja",
      {"outcode": outcode, "meja_ids": mejaIds},
    );
  }

  // 2026-10-16, submenu Kelola Meja: edit nama/kapasitas/area & hapus meja.
  Future<http.Response> updateMeja(String outcode, int mejaId, String mejaName,
      int mejaCapacity, int mejaAreaId) async {
    final ApiClient client = ApiClient();
    return client.put(
      "/gold-gym/v2/meja?type=updatemeja",
      {
        "outcode": outcode,
        "meja_id": mejaId,
        "meja_name": mejaName,
        "meja_capacity": mejaCapacity,
        "meja_area_id": mejaAreaId,
      },
    );
  }

  Future<http.Response> deleteMeja(String outcode, int mejaId) async {
    final ApiClient client = ApiClient();
    return client.delete(
      "/gold-gym/v2/meja",
      queryParams: {"outcode": outcode, "meja_id": mejaId.toString()},
    );
  }
}
