/// Konstanta tipe request -- FITUR_BARU tidak terikat 1 menu (menu boleh
/// kosong), PERBAIKAN wajib menyertakan nama menu yang dilaporkan.
class FeatureRequestType {
  static const String fiturBaru = 'FITUR_BARU';
  static const String perbaikan = 'PERBAIKAN';

  static String label(String value) {
    switch (value) {
      case perbaikan:
        return 'Perbaikan';
      default:
        return 'Fitur Baru';
    }
  }
}

/// Konstanta status -- alur review: BARU -> DITINJAU -> DIRENCANAKAN ->
/// SELESAI, atau DITOLAK kapan saja.
class FeatureRequestStatus {
  static const String baru = 'BARU';
  static const String ditinjau = 'DITINJAU';
  static const String direncanakan = 'DIRENCANAKAN';
  static const String selesai = 'SELESAI';
  static const String ditolak = 'DITOLAK';

  static const List<String> all = [
    baru,
    ditinjau,
    direncanakan,
    selesai,
    ditolak
  ];

  static String label(String value) {
    switch (value) {
      case ditinjau:
        return 'Ditinjau';
      case direncanakan:
        return 'Direncanakan';
      case selesai:
        return 'Selesai';
      case ditolak:
        return 'Ditolak';
      default:
        return 'Baru';
    }
  }
}

/// Konstanta kategori -- diturunkan SERVER-SIDE dari role JWT (+ outlet_type
/// untuk SELLER), bukan dikirim client. Dipakai di layar admin.
class FeatureRequestCategory {
  static const String penjualRetail = 'PENJUAL_RETAIL';
  static const String penjualTherapy = 'PENJUAL_THERAPY';
  static const String pembeli = 'PEMBELI';
  static const String staff = 'STAFF';

  static const List<String> all = [
    penjualRetail,
    penjualTherapy,
    pembeli,
    staff
  ];

  static String label(String value) {
    switch (value) {
      case penjualRetail:
        return 'Penjual Retail';
      case penjualTherapy:
        return 'Penjual Therapy';
      case pembeli:
        return 'Pembeli';
      case staff:
        return 'Staff';
      default:
        return value;
    }
  }
}

/// Satu baris permintaan fitur/perbaikan -- padanan models/featureRequest.ts.
class FeatureRequest {
  final int requestId;
  final int requestGoldId;
  final String requestRole;
  final String requestCategory;
  final String requestType;
  final String requestMenu;
  final String requestTitle;
  final String requestDescription;
  final String requestStatus;
  final DateTime? requestCreatedAt;

  FeatureRequest({
    required this.requestId,
    required this.requestGoldId,
    required this.requestRole,
    required this.requestCategory,
    required this.requestType,
    required this.requestMenu,
    required this.requestTitle,
    required this.requestDescription,
    required this.requestStatus,
    required this.requestCreatedAt,
  });

  factory FeatureRequest.fromJson(Map<String, dynamic> json) {
    return FeatureRequest(
      requestId: json['request_id'] ?? 0,
      requestGoldId: json['request_gold_id'] ?? 0,
      requestRole: json['request_role'] ?? '',
      requestCategory: json['request_category'] ?? '',
      requestType: json['request_type'] ?? FeatureRequestType.fiturBaru,
      requestMenu: json['request_menu'] ?? '',
      requestTitle: json['request_title'] ?? '',
      requestDescription: json['request_description'] ?? '',
      requestStatus: json['request_status'] ?? FeatureRequestStatus.baru,
      requestCreatedAt: json['request_created_at'] == null
          ? null
          : DateTime.tryParse(json['request_created_at']),
    );
  }
}
