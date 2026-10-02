// Padanan model Go internal/entity/location -- lihat lib/widgets/location_picker.dart.

class LocationCountry {
  final int countryId;
  final String iso2;
  final String name;

  LocationCountry({required this.countryId, required this.iso2, required this.name});

  factory LocationCountry.fromJson(Map<String, dynamic> json) {
    return LocationCountry(
      countryId: json['country_id'] ?? 0,
      iso2: json['iso2'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class LocationDivision {
  final int divisionId;
  final int countryId;
  final int? parentId;
  final int level;
  final String officialCode;
  final String name;

  LocationDivision({
    required this.divisionId,
    required this.countryId,
    this.parentId,
    required this.level,
    required this.officialCode,
    required this.name,
  });

  factory LocationDivision.fromJson(Map<String, dynamic> json) {
    return LocationDivision(
      divisionId: json['division_id'] ?? 0,
      countryId: json['country_id'] ?? 0,
      parentId: json['parent_id'],
      level: json['level'] ?? 0,
      officialCode: json['official_code'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

/// Hasil pilihan LocationPicker -- dikirim apa adanya ke body insert/update outlet
/// (field country_id, division_level1_id..4_id, outlet_postal_code).
class LocationSelection {
  int? countryId;
  int? level1Id;
  int? level2Id;
  int? level3Id;
  int? level4Id;
  String? postalCode;

  LocationSelection({
    this.countryId,
    this.level1Id,
    this.level2Id,
    this.level3Id,
    this.level4Id,
    this.postalCode,
  });

  bool get isEmpty => countryId == null;

  Map<String, dynamic> toJson() {
    if (isEmpty) return {};
    return {
      'country_id': countryId,
      if (level1Id != null) 'division_level1_id': level1Id,
      if (level2Id != null) 'division_level2_id': level2Id,
      if (level3Id != null) 'division_level3_id': level3Id,
      if (level4Id != null) 'division_level4_id': level4Id,
      if (postalCode != null && postalCode!.isNotEmpty) 'outlet_postal_code': postalCode,
    };
  }

  LocationSelection copy() => LocationSelection(
        countryId: countryId,
        level1Id: level1Id,
        level2Id: level2Id,
        level3Id: level3Id,
        level4Id: level4Id,
        postalCode: postalCode,
      );
}
