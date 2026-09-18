int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

/// Satu baris riwayat backup harian (tabel backup_log) -- padanan
/// models/backup.ts. ADMIN only.
class BackupRecord {
  static const String statusSuccess = 'SUCCESS';
  static const String statusFailed = 'FAILED';

  final int backupId;
  final String environment;
  final String serviceName;
  final int sizeBytes;
  final String status;
  final String errorMessage;
  final DateTime? createdAt;

  BackupRecord({
    required this.backupId,
    required this.environment,
    required this.serviceName,
    required this.sizeBytes,
    required this.status,
    required this.errorMessage,
    required this.createdAt,
  });

  factory BackupRecord.fromJson(Map<String, dynamic> j) => BackupRecord(
        backupId: _toInt(j['backup_id']),
        environment: j['environment'] ?? '',
        serviceName: j['service_name'] ?? '',
        sizeBytes: _toInt(j['size_bytes']),
        status: j['status'] ?? '',
        errorMessage: j['error_message'] ?? '',
        createdAt: j['created_at'] == null
            ? null
            : DateTime.tryParse(j['created_at']),
      );

  /// "1.2 MB" / "340 KB" / "980 B" -- sama gaya dengan formatting ukuran
  /// storage lain di app ini (mis. StorageSummary.usedMb).
  String get sizeLabel {
    if (sizeBytes >= 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeBytes >= 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$sizeBytes B';
  }
}
