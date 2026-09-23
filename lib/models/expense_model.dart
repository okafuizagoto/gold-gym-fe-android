/// Kategori pengeluaran -- daftar TETAP, divalidasi juga di backend
/// (server-side wajib divalidasi ulang, ini cuma buat UX/label).
class ExpenseCategory {
  static const String sewa = 'SEWA';
  static const String listrikAir = 'LISTRIK_AIR';
  static const String gaji = 'GAJI';
  static const String bahanBaku = 'BAHAN_BAKU';
  static const String marketing = 'MARKETING';
  static const String transportasi = 'TRANSPORTASI';
  static const String peralatan = 'PERALATAN';
  static const String lainnya = 'LAINNYA';

  static const List<String> all = [
    sewa,
    listrikAir,
    gaji,
    bahanBaku,
    marketing,
    transportasi,
    peralatan,
    lainnya,
  ];

  static String label(String value) {
    switch (value) {
      case sewa:
        return 'Sewa';
      case listrikAir:
        return 'Listrik & Air';
      case gaji:
        return 'Gaji';
      case bahanBaku:
        return 'Bahan Baku';
      case marketing:
        return 'Marketing';
      case transportasi:
        return 'Transportasi';
      case peralatan:
        return 'Peralatan';
      default:
        return 'Lainnya';
    }
  }
}

/// Periode berulang -- cuma tag filter/pelaporan, BUKAN mesin auto-generate
/// entri berikutnya (lihat catatan desain di backend).
class RecurringPeriod {
  static const String mingguan = 'MINGGUAN';
  static const String bulanan = 'BULANAN';

  static const List<String> all = [mingguan, bulanan];

  static String label(String value) {
    switch (value) {
      case mingguan:
        return 'Mingguan';
      case bulanan:
        return 'Bulanan';
      default:
        return value;
    }
  }
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

/// Satu baris pengeluaran -- padanan models/expense.ts.
class Expense {
  final int expenseId;
  final int expenseGoldId;
  final String expenseOutcode;
  final String expenseCategory;
  final String expenseVendor;
  final double expenseAmount;
  final String expenseDate;
  final String expenseDescription;
  final bool expenseIsRecurring;
  final String expenseRecurringPeriod;
  final int expenseCreatedByGoldId;
  final DateTime? expenseCreatedAt;

  Expense({
    required this.expenseId,
    required this.expenseGoldId,
    required this.expenseOutcode,
    required this.expenseCategory,
    required this.expenseVendor,
    required this.expenseAmount,
    required this.expenseDate,
    required this.expenseDescription,
    required this.expenseIsRecurring,
    required this.expenseRecurringPeriod,
    required this.expenseCreatedByGoldId,
    required this.expenseCreatedAt,
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        expenseId: _toInt(j['expense_id']),
        expenseGoldId: _toInt(j['expense_gold_id']),
        expenseOutcode: j['expense_outcode'] ?? '',
        expenseCategory: j['expense_category'] ?? '',
        expenseVendor: j['expense_vendor'] ?? '',
        expenseAmount: _toDouble(j['expense_amount']),
        expenseDate: j['expense_date'] ?? '',
        expenseDescription: j['expense_description'] ?? '',
        expenseIsRecurring: j['expense_is_recurring'] == true,
        expenseRecurringPeriod: j['expense_recurring_period'] ?? '',
        expenseCreatedByGoldId: _toInt(j['expense_created_by_gold_id']),
        expenseCreatedAt: j['expense_created_at'] == null
            ? null
            : DateTime.tryParse(j['expense_created_at']),
      );
}

/// Satu baris breakdown kategori pada ringkasan.
class ExpenseCategorySummary {
  final String category;
  final double totalAmount;
  final int count;

  ExpenseCategorySummary({
    required this.category,
    required this.totalAmount,
    required this.count,
  });

  factory ExpenseCategorySummary.fromJson(Map<String, dynamic> j) =>
      ExpenseCategorySummary(
        category: j['category'] ?? '',
        totalAmount: _toDouble(j['total_amount']),
        count: _toInt(j['count']),
      );
}

/// Ringkasan pengeluaran satu rentang tanggal.
class ExpenseSummary {
  final double totalAmount;
  final int count;
  final List<ExpenseCategorySummary> byCategory;

  ExpenseSummary({
    required this.totalAmount,
    required this.count,
    required this.byCategory,
  });

  factory ExpenseSummary.fromJson(Map<String, dynamic> j) => ExpenseSummary(
        totalAmount: _toDouble(j['total_amount']),
        count: _toInt(j['count']),
        byCategory: ((j['by_category'] ?? []) as List)
            .map((e) => ExpenseCategorySummary.fromJson(e))
            .toList(),
      );
}
