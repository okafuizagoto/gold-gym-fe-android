import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Hapus akun + ganti password. Padanan services/account.ts (Next.js).
class AccountApi extends ApiClient {
  final ApiClient _c = ApiClient();

  /// POST /gold-gym/v2/userdata/account/delete -- anonimisasi akun sendiri.
  Future<http.Response> deleteAccount(String password, {String? totpCode}) =>
      _c.post('/gold-gym/v2/userdata/account/delete', {
        'password': password,
        'confirm': 'HAPUS',
        if (totpCode != null && totpCode.isNotEmpty) 'totp_code': totpCode,
      });

  /// POST /gold-gym/v2/userdata/account/changepassword -- ganti password sendiri (password lama wajib benar).
  Future<http.Response> changePassword(String oldPassword, String newPassword) =>
      _c.post('/gold-gym/v2/userdata/account/changepassword', {
        'old_password': oldPassword,
        'new_password': newPassword,
      });

  /// GET /gold-gym/v2/userdata/account/profile -- nama, email, nomor HP akun sendiri.
  Future<http.Response> getProfile() =>
      _c.get('/gold-gym/v2/userdata/account/profile');

  /// PUT /gold-gym/v2/userdata/account/profile -- ubah nama akun sendiri.
  Future<http.Response> updateProfile(String nama) =>
      _c.put('/gold-gym/v2/userdata/account/profile', {'nama': nama});
}
