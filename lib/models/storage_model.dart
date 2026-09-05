/// Satu baris foto milik user di menu Storage -- bisa berasal dari foto item
/// katalog atau bukti pembayaran transaksi POS, disatukan lewat sourceType.
class StorageEntry {
  static const String sourceItemPhoto = 'ITEM_PHOTO';
  static const String sourcePaymentProof = 'PAYMENT_PROOF';

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
  final int usedKb;
  final int quotaKb;
  final List<StorageEntry> entries;

  StorageSummary({
    required this.usedKb,
    required this.quotaKb,
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
      entries: ((data['entries'] as List?) ?? [])
          .map((e) => StorageEntry.fromJson(e))
          .toList(),
    );
  }
}
