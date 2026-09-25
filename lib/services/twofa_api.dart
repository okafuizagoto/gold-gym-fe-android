import 'package:http/http.dart' as http;
import 'api_client.dart';

/// 2FA TOTP. Padanan services/twofa.ts (Next.js).
class TwoFaApi extends ApiClient {
  static const _base = '/gold-gym/v2/userdata/2fa';
  final ApiClient _c = ApiClient();

  Future<http.Response> status() => _c.get('$_base/status');
  Future<http.Response> setup() => _c.post('$_base/setup', {});
  Future<http.Response> enable(String code) =>
      _c.post('$_base/enable', {'code': code});
  Future<http.Response> disable(String code) =>
      _c.post('$_base/disable', {'code': code});
  Future<http.Response> setAdminRequired(bool required) =>
      _c.put('$_base/admin-required', {'required': required});
}
