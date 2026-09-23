import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../models/feature_request_model.dart';
import 'dart:convert';

/// Padanan services/featureRequest.ts. Endpoint di modul featurerequest
/// (gold-gym-be-v2) -- suggestion box privat (admin-only listing), lihat
/// dokumentasi backend-nya untuk desain kategori/tipe.
class FeatureRequestApi extends ApiClient {
  final ApiClient _client = ApiClient();

  /// POST /gold-gym/v2/featurerequest -- kirim request baru. `menu` cuma
  /// dipakai/divalidasi backend kalau `type` == PERBAIKAN. `outcode` cuma
  /// relevan untuk role SELLER (resolve kategori penjual retail/therapy).
  Future<http.Response> create({
    required String type,
    String? menu,
    required String title,
    required String description,
    String? outcode,
  }) {
    return _client.post('/gold-gym/v2/featurerequest', {
      'type': type,
      if (menu != null && menu.isNotEmpty) 'menu': menu,
      'title': title,
      'description': description,
      if (outcode != null && outcode.isNotEmpty) 'outcode': outcode,
    });
  }

  /// GET /gold-gym/v2/featurerequest/mine -- request milik akun sendiri.
  Future<List<FeatureRequest>?> listMine() async {
    final response = await _client.get('/gold-gym/v2/featurerequest/mine');
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = (body['data'] as List?) ?? [];
    return rows.map((e) => FeatureRequest.fromJson(e)).toList();
  }

  /// GET /gold-gym/v2/featurerequest/admin -- ADMIN only, semua request.
  /// Filter opsional; kosong/null berarti "semua".
  ///
  /// KOREKSI 2026-09-18 (QA audit #1.4): dulu return `null` utk SEMUA
  /// status non-200 (403 maupun 500), layar tidak bisa membedakan "khusus
  /// admin" dari error server. Sekarang melempar [ForbiddenException]
  /// khusus 403, [Exception] (pesan backend) utk error lain.
  Future<List<FeatureRequest>> adminListAll({
    String? category,
    String? status,
    String? type,
  }) async {
    final query = <String, String>{
      if (category != null && category.isNotEmpty) 'category': category,
      if (status != null && status.isNotEmpty) 'status': status,
      if (type != null && type.isNotEmpty) 'type': type,
    };
    final response = await _client.get(
      '/gold-gym/v2/featurerequest/admin',
      queryParams: query.isEmpty ? null : query,
    );
    throwOnErrorStatus(response, 'Gagal memuat daftar request fitur');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = (body['data'] as List?) ?? [];
    return rows.map((e) => FeatureRequest.fromJson(e)).toList();
  }

  /// PATCH /gold-gym/v2/featurerequest/admin/:id/status -- ADMIN only.
  Future<http.Response> adminUpdateStatus(int requestId, String status) {
    return _client.patch(
      '/gold-gym/v2/featurerequest/admin/$requestId/status',
      {'status': status},
    );
  }

  /// GET /gold-gym/v2/featurerequest/enabled -- apakah menu "Request Aplikasi Baru" ditampilkan
  /// ke user. Gagal/tidak login -> default true (fail-open, sama pola dengan hasFeature di
  /// utils/subscription_state.dart).
  Future<bool> getEnabled() async {
    try {
      final response = await _client.get('/gold-gym/v2/featurerequest/enabled');
      if (response.statusCode != 200) return true;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['data']?['enabled']) != false;
    } catch (_) {
      return true;
    }
  }

  /// PATCH /gold-gym/v2/featurerequest/admin/enabled -- ADMIN hide/unhide menu untuk semua user.
  Future<http.Response> adminSetEnabled(bool enabled) {
    return _client.patch(
      '/gold-gym/v2/featurerequest/admin/enabled',
      {'enabled': enabled},
    );
  }
}
