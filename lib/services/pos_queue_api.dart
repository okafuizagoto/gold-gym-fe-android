import 'package:http/http.dart' as http;
import 'api_client.dart';

// Padanan backend internal/delivery/http/posqueue.
class PosQueueApi extends ApiClient {
  Future<http.Response> list(String outcode, {String? status}) async {
    final client = ApiClient();
    final queryParams = {"outcode": outcode};
    if (status != null && status.isNotEmpty) queryParams["status"] = status;
    return client.get("/gold-gym/v2/pos-queue", queryParams: queryParams);
  }

  Future<http.Response> mine() async {
    final client = ApiClient();
    return client.get("/gold-gym/v2/pos-queue/mine");
  }

  Future<http.Response> advance(int id) async {
    final client = ApiClient();
    return client.put("/gold-gym/v2/pos-queue/$id/advance", {});
  }
}
