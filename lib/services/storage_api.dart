import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'items_api.dart';
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

  /// URL foto untuk satu entry, siap dipakai Image.network (+ headers auth).
  String photoUrl(StorageEntry entry) {
    if (entry.sourceType == StorageEntry.sourceItemPhoto) {
      return ItemsApi().itemPhotoUrl(entry.sourceId);
    }
    return '${ApiClient.baseUrl}/gold-gym/v2/sales?type=proofphoto&proofid=${entry.sourceId}';
  }
}
