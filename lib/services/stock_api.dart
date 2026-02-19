import 'package:http/http.dart' as http;
import 'api_client.dart';

class StockApi extends ApiClient {
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

    return await http
        .get(url, headers: headers)
        .timeout(ApiClient.timeout);
  }

  // GET /gold-gym/v2/userdata?type=getallstock
  Future<http.Response> getAllStockHeader() async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('${ApiClient.baseUrl}/gold-gym/v2/userdata').replace(
      queryParameters: {'type': 'getallstock'},
    );

    return await http
        .get(url, headers: headers)
        .timeout(ApiClient.timeout);
  }
}
