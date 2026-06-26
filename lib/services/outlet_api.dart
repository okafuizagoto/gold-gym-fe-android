import 'package:http/http.dart' as http;
import '../models/outlet_model.dart';
import 'api_client.dart';
import 'dart:convert';

class OutletsApi extends ApiClient {
  Future<http.Response> insertOutlet(Map<String, dynamic> data) async {
    final ApiClient client = ApiClient();
    print("data: $data");
    return client.post(
      "/gold-gym/v2/outlet?type=insertoutlet",
      data,
    );
  }

  Future<http.Response> getAllOutlet(String name, String status, int page, int length) async {
    final ApiClient client = ApiClient();
    final queryParams = {
      "type": "getalloutlet",
      "page": page.toString(),
      "length": length.toString(),
    };

    if (name.isNotEmpty) {
      queryParams["name"] = name;
    }
    if (status.isNotEmpty) {
      queryParams["status"] = status;
    }
    return client.get("/gold-gym/v2/outlet", queryParams: queryParams);
  }

    Future<http.Response> updateOutlets(Map<String, dynamic> data) async {
    final ApiClient client = ApiClient();
    return client.put(
      "/gold-gym/v2/outlet?type=updateoutlet",
      data,
    );
  }

  // // GET /gold-gym/v2/userdata?type=getonestock&stockcode=XXX
  // Future<http.Response> getAllItems(
  //     String name, int page, int length) async {
  //   final ApiClient client = ApiClient();
  //   final queryParams = {
  //   "type": "getallitems",
  //   "page": page.toString(),
  //   "length": length.toString(),
  // };

  // if (name.isNotEmpty) {
  //   queryParams["name"] = name;
  // }
  //   return client.get(
  //     "/gold-gym/v2/items",
  //     queryParams: queryParams
  //   );
  // }

  // Future<http.Response> updateItems(Map<String, dynamic> data) async {
  //   final ApiClient client = ApiClient();
  //   return client.put(
  //     "/gold-gym/v2/items?type=updateitems",
  //     data,
  //   );
  // }

  // Future<http.Response> deleteItems(int id) async {
  //   final ApiClient client = ApiClient();
  //   return client.delete(
  //     "/gold-gym/v2/items?type=deleteitems&id=$id",
  //   );
  // }

  // // GET /gold-gym/v2/userdata?type=getallstock
  // Future<http.Response> getAllStockHeader() async {
  //   final headers = await getAuthHeaders();
  //   final url = Uri.parse('${ApiClient.baseUrl}/gold-gym/v2/userdata').replace(
  //     queryParameters: {'type': 'getallstock'},
  //   );

  //   return await http.get(url, headers: headers).timeout(ApiClient.timeout);
  // }
}
