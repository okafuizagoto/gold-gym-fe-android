import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Statistik pemakaian (ADMIN). Padanan services/usageStats.ts (Next.js).
class UsageStatsApi extends ApiClient {
  final ApiClient _c = ApiClient();

  Future<http.Response> getReport() =>
      _c.get('/gold-gym/v2/userdata/admin/usage-stats');

  /// GET /gold-gym/v2/userdata/admin/usage-stats/online-now (2026-10-10) -- daftar akun "online
  /// sekarang", untuk tombol "Detail" di kartu Live Sekarang.
  Future<http.Response> getOnlineNowUsers() =>
      _c.get('/gold-gym/v2/userdata/admin/usage-stats/online-now');
}
