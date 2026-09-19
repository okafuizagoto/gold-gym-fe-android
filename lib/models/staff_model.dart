int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

/// Satu akun staff (baris data_peserta role STAFF) milik 1 owner penjual.
class StaffRow {
  final int goldId;
  final String email;
  final String nama;
  final String nomorHp;
  final int ownerId;

  StaffRow({
    required this.goldId,
    required this.email,
    required this.nama,
    required this.nomorHp,
    required this.ownerId,
  });

  factory StaffRow.fromJson(Map<String, dynamic> json) => StaffRow(
        goldId: _toInt(json['gold_id']),
        email: json['gold_email'] ?? '',
        nama: json['gold_nama'] ?? '',
        nomorHp: json['gold_nomorhp'] ?? '',
        ownerId: _toInt(json['gold_owner_id']),
      );
}
