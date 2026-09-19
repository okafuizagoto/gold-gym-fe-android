double? _toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

bool _toBool(dynamic v) {
  return v == true || v == 1 || v == '1';
}

/// Satu baris hasil GET /gold-gym/v2/staff?type=attendance -- 1 tanggal.
/// status: "hadir" | "tidak_masuk".
class AttendanceDay {
  final String date;
  final String? clockInAt;
  final String? clockOutAt;
  final double? workHours;
  final bool underHours;
  final String status;

  AttendanceDay({
    required this.date,
    required this.clockInAt,
    required this.clockOutAt,
    required this.workHours,
    required this.underHours,
    required this.status,
  });

  factory AttendanceDay.fromJson(Map<String, dynamic> json) => AttendanceDay(
        date: json['date'] ?? '',
        clockInAt: json['clock_in_at'],
        clockOutAt: json['clock_out_at'],
        workHours: _toDoubleOrNull(json['work_hours']),
        underHours: _toBool(json['under_hours']),
        status: json['status'] ?? 'tidak_masuk',
      );
}

/// Hasil GET /gold-gym/v2/staff?type=today (self-service staff).
class TodayStatus {
  final String date;
  final String? clockInAt;
  final String? clockOutAt;

  TodayStatus({
    required this.date,
    required this.clockInAt,
    required this.clockOutAt,
  });

  factory TodayStatus.fromJson(Map<String, dynamic> json) => TodayStatus(
        date: json['date'] ?? '',
        clockInAt: json['clock_in_at'],
        clockOutAt: json['clock_out_at'],
      );

  bool get isClockedIn => clockInAt != null && clockOutAt == null;
  bool get isDone => clockInAt != null && clockOutAt != null;
}
