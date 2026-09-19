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
}
