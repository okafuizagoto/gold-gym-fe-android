import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Kontak bantuan + bayar langganan lewat transfer bank (2026-11-18, putaran 4 founder). Padanan web:
/// services/manualPay.ts. Aplikasi Android TIDAK menampilkan instruksi transfer ke penjual (kebijakan Google Play);
/// penjual hanya melihat status permintaan yang dibuat di web. Layar admin sama dengan web.
class ManualPayApi {
  final ApiClient _client = ApiClient();
  static const _p = '/gold-gym/v2/userdata';

  /// GET /public/contact (tanpa login)
  Future<http.Response> contact() => _client.get('$_p/public/contact');

  /// PUT /admin/contact (ADMIN)
  Future<http.Response> setContact(Map<String, dynamic> body) => _client.put('$_p/admin/contact', body);

  /// GET/PUT /admin/manual-payment/settings (ADMIN): rekening tujuan transfer
  Future<http.Response> bank() => _client.get('$_p/admin/manual-payment/settings');
  Future<http.Response> setBank(Map<String, dynamic> body) => _client.put('$_p/admin/manual-payment/settings', body);

  /// GET /admin/manual-payments?status= (ADMIN)
  Future<http.Response> adminList(String status) => _client.get('$_p/admin/manual-payments',
      queryParams: status.isEmpty ? null : {'status': status});
  Future<http.Response> approve(int id, String bankRef, String note) =>
      _client.post('$_p/admin/manual-payments/$id/approve', {'bank_ref': bankRef, 'note': note});
  Future<http.Response> reject(int id, String note) =>
      _client.post('$_p/admin/manual-payments/$id/reject', {'note': note});

  /// Pemilik: permintaan miliknya (rekening tidak ditampilkan di Android)
  Future<http.Response> mine() => _client.get('$_p/subscription/manual-payment');
}
