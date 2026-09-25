/// Satu baris foto milik user di menu Storage -- bisa berasal dari foto item
/// katalog atau bukti pembayaran transaksi POS, disatukan lewat sourceType.
class StorageEntry {
  static const String sourceItemPhoto = 'ITEM_PHOTO';
  static const String sourcePaymentProof = 'PAYMENT_PROOF';
  static const String sourceQrisPhoto = 'QRIS_PHOTO';

  final String sourceType;
  final int sourceId;
  final String label;
  final String contextText;
  final int sizeKb;
  final DateTime? uploadedAt;

  StorageEntry({
    required this.sourceType,
    required this.sourceId,
    required this.label,
    required this.contextText,
    required this.sizeKb,
    required this.uploadedAt,
  });

  factory StorageEntry.fromJson(Map<String, dynamic> json) {
    return StorageEntry(
      sourceType: json['source_type'] ?? '',
      sourceId: json['source_id'] ?? 0,
      label: json['label'] ?? '',
      contextText: json['context_text'] ?? '',
      sizeKb: json['size_kb'] ?? 0,
      uploadedAt: json['uploaded_at'] == null
          ? null
          : DateTime.tryParse(json['uploaded_at']),
    );
  }
}

/// Ringkasan pemakaian + daftar foto milik satu user (menu Storage).
class StorageSummary {
  /// Kuota total bukti bayar + QRIS.
  final int usedKb;
  final int quotaKb;

  /// Foto PRODUK: dicatat terpisah, tidak ikut kuota di atas; itemQuotaKb 0 = tanpa batas.
  final int itemUsedKb;
  final int itemQuotaKb;
  final int itemMaxKb;
  final int proofMaxKb;

  /// Fitur foto bukti bayar/QRIS aktif untuk user ini (diatur admin).
  final bool proofEnabled;
  final List<StorageEntry> entries;

  StorageSummary({
    required this.usedKb,
    required this.quotaKb,
    this.itemUsedKb = 0,
    this.itemQuotaKb = 0,
    this.itemMaxKb = 0,
    this.proofMaxKb = 0,
    this.proofEnabled = true,
    required this.entries,
  });

  double get usedMb => usedKb / 1024;
  double get quotaMb => quotaKb / 1024;
  double get usedFraction => quotaKb <= 0 ? 0 : (usedKb / quotaKb).clamp(0, 1);

  factory StorageSummary.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return StorageSummary(
      usedKb: data['used_kb'] ?? 0,
      quotaKb: data['quota_kb'] ?? 0,
      itemUsedKb: data['item_used_kb'] ?? 0,
      itemQuotaKb: data['item_quota_kb'] ?? 0,
      itemMaxKb: data['item_max_kb'] ?? 0,
      proofMaxKb: data['proof_max_kb'] ?? 0,
      proofEnabled: data['proof_enabled'] != false,
      entries: ((data['entries'] as List?) ?? [])
          .map((e) => StorageEntry.fromJson(e))
          .toList(),
    );
  }
}

/// Admin: satu baris di GET /v1/storage/admin/users (padanan AdminUserUsage
/// di Next.js).
class AdminUserUsage {
  final int goldId;
  final String plan;

  /// Foto produk (dicatat terpisah dari kuota bukti bayar/QRIS).
  final double itemStorageGb;
  final double itemQuotaMb; // 0 = tanpa batas
  final double itemMaxMb;
  final double proofMaxMb;
  final double uploadGb;
  final double downloadGb;
  final double storageGb;
  final double effectiveLimitGb;
  final bool hasOverride;

  AdminUserUsage({
    required this.goldId,
    this.plan = '',
    this.itemStorageGb = 0,
    this.itemQuotaMb = 0,
    this.itemMaxMb = 0,
    this.proofMaxMb = 0,
    required this.uploadGb,
    required this.downloadGb,
    required this.storageGb,
    required this.effectiveLimitGb,
    required this.hasOverride,
  });

  factory AdminUserUsage.fromJson(Map<String, dynamic> j) => AdminUserUsage(
        goldId: (j['gold_id'] ?? 0) as int,
        plan: (j['plan'] ?? '').toString(),
        itemStorageGb: (j['item_storage_gb'] ?? 0).toDouble(),
        itemQuotaMb: (j['item_quota_mb'] ?? 0).toDouble(),
        itemMaxMb: (j['item_max_mb'] ?? 0).toDouble(),
        proofMaxMb: (j['proof_max_mb'] ?? 0).toDouble(),
        uploadGb: (j['upload_gb'] ?? 0).toDouble(),
        downloadGb: (j['download_gb'] ?? 0).toDouble(),
        storageGb: (j['storage_gb'] ?? 0).toDouble(),
        effectiveLimitGb: (j['effective_limit_gb'] ?? 0).toDouble(),
        hasOverride: j['has_override'] == true,
      );
}

/// Admin: rollup per environment, GET /v1/storage/admin/usage-summary.
class AdminUsageSummary {
  final String environment;
  final double uploadGb;
  final double downloadGb;
  final double storageGb;
  final int alertGb;
  final int limitGb;
  final bool alerted;

  AdminUsageSummary({
    required this.environment,
    required this.uploadGb,
    required this.downloadGb,
    required this.storageGb,
    required this.alertGb,
    required this.limitGb,
    required this.alerted,
  });

  factory AdminUsageSummary.fromJson(Map<String, dynamic> j) =>
      AdminUsageSummary(
        environment: j['environment'] ?? '',
        uploadGb: (j['upload_gb'] ?? 0).toDouble(),
        downloadGb: (j['download_gb'] ?? 0).toDouble(),
        storageGb: (j['storage_gb'] ?? 0).toDouble(),
        alertGb: (j['alert_gb'] ?? 0) as int,
        limitGb: (j['limit_gb'] ?? 0) as int,
        alerted: j['alerted'] == true,
      );
}

/// Admin: satu aturan batas foto (GET /v2/storage/admin/limits). Cakupan GLOBAL | PLAN | USER,
/// jenis ITEM_MAX_KB | PROOF_MAX_KB | ITEM_QUOTA_KB | PROOF_QUOTA_KB.
class LimitRule {
  final String scopeType;
  final String scopeKey;
  final String kind;
  final int limitKb;

  LimitRule({
    required this.scopeType,
    required this.scopeKey,
    required this.kind,
    required this.limitKb,
  });

  factory LimitRule.fromJson(Map<String, dynamic> j) => LimitRule(
        scopeType: (j['scope_type'] ?? '').toString(),
        scopeKey: (j['scope_key'] ?? '').toString(),
        kind: (j['kind'] ?? '').toString(),
        limitKb: (j['limit_kb'] ?? 0) as int,
      );
}
