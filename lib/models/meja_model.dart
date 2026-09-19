class Meja {
  final int mejaId;
  final int mejaAreaId;
  final String mejaName;
  final int mejaCapacity;
  final String mejaStatus; // KOSONG | ISI

  Meja({
    required this.mejaId,
    required this.mejaAreaId,
    required this.mejaName,
    required this.mejaCapacity,
    required this.mejaStatus,
  });

  bool get isKosong => mejaStatus == 'KOSONG';

  factory Meja.fromJson(Map<String, dynamic> json) {
    return Meja(
      mejaId: json['meja_id'] ?? 0,
      mejaAreaId: json['meja_area_id'] ?? 0,
      mejaName: json['meja_name'] ?? '',
      mejaCapacity: json['meja_capacity'] ?? 0,
      mejaStatus: json['meja_status'] ?? 'KOSONG',
    );
  }
}
