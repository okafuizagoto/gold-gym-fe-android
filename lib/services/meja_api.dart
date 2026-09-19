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
}
