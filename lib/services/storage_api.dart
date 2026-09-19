import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'items_api.dart';
import 'sales_api.dart';
import '../models/storage_model.dart';
import 'dart:convert';

class StorageApi extends ApiClient {
  final ApiClient _client = ApiClient();

  /// Ringkasan pemakaian + daftar foto (item + bukti pembayaran) milik user.
  Future<StorageSummary?> getSummary() async {
    final response = await _client.get('/gold-gym/v2/storage');
    if (response.statusCode != 200) return null;
    return StorageSummary.fromJson(jsonDecode(response.body));
  }

  /// Hapus satu foto (item atau bukti pembayaran) dari menu Storage.
  Future<http.Response> deleteEntry(String sourceType, int sourceId) async {
    final type = sourceType == StorageEntry.sourceItemPhoto
        ? 'item_photo'
        : 'payment_proof';
    return _client.delete(
      '/gold-gym/v2/storage?type=$type&id=$sourceId',
    );
  }

  /// Presigned URL (B2) untuk satu entry -- lihat ItemsApi.itemPhotoUrl /
  /// SalesApi.proofPhotoUrl untuk kenapa ini sekarang async.
  Future<String?> photoUrl(StorageEntry entry) {
    if (entry.sourceType == StorageEntry.sourceItemPhoto) {
      return ItemsApi().itemPhotoUrl(entry.sourceId);
    }
    return SalesApi().proofPhotoUrl(entry.sourceId);
  }

  // --- Admin: penggunaan storage B2 lintas semua user (2026-09-16) ---

  /// GET /v1/storage/admin/users (role=ADMIN).
  Future<List<AdminUserUsage>?> adminListUsers() async {
    final response = await _client.get('/gold-gym/v2/storage/admin/users');
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = (body['data'] as List?) ?? [];
    return rows.map((e) => AdminUserUsage.fromJson(e)).toList();
  }

  /// PATCH /v1/storage/admin/users/:goldId/limit -- limitGb null = hapus override.
  Future<http.Response> adminSetUserLimit(int goldId, double? limitGb) {
    return _client.patch(
      '/gold-gym/v2/storage/admin/users/$goldId/limit',
      {'limit_gb': limitGb},
    );
  }

  /// PATCH /v1/storage/admin/global-limit -- ganti default 30MB semua user.
  Future<http.Response> adminSetGlobalLimit(double limitGb) {
    return _client.patch(
      '/gold-gym/v2/storage/admin/global-limit',
      {'limit_gb': limitGb},
    );
  }

  /// GET /v1/storage/admin/usage-summary.
  Future<List<AdminUsageSummary>?> adminGetUsageSummary() async {
    final response =
        await _client.get('/gold-gym/v2/storage/admin/usage-summary');
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = (body['data'] as List?) ?? [];
    return rows.map((e) => AdminUsageSummary.fromJson(e)).toList();
  }
}
