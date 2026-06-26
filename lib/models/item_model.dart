// import 'dart:nativewrappers/_internal/vm/lib/ffi_native_type_patch.dart';
import 'dart:typed_data';

class Item {
  String item_name;
  String item_outcode;
  String item_type;
  String item_pack;
  int item_price;
  String item_brand;
  String item_description;
  bool item_status;
  String item_email;

  Item({
    required this.item_name,
    required this.item_outcode,
    required this.item_type,
    required this.item_pack,
    required this.item_price,
    required this.item_brand,
    required this.item_description,
    required this.item_status,
    required this.item_email,
  });

  Map<String, dynamic> toJson() {
    return {
      "item_name": item_name,
      "item_outcode": item_outcode,
      "item_type": item_type,
      "item_pack": item_pack,
      "item_price": item_price,
      "item_brand": item_brand,
      "item_description": item_description,
      "item_status": item_status ? "ACTIVE" : "NON ACTIVE",
      "item_email": item_email,
    };
  }
}

// ----------------------------------------------------------------------------
class ItemResponse {
  final int item_id;
  final int item_gold_id;
  final String item_code;
  final String item_name;
  final String item_type;
  final String item_pack;
  final int item_price;
  final String item_brand;
  final String item_description;
  final String item_status;
  final DateTime item_created_at;
  final DateTime? item_updated_at;

  ItemResponse({
    required this.item_id,
    required this.item_gold_id,
    required this.item_code,
    required this.item_name,
    required this.item_type,
    required this.item_pack,
    required this.item_price,
    required this.item_brand,
    required this.item_description,
    required this.item_status,
    required this.item_created_at,
    this.item_updated_at,
  });

  /// JSON → Object
  factory ItemResponse.fromJson(Map<String, dynamic> json) {
    return ItemResponse(
      item_id: json["item_id"],
      item_gold_id: json["item_gold_id"],
      item_code: json["item_code"] ?? "",
      item_name: json["item_name"] ?? "",
      item_type: json["item_type"] ?? "",
      item_pack: json["item_pack"] ?? "",
      item_price: json["item_price"] ?? 0.0,
      item_brand: json["item_brand"] ?? "",
      item_description: json["item_description"] ?? "",
      item_status: json["item_status"] ?? "",
      item_created_at: DateTime.parse(json["item_created_at"]),
      item_updated_at: json["item_updated_at"] == null ||
              json["item_updated_at"] == "0001-01-01T00:00:00Z"
          ? null
          : DateTime.parse(json["item_updated_at"]),
    );
  }

  /// Object → JSON
  Map<String, dynamic> toJson() {
    return {
      "item_id": item_id,
      "item_gold_id": item_gold_id,
      "item_code": item_code,
      "item_name": item_name,
      "item_type": item_type,
      "item_pack": item_pack,
      "item_price": item_price,
      "item_brand": item_brand,
      "item_description": item_description,
      "item_status": item_status,
      "item_created_at": item_created_at.toIso8601String(),
      "item_updated_at": item_updated_at?.toIso8601String(),
    };
  }
}

// ----------------------------------------------------------------------------
class ItemPagination {
  final List<ItemResponse> data;
  final int page;
  final int limit;
  final int totalData;
  final int totalPage;

  ItemPagination({
    required this.data,
    required this.page,
    required this.limit,
    required this.totalData,
    required this.totalPage,
  });

  factory ItemPagination.fromJson(Map<String, dynamic> json) {
    return ItemPagination(
      data:
          (json["data"] as List).map((e) => ItemResponse.fromJson(e)).toList(),
      page: json["metadata"]["page"],
      limit: json["metadata"]["limit"],
      totalData: json["metadata"]["total_data"],
      totalPage: json["metadata"]["total_page"],
    );
  }
}
