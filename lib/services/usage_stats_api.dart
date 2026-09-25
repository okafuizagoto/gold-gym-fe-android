import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Statistik pemakaian (ADMIN). Padanan services/usageStats.ts (Next.js).
class UsageStatsApi extends ApiClient {
  final ApiClient _c = ApiClient();

  Future<http.Response> getReport() =>
      _c.get('/gold-gym/v2/userdata/admin/usage-stats');
}
