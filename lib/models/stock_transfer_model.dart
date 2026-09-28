/// Padanan models/stockTransfer.ts -- transfer stok antar outlet.
class TransferStatus {
  static const String dibuat = 'DIBUAT';
  static const String dikirim = 'DIKIRIM';
  static const String diterima = 'DITERIMA';
  static const String dibatalkan = 'DIBATALKAN';
}

class TransferLevel {
  static const String none = 'NONE';
  static const String persetujuan = 'PERSETUJUAN';
  static const String penuh = 'PENUH';
  static const List<String> all = [none, persetujuan, penuh];

  static String label(String v) {
    switch (v) {
      case persetujuan:
        return 'Perlu persetujuan pemilik';
      case penuh:
        return 'Boleh penuh';
      default:
        return 'Tidak boleh';
    }
  }

  static String normalize(dynamic v) =>
      (v == penuh || v == persetujuan) ? v as String : none;
}

/// Ukuran kertas surat jalan: nilai = query `paper` di backend.
class TransferPaper {
  static const List<String> all = ['a4', '58', '80'];
  static String label(String v) {
    switch (v) {
      case '58':
        return 'Thermal 58 mm';
      case '80':
        return 'Thermal 80 mm';
      default:
        return 'A4';
    }
  }
}

int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
String? _ns(dynamic v) => v == null ? null : v.toString();
DateTime? _d(dynamic v) {
  final s = v?.toString() ?? '';
  if (s.isEmpty || s.startsWith('0001-01-01')) return null;
  return DateTime.tryParse(s);
}

class TransferItem {
  final String stockId;
  final int itemId;
  final String name;
  final String pack;
  final int qty;

  TransferItem({
    required this.stockId,
    required this.itemId,
    required this.name,
    required this.pack,
    required this.qty,
  });

  factory TransferItem.fromJson(Map<String, dynamic> j) => TransferItem(
        stockId: '${j['stock_id'] ?? ''}',
        itemId: _i(j['item_id']),
        name: '${j['name'] ?? ''}',
        pack: '${j['pack'] ?? ''}',
        qty: _i(j['qty']),
      );
}

class StockTransfer {
  final int id;
  final String number;
  final String fromOutcode;
  final String toOutcode;
  final String fromName;
  final String toName;
  final String status;
  final String note;
  final String createdByName;
  final DateTime? createdAt;
  final String? sentByName;
  final DateTime? sentAt;
  final String? receivedByName;
  final String? receiverName;
  final DateTime? receivedAt;
  final String? cancelledByName;
  final String? cancelReason;
  final DateTime? cancelledAt;

  /// 'KIRIM' | 'TERIMA' | null -- permintaan menunggu persetujuan pemilik.
  final String? pendingAction;
  final String? pendingByName;
  final List<TransferItem> items;

  StockTransfer({
    required this.id,
    required this.number,
    required this.fromOutcode,
    required this.toOutcode,
    required this.fromName,
    required this.toName,
    required this.status,
    required this.note,
    required this.createdByName,
    required this.createdAt,
    this.sentByName,
    this.sentAt,
    this.receivedByName,
    this.receiverName,
    this.receivedAt,
    this.cancelledByName,
    this.cancelReason,
    this.cancelledAt,
    this.pendingAction,
    this.pendingByName,
    this.items = const [],
  });

  factory StockTransfer.fromJson(Map<String, dynamic> j) => StockTransfer(
        id: _i(j['id']),
        number: '${j['number'] ?? ''}',
        fromOutcode: '${j['from_outcode'] ?? ''}',
        toOutcode: '${j['to_outcode'] ?? ''}',
        fromName: '${j['from_name'] ?? j['from_outcode'] ?? ''}',
        toName: '${j['to_name'] ?? j['to_outcode'] ?? ''}',
        status: '${j['status'] ?? ''}',
        note: '${j['note'] ?? ''}',
        createdByName: '${j['created_by_name'] ?? ''}',
        createdAt: _d(j['created_at']),
        sentByName: _ns(j['sent_by_name']),
        sentAt: _d(j['sent_at']),
        receivedByName: _ns(j['received_by_name']),
        receiverName: _ns(j['receiver_name']),
        receivedAt: _d(j['received_at']),
        cancelledByName: _ns(j['cancelled_by_name']),
        cancelReason: _ns(j['cancel_reason']),
        cancelledAt: _d(j['cancelled_at']),
        pendingAction: _ns(j['pending_action']),
        pendingByName: _ns(j['pending_by_name']),
        items: ((j['items'] ?? []) as List)
            .map((e) => TransferItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TransferPermission {
  final int staffGoldId;
  final String sendLevel;
  final String receiveLevel;

  TransferPermission({
    required this.staffGoldId,
    required this.sendLevel,
    required this.receiveLevel,
  });

  factory TransferPermission.fromJson(Map<String, dynamic> j) =>
      TransferPermission(
        staffGoldId: _i(j['staff_gold_id']),
        sendLevel: TransferLevel.normalize(j['send_level']),
        receiveLevel: TransferLevel.normalize(j['receive_level']),
      );
}
