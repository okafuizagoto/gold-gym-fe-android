// Model laporan penjualan (per hari / minggu / bulan).
// Semua nilai uang diparse ke double supaya aman dari int/decimal string.

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

/// Satu baris item pada laporan per-hari.
class ReportItem {
  final String saleId;
  final String trancnum;
  final String customer;
  final String salesperson;
  final String transTime;
  final String itemName;
  final int qty;
  final double price;
  final double subtotal;
  final int remaining;

  ReportItem({
    required this.saleId,
    required this.trancnum,
    required this.customer,
    required this.salesperson,
    required this.transTime,
    required this.itemName,
    required this.qty,
    required this.price,
    required this.subtotal,
    required this.remaining,
  });

  factory ReportItem.fromJson(Map<String, dynamic> j) => ReportItem(
        saleId: j['sale_id'] ?? '',
        trancnum: j['trancnum'] ?? '',
        customer: j['customer'] ?? '',
        salesperson: j['salesperson'] ?? '',
        transTime: j['trans_time'] ?? '',
        itemName: j['item_name'] ?? '',
        qty: _toInt(j['qty']),
        price: _toDouble(j['price']),
        subtotal: _toDouble(j['subtotal']),
        remaining: _toInt(j['remaining']),
      );
}

/// Laporan per-hari: daftar item + total keseluruhan.
class DayReport {
  final String date;
  final List<ReportItem> items;
  final int count; // jumlah nota
  final double grandTotal;

  DayReport({
    required this.date,
    required this.items,
    required this.count,
    required this.grandTotal,
  });

  factory DayReport.fromJson(Map<String, dynamic> j) => DayReport(
        date: j['date'] ?? '',
        items: ((j['items'] ?? []) as List)
            .map((e) => ReportItem.fromJson(e))
            .toList(),
        count: _toInt(j['count']),
        grandTotal: _toDouble(j['grand_total']),
      );
}

/// Total penjualan satu hari (baris di laporan per-minggu).
class DailyTotal {
  final String date;
  final double total;
  final int count;

  DailyTotal({required this.date, required this.total, required this.count});

  factory DailyTotal.fromJson(Map<String, dynamic> j) => DailyTotal(
        date: j['date'] ?? '',
        total: _toDouble(j['total']),
        count: _toInt(j['count']),
      );
}

/// Laporan per-minggu: daftar total per hari + total keseluruhan.
class WeekReport {
  final String label;
  final String rangeStart;
  final String rangeEnd;
  final List<DailyTotal> days;
  final double grandTotal;

  WeekReport({
    required this.label,
    required this.rangeStart,
    required this.rangeEnd,
    required this.days,
    required this.grandTotal,
  });

  factory WeekReport.fromJson(Map<String, dynamic> j) => WeekReport(
        label: j['label'] ?? '',
        rangeStart: j['range_start'] ?? '',
        rangeEnd: j['range_end'] ?? '',
        days: ((j['days'] ?? []) as List)
            .map((e) => DailyTotal.fromJson(e))
            .toList(),
        grandTotal: _toDouble(j['grand_total']),
      );
}

/// Total penjualan satu blok minggu (baris di laporan per-bulan).
class WeeklyTotal {
  final int weekNo;
  final String label;
  final String rangeStart;
  final String rangeEnd;
  final double total;
  final int count;

  WeeklyTotal({
    required this.weekNo,
    required this.label,
    required this.rangeStart,
    required this.rangeEnd,
    required this.total,
    required this.count,
  });

  factory WeeklyTotal.fromJson(Map<String, dynamic> j) => WeeklyTotal(
        weekNo: _toInt(j['week_no']),
        label: j['label'] ?? '',
        rangeStart: j['range_start'] ?? '',
        rangeEnd: j['range_end'] ?? '',
        total: _toDouble(j['total']),
        count: _toInt(j['count']),
      );
}

/// Laporan per-bulan: daftar total per minggu + total keseluruhan.
class MonthReport {
  final String month;
  final String label;
  final List<WeeklyTotal> weeks;
  final double grandTotal;

  MonthReport({
    required this.month,
    required this.label,
    required this.weeks,
    required this.grandTotal,
  });

  factory MonthReport.fromJson(Map<String, dynamic> j) => MonthReport(
        month: j['month'] ?? '',
        label: j['label'] ?? '',
        weeks: ((j['weeks'] ?? []) as List)
            .map((e) => WeeklyTotal.fromJson(e))
            .toList(),
        grandTotal: _toDouble(j['grand_total']),
      );
}
