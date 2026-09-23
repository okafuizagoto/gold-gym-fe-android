import 'package:http/http.dart' as http;
import 'api_client.dart';

/// API alur pesanan pembeli (BUYER order flow) — endpoint /gold-gym/v2/order.
class OrderApi extends ApiClient {
  final ApiClient _client = ApiClient();

  /// Semua outlet non-THERAPY yang bisa dipilih pembeli.
  Future<http.Response> getOutlets(String name) {
    final params = {"type": "outlets"};
    if (name.isNotEmpty) params["name"] = name;
    return _client.get("/gold-gym/v2/order", queryParams: params);
  }

  /// ADMIN: semua outlet + penanda visible (untuk layar kurasi).
  Future<http.Response> getAllOutletsAdmin(String name) {
    final params = {"type": "alloutlets"};
    if (name.isNotEmpty) params["name"] = name;
    return _client.get("/gold-gym/v2/order", queryParams: params);
  }

  /// ADMIN: tampilkan outlet ke pembeli.
  Future<http.Response> addVisibleOutlet(int goldId, String outcode) {
    return _client.post("/gold-gym/v2/order?type=addvisible",
        {"gold_id": goldId, "outcode": outcode});
  }

  /// ADMIN: sembunyikan outlet dari pembeli.
  Future<http.Response> removeVisibleOutlet(int goldId, String outcode) {
    return _client.delete("/gold-gym/v2/order", queryParams: {
      "type": "removevisible",
      "goldid": goldId.toString(),
      "code": outcode,
    });
  }

  /// Barang satu outlet (goldId + outcode wajib).
  Future<http.Response> getCatalog(int goldId, String outcode, String name) {
    final params = {
      "type": "catalog",
      "goldid": goldId.toString(),
      "code": outcode,
    };
    if (name.isNotEmpty) params["name"] = name;
    return _client.get("/gold-gym/v2/order", queryParams: params);
  }

  /// Buat pesanan baru (checkout pembeli).
  Future<http.Response> insertOrder(Map<String, dynamic> data) {
    return _client.post("/gold-gym/v2/order?type=insertorder", {"data": data});
  }

  /// Daftar pesanan milik pembeli login (dashboard).
  Future<http.Response> getBuyerOrders() {
    return _client
        .get("/gold-gym/v2/order", queryParams: {"type": "buyerorders"});
  }

  /// Daftar pesanan masuk untuk penjual login (status opsional).
  Future<http.Response> getSellerOrders(String status) {
    final params = {"type": "sellerorders"};
    if (status.isNotEmpty) params["status"] = status;
    return _client.get("/gold-gym/v2/order", queryParams: params);
  }

  /// Detail satu pesanan (header + item).
  Future<http.Response> getOrderDetail(String orderId) {
    return _client.get("/gold-gym/v2/order",
        queryParams: {"type": "orderdetail", "orderid": orderId});
  }

  /// Penjual konfirmasi pesanan (WAITING -> PROCESS).
  Future<http.Response> confirmOrder(String orderId) {
    return _client
        .put("/gold-gym/v2/order?type=confirm&orderid=$orderId", {});
  }

  /// Penjual tolak pesanan (WAITING -> REJECT) dengan alasan.
  Future<http.Response> rejectOrder(String orderId, String reason) {
    return _client.put(
        "/gold-gym/v2/order?type=reject&orderid=$orderId", {"reason": reason});
  }

  /// Penjual selesaikan pesanan (PROCESS -> FINISH). Nota dibuat.
  Future<http.Response> finishOrder(String orderId) {
    return _client.put("/gold-gym/v2/order?type=finish&orderid=$orderId", {});
  }
}
