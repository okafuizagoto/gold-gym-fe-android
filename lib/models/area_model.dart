class Area {
  final int areaId;
  final String areaName;
  final String areaType; // INDOOR | OUTDOOR

  Area({
    required this.areaId,
    required this.areaName,
    required this.areaType,
  });

  factory Area.fromJson(Map<String, dynamic> json) {
    return Area(
      areaId: json['area_id'] ?? 0,
      areaName: json['area_name'] ?? '',
      areaType: json['area_type'] ?? '',
    );
  }
}
