// Padanan CashDay di models/cashierShift.ts (web) -- Kas History: buku kas harian satu outlet.

double _n(dynamic v) => double.tryParse('$v') ?? 0;

class CashMovement {
  final String at; // "YYYY-MM-DD HH:MM:SS"
  final String kind; // OPENING | SALE | REFUND
  final String ref;
  final String description;
  final double amount; // masuk positif, keluar negatif
  final double balance;

  CashMovement({
    required this.at,
    required this.kind,
    required this.ref,
    required this.description,
    required this.amount,
    required this.balance,
  });

  factory CashMovement.fromJson(Map<String, dynamic> j) => CashMovement(
        at: '${j['at'] ?? ''}',
        kind: '${j['kind'] ?? ''}',
        ref: '${j['ref'] ?? ''}',
        description: '${j['description'] ?? ''}',
        amount: _n(j['amount']),
        balance: _n(j['balance']),
      );

  /// Jam:menit dari "YYYY-MM-DD HH:MM:SS".
  String get time => at.length >= 16 ? at.substring(11, 16) : at;
}

class CashDay {
  final String date;
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
