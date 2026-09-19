import 'package:http/http.dart' as http;
import 'api_client.dart';

/// API tabel customer (/v2/cust) — dipakai POS sebagai salah satu sumber nama customer.
class CustomerApi extends ApiClient {
  final ApiClient _client = ApiClient();

  /// Daftar customer milik outlet penjual login (name opsional untuk cari).
  Future<http.Response> getAllCustomer(String name, String outcode) {
    final params = {
      "type": "getallcustomer",
      "code": outcode,
      "page": "0",
      "length": "0",
    };
    if (name.isNotEmpty) params["name"] = name;
    return _client.get("/gold-gym/v2/cust", queryParams: params);
  }

  /// Insert customer (sinkron) — 1 atau beberapa customer sekaligus.
  Future<http.Response> insertCustomer(List<Map<String, dynamic>> customers) {
    return _client
        .post("/gold-gym/v2/cust?type=insertcustomer", {"data": customers});
  }

  /// Insert massal (bulk) via Kafka — request langsung balas 202, insert async.
  Future<http.Response> bulkInsertCustomer(List<Map<String, dynamic>> customers) {
    return _client
        .post("/gold-gym/v2/cust?type=bulkinsertcustomer", {"data": customers});
  }
}
