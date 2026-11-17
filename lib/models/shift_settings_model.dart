/// Pengaturan hitung uang per outlet (hanya pemilik yang mengubah). true = Wajib (bawaan), false = Opsional.
/// Padanan ShiftSettings di models/cashierShift.ts (web).
class ShiftSettings {
  final bool countOnClose;
  final bool countOnOpen;

  const ShiftSettings({this.countOnClose = true, this.countOnOpen = true});

  factory ShiftSettings.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ShiftSettings();
    return ShiftSettings(
      countOnClose: j['count_on_close'] != false,
      countOnOpen: j['count_on_open'] != false,
    );
  }

  ShiftSettings copyWith({bool? countOnClose, bool? countOnOpen}) => ShiftSettings(
        countOnClose: countOnClose ?? this.countOnClose,
        countOnOpen: countOnOpen ?? this.countOnOpen,
      );
}
