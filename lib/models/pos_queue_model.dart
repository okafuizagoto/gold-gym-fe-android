// Padanan backend internal/entity/posqueue. Nomor antrian ACAK (bukan berurutan), lihat komentar migrasi
// 20260930_pos_queue.sql.
class QueueStatus {
  static const menunggu = 'MENUNGGU';
  static const diproses = 'DIPROSES';
  static const selesai = 'SELESAI';
}

class QueueRow {
  final int queueId;
  final int queueNumber;
  final String queueOutcode;
  final String queueSaleId;
  final String queueStatus;
  final DateTime queueCreatedAt;

  QueueRow({
    required this.queueId,
    required this.queueNumber,
    required this.queueOutcode,
    required this.queueSaleId,
    required this.queueStatus,
    required this.queueCreatedAt,
  });

  factory QueueRow.fromJson(Map<String, dynamic> json) {
    return QueueRow(
      queueId: json['queue_id'] is int
          ? json['queue_id']
          : int.tryParse('${json['queue_id']}') ?? 0,
      queueNumber: json['queue_number'] is int
          ? json['queue_number']
          : int.tryParse('${json['queue_number']}') ?? 0,
      queueOutcode: json['queue_outcode'] ?? '',
      queueSaleId: json['queue_sale_id'] ?? '',
      queueStatus: json['queue_status'] ?? '',
      queueCreatedAt:
          DateTime.tryParse('${json['queue_created_at'] ?? ''}') ??
              DateTime.now(),
    );
  }
}
