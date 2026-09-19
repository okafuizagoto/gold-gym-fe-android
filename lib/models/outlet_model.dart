// import 'dart:nativewrappers/_internal/vm/lib/ffi_native_type_patch.dart';
import 'dart:typed_data';

class Outlet {
  String outlet_name;
  String outlet_address;
  bool outlet_status;

  Outlet({
    required this.outlet_name,
    required this.outlet_address,
    required this.outlet_status,
  });

  Map<String, dynamic> toJson() {
    return {
      "outlet_name": outlet_name,
      "outlet_address": outlet_address,
      "outlet_status": outlet_status
    };
  }
}

// ----------------------------------------------------------------------------
class OutletResponse {
  final String outlet_id;
  final int outlet_gold_id;
  final String outlet_code;
  final String outlet_name;
  final String outlet_type;
  final String outlet_address;
  final String outlet_status;
  final DateTime created_at;
  final DateTime? updated_at;

  OutletResponse({
    required this.outlet_id,
    required this.outlet_gold_id,
    required this.outlet_code,
    required this.outlet_name,
    this.outlet_type = 'RETAIL',
    required this.outlet_address,
    required this.outlet_status,
    required this.created_at,
    this.updated_at,
  });

  /// JSON → Object
  factory OutletResponse.fromJson(Map<String, dynamic> json) {
    return OutletResponse(
      outlet_id: json["outlet_id"],
      outlet_gold_id: json["outlet_gold_id"],
      outlet_code: json["outlet_code"] ?? "",
      outlet_name: json["outlet_name"] ?? "",
      outlet_type: json["outlet_type"] ?? "RETAIL",
      outlet_address: json["outlet_address"] ?? "",
      outlet_status: json["outlet_status"] ?? "",
      // parser aman: backend bisa mengirim "" untuk kolom tanggal NULL
      created_at:
          DateTime.tryParse('${json["created_at"] ?? ''}') ?? DateTime.now(),
      updated_at: json["updated_at"] == null
          ? null
          : DateTime.tryParse('${json["updated_at"]}'),
    );
  }

  /// Object → JSON
  Map<String, dynamic> toJson() {
    return {
      "outlet_id": outlet_id,
      "outlet_gold_id": outlet_gold_id,
      "outlet_code": outlet_code,
      "outlet_name": outlet_name,
      "outlet_type": outlet_type,
      "outlet_address": outlet_address,
      "outlet_status": outlet_status,
      "created_at": created_at.toIso8601String(),
      "updated_at": updated_at?.toIso8601String(),
    };
  }
}

// ----------------------------------------------------------------------------
class OutletPagination {
  final List<OutletResponse> data;
  final int page;
  final int limit;
  final int totalData;
  final int totalPage;

  OutletPagination({
    required this.data,
    required this.page,
    required this.limit,
    required this.totalData,
    required this.totalPage,
  });

  factory OutletPagination.fromJson(Map<String, dynamic> json) {
    return OutletPagination(
      data: (json["data"] as List)
          .map((e) => OutletResponse.fromJson(e))
          .toList(),
      page: json["metadata"]["page"],
      limit: json["metadata"]["limit"],
      totalData: json["metadata"]["total_data"],
      totalPage: json["metadata"]["total_page"],
    );
  }
}
