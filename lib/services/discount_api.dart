import 'package:http/http.dart' as http;
import 'api_client.dart';

class DiscountApi extends ApiClient {
  Future<http.Response> getItemsForOutlet(String outcode, String name) async {
    final ApiClient client = ApiClient();
    final queryParams = {"type": "getitemsforoutlet", "code": outcode};
    if (name.isNotEmpty) {
      queryParams["name"] = name;
    }
    return client.get("/gold-gym/v2/discount", queryParams: queryParams);
  }

  Future<http.Response> getDiscounts(
      String outcode, String name, int page, int length) async {
    final ApiClient client = ApiClient();
    final queryParams = {
      "type": "getdiscounts",
      "code": outcode,
      "page": page.toString(),
      "length": length.toString(),
    };
    if (name.isNotEmpty) {
      queryParams["name"] = name;
    }
    return client.get("/gold-gym/v2/discount", queryParams: queryParams);
  }

  Future<http.Response> getActiveByOutlet(String outcode) async {
    final ApiClient client = ApiClient();
    return client.get("/gold-gym/v2/discount",
        queryParams: {"type": "getactivebyoutlet", "code": outcode});
  }

  Future<http.Response> insertDiscounts(Map<String, dynamic> data) async {
    final ApiClient client = ApiClient();
    return client.post("/gold-gym/v2/discount?type=insertdiscount", data);
  }

  Future<http.Response> updateDiscount(Map<String, dynamic> data) async {
    final ApiClient client = ApiClient();
    return client.put("/gold-gym/v2/discount?type=updatediscount", data);
  }

  Future<http.Response> deleteDiscount(int discountId, String outcode) async {
    final ApiClient client = ApiClient();
    return client.delete(
      "/gold-gym/v2/discount?type=deletediscount&discountid=$discountId&code=$outcode",
    );
  }

  Future<http.Response> getHistory(int discountId, int page, int length) async {
    final ApiClient client = ApiClient();
    return client.get("/gold-gym/v2/discount", queryParams: {
      "type": "gethistory",
      "discountid": discountId.toString(),
      "page": page.toString(),
      "length": length.toString(),
    });
  }

  // ---------------------------------------------------------------------
  // Voucher

  /// Pratinjau voucher (TIDAK mengonsumsi) -- dipakai POS sebelum kasir
  /// input jumlah bayar, supaya potongannya kelihatan dulu.
  Future<http.Response> checkVoucher(String outcode, String code) async {
    final ApiClient client = ApiClient();
    return client.get("/gold-gym/v2/discount", queryParams: {
      "type": "checkvoucher",
      "code": outcode,
      "voucher": code,
    });
  }

  Future<http.Response> generateVoucherCode(String outcode) async {
    final ApiClient client = ApiClient();
    return client.get("/gold-gym/v2/discount",
        queryParams: {"type": "generatevouchercode", "code": outcode});
  }

  Future<http.Response> insertVoucher(Map<String, dynamic> data) async {
    final ApiClient client = ApiClient();
    return client.post("/gold-gym/v2/discount?type=insertvoucher", data);
  }

  Future<http.Response> getVouchers(String outcode, int page, int length) async {
    final ApiClient client = ApiClient();
    return client.get("/gold-gym/v2/discount", queryParams: {
      "type": "getvouchers",
      "code": outcode,
      "page": page.toString(),
      "length": length.toString(),
    });
  }

  Future<http.Response> deleteVoucher(int voucherId, String outcode) async {
    final ApiClient client = ApiClient();
    return client.delete(
      "/gold-gym/v2/discount?type=deletevoucher&voucherid=$voucherId&code=$outcode",
    );
  }

  Future<http.Response> getVoucherHistory(
      String outcode, int page, int length) async {
    final ApiClient client = ApiClient();
    return client.get("/gold-gym/v2/discount", queryParams: {
      "type": "getvoucherhistory",
      "code": outcode,
      "page": page.toString(),
      "length": length.toString(),
    });
  }
}
