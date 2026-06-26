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

  // GET /gold-gym/v2/userdata?type=getallstock
  Future<http.Response> getAllStockHeader() async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('${ApiClient.baseUrl}/gold-gym/v2/userdata').replace(
      queryParameters: {'type': 'getallstock'},
    );

    return await http.get(url, headers: headers).timeout(ApiClient.timeout);
  }
}
