import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Daftar akun + ban/buka ban (ADMIN). Padanan services/accountAdmin.ts (Next.js).
class AccountAdminApi extends ApiClient {
  final ApiClient _c = ApiClient();

  /// GET /gold-gym/v2/userdata/admin/accounts -- status: all | active | banned.
  Future<http.Response> list(String q, String status, int limit, int offset) =>
      _c.get('/gold-gym/v2/userdata/admin/accounts'
          '?q=${Uri.encodeQueryComponent(q)}&status=$status&limit=$limit&offset=$offset');

  /// PUT /gold-gym/v2/userdata/admin/accounts/:id/status -- active=false: ban, true: buka ban.
  Future<http.Response> setActive(int id, bool active) => _c.put(
      '/gold-gym/v2/userdata/admin/accounts/$id/status', {'active': active});
}
