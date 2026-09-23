import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Akun staff (dibawahi owner/SELLER) & absensi -- endpoint /gold-gym/v2/staff.
class StaffApi extends ApiClient {
  final ApiClient _client = ApiClient();

  // ---- Owner (SELLER) ----

  Future<http.Response> register({
    required String nama,
    required String email,
    required String password,
    required String nomorHp,
  }) {
    return _client.post("/gold-gym/v2/staff?type=register", {
      "gold_nama": nama,
      "gold_email": email,
      "gold_password": password,
      "gold_nomorhp": nomorHp,
    });
  }

  Future<http.Response> list() {
    return _client.get("/gold-gym/v2/staff", queryParams: {"type": "list"});
  }

  Future<http.Response> getMenuAccess(int staffGoldId) {
    return _client.get("/gold-gym/v2/staff", queryParams: {
      "type": "menuaccess",
      "staff_gold_id": staffGoldId.toString(),
    });
  }

  Future<http.Response> setMenuAccess(int staffGoldId, List<String> deniedKeys) {
    return _client.put("/gold-gym/v2/staff?type=menuaccess", {
      "staff_gold_id": staffGoldId,
      "denied_menu_keys": deniedKeys,
    });
  }

  Future<http.Response> getAttendance(int staffGoldId, String month) {
    return _client.get("/gold-gym/v2/staff", queryParams: {
      "type": "attendance",
      "staff_gold_id": staffGoldId.toString(),
      "month": month,
    });
  }

  Future<http.Response> getWorkHours() {
    return _client
        .get("/gold-gym/v2/staff", queryParams: {"type": "workhours"});
  }

  Future<http.Response> setWorkHours(int hours) {
    return _client.put("/gold-gym/v2/staff?type=workhours", {"hours": hours});
  }

  // ---- Staff (self-service) ----

  Future<http.Response> myDeniedMenus() {
    return _client
        .get("/gold-gym/v2/staff", queryParams: {"type": "mydeniedmenus"});
  }

  Future<http.Response> clockIn() {
    return _client.post("/gold-gym/v2/staff?type=clockin", {});
  }

  Future<http.Response> clockOut() {
    return _client.post("/gold-gym/v2/staff?type=clockout", {});
  }

  Future<http.Response> today() {
    return _client.get("/gold-gym/v2/staff", queryParams: {"type": "today"});
  }
}
