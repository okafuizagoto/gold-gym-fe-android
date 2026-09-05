import 'package:http/http.dart' as http;
import 'api_client.dart';

/// ADMIN: aktif/nonaktifkan menu "Daftar Pembeli" & "Mode Pembeli" milik
/// akun penjual (retail & therapy) — endpoint /gold-gym/v2/selleraccess.
class SellerAccessApi extends ApiClient {
  final ApiClient _client = ApiClient();

  /// Daftar outlet + status 2 menu milik penjual pemiliknya.
  /// name (opsional) cari berdasarkan nama outlet ATAU nama penjual.
  Future<http.Response> getList(String name) {
    final params = {"type": "list"};
    if (name.isNotEmpty) params["name"] = name;
    return _client.get("/gold-gym/v2/selleraccess", queryParams: params);
  }

  Future<http.Response> setDaftarPembeli(int goldId, bool active) {
    return _client.put("/gold-gym/v2/selleraccess?type=daftarpembeli",
        {"gold_id": goldId, "active": active});
  }

  Future<http.Response> setModePembeli(int goldId, bool active) {
    return _client.put("/gold-gym/v2/selleraccess?type=modepembeli",
        {"gold_id": goldId, "active": active});
  }
}
