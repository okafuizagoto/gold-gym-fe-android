int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

bool _toBool(dynamic v) {
  return v == true || v == 1 || v == '1';
}

/// Satu baris outlet + status 2 menu (Daftar Pembeli/Mode Pembeli) milik
/// penjual pemiliknya. Flag ini melekat di akun penjual (gold_id), bukan
/// per outlet -- kalau 1 penjual punya beberapa outlet, semua baris
/// outletnya akan menampilkan status yang sama.
class SellerMenuAccessRow {
  final int outletGoldId;
  final String outletCode;
  final String outletName;
  final String outletType;
  final String outletAddress;
  final String ownerName;
  final bool daftarPembeliActive;
  final bool modePembeliActive;

  SellerMenuAccessRow({
    required this.outletGoldId,
    required this.outletCode,
    required this.outletName,
    required this.outletType,
    required this.outletAddress,
    required this.ownerName,
    required this.daftarPembeliActive,
    required this.modePembeliActive,
  });

  factory SellerMenuAccessRow.fromJson(Map<String, dynamic> json) =>
      SellerMenuAccessRow(
        outletGoldId: _toInt(json['outlet_gold_id']),
        outletCode: json['outlet_code'] ?? '',
        outletName: json['outlet_name'] ?? '',
        outletType: json['outlet_type'] ?? 'RETAIL',
        outletAddress: json['outlet_address'] ?? '',
        ownerName: json['owner_name'] ?? '',
        daftarPembeliActive: _toBool(json['daftar_pembeli_active']),
        modePembeliActive: _toBool(json['mode_pembeli_active']),
      );
}
