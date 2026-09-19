import 'dart:convert';
import 'api_client.dart';
import '../models/backup_model.dart';

/// Padanan services/backup.ts. Modul backup (gold-gym-be-v2) -- ADMIN-only,
/// riwayat + trigger manual backup harian (mysqldump -> gzip -> B2).
class BackupApi extends ApiClient {
  final ApiClient _client = ApiClient();

  /// POST /gold-gym/v2/backup/run -- trigger backup sekarang.
  ///
  /// KOREKSI 2026-09-18 (mirror dari bug Next.js #2.3): dulu pakai
  /// `ApiClient.timeout` default (10s) utk operasi sinkron berat
  /// (mysqldump+gzip+upload B2) di server -- timeout klien bisa membunuh
  /// proses backup di tengah jalan.
  Future<BackupRecord?> runNow() async {
    final response = await _client.post('/gold-gym/v2/backup/run', {},
        timeoutOverride: const Duration(minutes: 3));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return BackupRecord.fromJson(body['data'] ?? {});
  }

  /// GET /gold-gym/v2/backup -- riwayat, terbaru dulu.
  ///
  /// KOREKSI 2026-09-18 (QA audit #1.1): dulu return `null` untuk SEMUA
  /// status non-200 (403 maupun 500), sehingga layar tidak bisa membedakan
  /// "khusus admin" dari error server biasa. Sekarang melempar
  /// [ForbiddenException] khusus utk 403, [Exception] (pesan dari backend)
  /// utk error lain -- pemanggil WAJIB try/catch.
  Future<List<BackupRecord>> list() async {
    final response = await _client.get('/gold-gym/v2/backup');
    throwOnErrorStatus(response, 'Gagal memuat riwayat backup');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = (body['data'] as List?) ?? [];
    return rows.map((e) => BackupRecord.fromJson(e)).toList();
  }

  /// GET /gold-gym/v2/backup/:id/download -- presigned URL B2.
  Future<String?> downloadUrl(int backupId) async {
    final response =
        await _client.get('/gold-gym/v2/backup/$backupId/download');
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final url = body['url'];
    return url is String && url.isNotEmpty ? url : null;
  }
}
