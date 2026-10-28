// Padanan CashDay di models/cashierShift.ts (web) -- Kas History: buku kas harian satu outlet.

double _n(dynamic v) => double.tryParse('$v') ?? 0;

class CashMovement {
  final String at; // "YYYY-MM-DD HH:MM:SS"
  final String kind; // OPENING | SALE | REFUND | CASH_OUT | CASH_IN
  final String ref;
  final String description;
  final double amount; // masuk positif, keluar negatif
  final double balance;

  /// HANDOFF_DIFF saja: 'REVIEW' (tanpa catatan pendukung) | 'PARTIAL' (catatan belum menutup selisih).
  final String flag;

  CashMovement({
    required this.at,
    required this.kind,
    required this.ref,
    required this.description,
    required this.amount,
    required this.balance,
    this.flag = '',
  });

  factory CashMovement.fromJson(Map<String, dynamic> j) => CashMovement(
        at: '${j['at'] ?? ''}',
        kind: '${j['kind'] ?? ''}',
        ref: '${j['ref'] ?? ''}',
        description: '${j['description'] ?? ''}',
        amount: _n(j['amount']),
        balance: _n(j['balance']),
        flag: '${j['flag'] ?? ''}',
      );

  /// Jam:menit dari "YYYY-MM-DD HH:MM:SS".
  String get time => at.length >= 16 ? at.substring(11, 16) : at;
}

/// Selisih serah-terima saat sebuah sesi dibuka (kas akhir sesi sebelumnya vs uang awal), lengkap dengan alasan + penulisnya.
class HandoffNote {
  final int shiftId;
  final String? verifyStatus; // RESOLVED | ACCEPTED | null (belum diverifikasi)
  final String verifyNote;
  final String verifyBy;
  final String verifyAt;
  final double diff;
  final double? gapNet;
  final double prevCounted;
  final double expected;
  final double opening;
  final String reason;
  final String by;

  HandoffNote({
    required this.shiftId,
    required this.verifyStatus,
    required this.verifyNote,
    required this.verifyBy,
    required this.verifyAt,
    required this.diff,
    required this.gapNet,
    required this.prevCounted,
    required this.expected,
    required this.opening,
    required this.reason,
    required this.by,
  });

  bool get verified => verifyStatus != null;

  factory HandoffNote.fromShift(Map<String, dynamic> j) => HandoffNote(
        shiftId: _n(j['shift_id']).toInt(),
        verifyStatus: j['verify_status'] == null ? null : '${j['verify_status']}',
        verifyNote: '${j['verify_note'] ?? ''}',
        verifyBy: '${j['verify_by'] ?? ''}',
        verifyAt: '${j['verify_at'] ?? ''}',
        diff: _n(j['handoff_diff']),
        gapNet: j['handoff_gap_net'] == null ? null : _n(j['handoff_gap_net']),
        prevCounted: _n(j['handoff_prev_counted']),
        expected: _n(j['handoff_expected']),
        opening: _n(j['shift_opening_cash']),
        reason: '${j['handoff_reason'] ?? ''}',
        by: '${j['handoff_by'] ?? ''}',
      );
}

class CashDay {
  final String date;
  final double cashIn;
  final double cashOut;
  final double endBalance;
  final List<HandoffNote> handoffs;
  final double opening;
  final double cashSales;
  final double cashRefunds;
  final double expected;
  final double nonCash;
  final int salesCount;
  final double? counted;
  final double? difference;
  final List<CashMovement> movements;

  CashDay({
    required this.date,
    required this.cashIn,
    required this.cashOut,
    required this.endBalance,
    required this.handoffs,
    required this.opening,
    required this.cashSales,
    required this.cashRefunds,
    required this.expected,
    required this.nonCash,
    required this.salesCount,
    required this.counted,
    required this.difference,
    required this.movements,
  });

  factory CashDay.fromJson(Map<String, dynamic> j) => CashDay(
        date: '${j['date'] ?? ''}',
        cashIn: _n(j['cash_in']),
        cashOut: _n(j['cash_out']),
        endBalance: _n(j['end_balance']),
        handoffs: ((j['shifts'] ?? []) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((e) => e['handoff_diff'] != null)
            .map(HandoffNote.fromShift)
            .toList(),
        opening: _n(j['opening']),
        cashSales: _n(j['cash_sales']),
        cashRefunds: _n(j['cash_refunds']),
        expected: _n(j['expected']),
        nonCash: _n(j['non_cash']),
        salesCount: _n(j['sales_count']).toInt(),
        counted: j['counted'] == null ? null : _n(j['counted']),
        difference: j['difference'] == null ? null : _n(j['difference']),
        movements: ((j['movements'] ?? []) as List)
            .map((e) => CashMovement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Catatan Tarik Kas (padanan CashMove di models/cashierShift.ts).
const List<List<dynamic>> cashMoveKinds = [
  // [key, label, incoming]
  ['TARIK_OWNER', 'Tarik owner', false],
  ['SETOR_BANK', 'Setor ke bank', false],
  ['PENGELUARAN', 'Pengeluaran kas', false],
  ['TAMBAH_MODAL', 'Tambah modal', true],
  ['KAS_MASUK_LAIN', 'Kas masuk lainnya', true],
];

String cashMoveKindLabel(String kind) {
  for (final k in cashMoveKinds) {
    if (k[0] == kind) return k[1] as String;
  }
  return kind;
}

bool cashMoveIsIncoming(String kind) {
  for (final k in cashMoveKinds) {
    if (k[0] == kind) return k[2] as bool;
  }
  return false;
}

class CashMove {
  final int id;
  final String kind;
  final double amount;
  final String reason;
  final String by;
  final String byRole;
  final String at;

  CashMove({
    required this.id,
    required this.kind,
    required this.amount,
    required this.reason,
    required this.by,
    required this.byRole,
    required this.at,
  });

  factory CashMove.fromJson(Map<String, dynamic> j) => CashMove(
        id: _n(j['id']).toInt(),
        kind: '${j['kind'] ?? ''}',
        amount: _n(j['amount']),
        reason: '${j['reason'] ?? ''}',
        by: '${j['by'] ?? ''}',
        byRole: '${j['by_role'] ?? ''}',
        at: '${j['at'] ?? ''}',
      );

  String get time => at.length >= 16 ? at.substring(11, 16) : at;
}
