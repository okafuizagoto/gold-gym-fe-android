import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Hapus akun. Padanan services/account.ts (Next.js).
class AccountApi extends ApiClient {
  final ApiClient _c = ApiClient();

  /// POST /gold-gym/v2/userdata/account/delete -- anonimisasi akun sendiri.
  Future<http.Response> deleteAccount(String password, {String? totpCode}) =>
      _c.post('/gold-gym/v2/userdata/account/delete', {
        'password': password,
        'confirm': 'HAPUS',
        if (totpCode != null && totpCode.isNotEmpty) 'totp_code': totpCode,
      });
}
