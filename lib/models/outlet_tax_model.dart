// Pajak per outlet, tahap 1 (2026-11-17). Padanan models/outletTax.ts (web) dan internal/entity/outlettax (Go).
// Satu persen per outlet atas total belanja (setelah diskon & voucher). Bawaan MATI.
// inclusive=true  -> harga barang SUDAH termasuk pajak (total tidak berubah; pajak hanya ditampilkan).
// inclusive=false -> harga BELUM termasuk pajak (pajak ditambahkan ke total).

class TaxSettings {
  final bool enabled;
  final String name;
  final double percent;
  final bool inclusive;

  const TaxSettings({
    this.enabled = false,
    this.name = 'PPN',
    this.percent = 0,
    this.inclusive = true,
  });

  static const TaxSettings off = TaxSettings();

  factory TaxSettings.fromJson(Map<String, dynamic>? j) {
    if (j == null) return off;
    final name = j['name'];
    return TaxSettings(
      enabled: j['enabled'] == true,
      name: name is String && name.isNotEmpty ? name : 'PPN',
      percent: double.tryParse('${j['percent']}') ?? 0,
      inclusive: j['inclusive'] != false,
    );
  }

  Map<String, dynamic> toJson() =>
      {'enabled': enabled, 'name': name, 'percent': percent, 'inclusive': inclusive};

  TaxSettings copyWith({bool? enabled, String? name, double? percent, bool? inclusive}) =>
      TaxSettings(
        enabled: enabled ?? this.enabled,
        name: name ?? this.name,
        percent: percent ?? this.percent,
        inclusive: inclusive ?? this.inclusive,
      );

  /// Pajak aktif yang ditambahkan ke total (mode "belum termasuk"); server mewajibkan sale_tax_applied untuk ini.
  bool get addsToTotal => enabled && !inclusive;
}

/// Pajak dari [net] (total setelah diskon & voucher, sudah dibulatkan rupiah). Rumus SAMA dengan server
/// (outlettax.Compute) dan web (computeTax) supaya total di layar = total yang divalidasi server.
({double tax, double due}) computeTax(TaxSettings? t, double net) {
  if (t == null || !t.enabled || t.percent <= 0 || net <= 0) return (tax: 0, due: net);
  if (t.inclusive) {
    return (tax: (net * t.percent / (100 + t.percent)).roundToDouble(), due: net);
  }
  final tax = (net * t.percent / 100).roundToDouble();
  return (tax: tax, due: net + tax);
}
