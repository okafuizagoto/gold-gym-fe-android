import 'package:http/http.dart' as http;
import 'api_client.dart';

class AreaApi extends ApiClient {
  Future<http.Response> getAreas(String outcode) async {
    final ApiClient client = ApiClient();
    return client.get(
      "/gold-gym/v2/area",
      queryParams: {"type": "listarea", "outcode": outcode},
    );
  }

  Future<http.Response> insertArea(Map<String, dynamic> data) async {
    final ApiClient client = ApiClient();
    return client.post(
      "/gold-gym/v2/area?type=insertarea",
      data,
    );
  }

  // 2026-10-16, submenu Kelola Meja & Area: edit nama/tipe & hapus area.
  Future<http.Response> updateArea(
      String outcode, int areaId, String areaName, String areaType) async {
    final ApiClient client = ApiClient();
    return client.put(
      "/gold-gym/v2/area",
      {
        "outcode": outcode,
        "area_id": areaId,
        "area_name": areaName,
        "area_type": areaType,
      },
    );
  }

  Future<http.Response> deleteArea(String outcode, int areaId) async {
    final ApiClient client = ApiClient();
    return client.delete(
      "/gold-gym/v2/area",
      queryParams: {"outcode": outcode, "area_id": areaId.toString()},
    );
  }
}
