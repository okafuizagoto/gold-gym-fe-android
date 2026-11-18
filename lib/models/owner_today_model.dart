/// Kartu "Hari ini" semua outlet untuk pemilik (2026-11-18). Angka dari Ledger (Kas History) yang sama di server.
/// Padanan web: models/cashierShift.ts (OwnerToday).
double _d(dynamic v) => v == null || v == '' ? 0 : double.tryParse(v.toString()) ?? 0;
double? _dn(dynamic v) => v == null || v == '' ? null : double.tryParse(v.toString());
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? 0}') ?? 0;

class OutletToday {
  final String outcode;
  final String name;
  final double sales;
  final int salesCount;
  final double expected;
  final double? counted;
  final double? difference; // null = belum bisa dihitung / tidak diketahui
  final bool openShift;
  final int closedShifts;
  final int uncountedShifts;
  final int needsCheck;
  final String error;

  const OutletToday({
    required this.outcode,
    this.name = '',
    this.sales = 0,
    this.salesCount = 0,
    this.expected = 0,
    this.counted,
    this.difference,
    this.openShift = false,
    this.closedShifts = 0,
    this.uncountedShifts = 0,
    this.needsCheck = 0,
    this.error = '',
  });

  factory OutletToday.fromJson(Map<String, dynamic> j) => OutletToday(
        outcode: (j['outcode'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        sales: _d(j['sales']),
        salesCount: _i(j['sales_count']),
        expected: _d(j['expected']),
        counted: _dn(j['counted']),
        difference: _dn(j['difference']),
        openShift: j['open_shift'] == true,
        closedShifts: _i(j['closed_shifts']),
        uncountedShifts: _i(j['uncounted_shifts']),
        needsCheck: _i(j['needs_check']),
        error: (j['error'] ?? '').toString(),
      );

  /// Status kas untuk chip: (teks, tingkat) -- tingkat: error / warning / success / neutral. Sama dengan web.
  (String, String) get cashStatus => cashStatusFor((en, id) => id);

  /// Sama dengan [cashStatus] tetapi mengikuti bahasa aplikasi: [t] memilih teks (en, id), mis. `lang.get`.
  (String, String) cashStatusFor(String Function(String en, String id) t) {
    if (needsCheck > 0) return ('$needsCheck ${t('TO CHECK', 'PERLU DICEK')}', 'error');
    if (uncountedShifts > 0) return (t('Cash not counted', 'Kas tidak dihitung'), 'warning');
    if (difference == null) {
      return (
        openShift
            ? t('Shift running', 'Sesi berjalan')
            : closedShifts > 0
                ? t('Incomplete', 'Belum lengkap')
                : t('No shift yet', 'Belum ada sesi'),
        'neutral'
      );
    }
    if (difference == 0) return (t('Cash matches', 'Kas cocok'), 'success');
    final d = difference!;
    return ('${t('Difference', 'Selisih')} ${d < 0 ? '-' : '+'}Rp${_thousand(d.abs())}', d < 0 ? 'error' : 'warning');
  }

  static String _thousand(double v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }
}

class OwnerToday {
  final String date;
  final List<OutletToday> outlets;
  final double sales;
  final int salesCount;
  final int needsCheck;
  final int uncountedShifts;

  const OwnerToday({
    required this.date,
    required this.outlets,
    this.sales = 0,
    this.salesCount = 0,
    this.needsCheck = 0,
    this.uncountedShifts = 0,
  });

  factory OwnerToday.fromJson(Map<String, dynamic> j) => OwnerToday(
        date: (j['date'] ?? '').toString(),
        sales: _d(j['sales']),
        salesCount: _i(j['sales_count']),
        needsCheck: _i(j['needs_check']),
        uncountedShifts: _i(j['uncounted_shifts']),
        outlets: ((j['outlets'] as List?) ?? [])
            .map((e) => OutletToday.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
