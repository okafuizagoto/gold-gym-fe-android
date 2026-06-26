import 'package:http/http.dart' as http;
import 'api_client.dart';

class StockApi extends ApiClient {
  Future<http.Response> insertStock(Map<String, dynamic> data) async {
    final ApiClient client = ApiClient();
    return client.post(
      "/gold-gym/v2/stock?type=insertstocknew",
      data,
    );
  }

  // GET /gold-gym/v2/userdata?type=getonestock&stockcode=XXX
  Future<http.Response> getOneStock(String stockId, String stockCode) async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('${ApiClient.baseUrl}/gold-gym/v2/userdata').replace(
      queryParameters: {
        'type': 'getonestock',
        'stockid': stockId,
        'stockcode': stockCode,
        'stockname': '',
      },
    );

    return await http.get(url, headers: headers).timeout(ApiClient.timeout);
  }

  // GET /gold-gym/v2/userdata?type=getallstock
  Future<http.Response> getAllStockHeader() async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('${ApiClient.baseUrl}/gold-gym/v2/userdata').replace(
      queryParameters: {'type': 'getallstock'},
    );

    return await http.get(url, headers: headers).timeout(ApiClient.timeout);
  }

  Future<http.Response> getStockByName(String name) async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('${ApiClient.baseUrl}/gold-gym/v2/stock').replace(
      queryParameters: {
        'type': 'getstockbyname',
        'stockname': name,
      },
    );

    return await http.get(url, headers: headers).timeout(ApiClient.timeout);
  }

  Future<http.Response> getAllStock(
      String name, String outcode, int page, int length) async {
    final ApiClient client = ApiClient();
    final queryParams = {
      "type": "getallstock",
      "code": outcode,
      "page": page.toString(),
      "length": length.toString(),
    };

    if (name.isNotEmpty) {
      queryParams["name"] = name;
    }
    return client.get("/gold-gym/v2/stock", queryParams: queryParams);
  }
}
