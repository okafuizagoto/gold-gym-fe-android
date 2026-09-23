import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Langganan (paket) -- backend goldgym: /v1/goldgym/{plans,subscription}
/// (nginx memetakan /gold-gym/v2/userdata/* ke /v1/goldgym/*).
class SubscriptionApi extends ApiClient {
  final ApiClient _client = ApiClient();

  /// GET /plans: katalog paket (harga, batas, fitur).
  Future<http.Response> getPlans() {
    return _client.get('/gold-gym/v2/userdata/plans');
  }

  /// GET /subscription: langganan pemilik (staff melihat langganan pemiliknya).
  Future<http.Response> getMine() {
    return _client.get('/gold-gym/v2/userdata/subscription');
  }

  /// PATCH /admin/pricing-ui (ADMIN): hide/unhide baris Marketplace/Booking di matriks Langganan.
  /// Murni tampilan -- tidak mempengaruhi akses fitur sungguhan.
  Future<http.Response> adminSetPricingUI(Map<String, dynamic> body) {
    return _client.patch('/gold-gym/v2/userdata/admin/pricing-ui', body);
  }
}
