class StockModel {
  final int stockItemId;
  final String stockOutcode;
  final String stockName;
  final String stockPack;
  final int stockQty;
  final String? stockUpdateBy;

  StockModel({
    required this.stockItemId,
    required this.stockOutcode,
    required this.stockName,
    required this.stockPack,
    required this.stockQty,
    required this.stockUpdateBy,
  });

  factory StockModel.fromJson(Map<String, dynamic> json) {
    return StockModel(
      stockItemId: json['stock_item_id'] ?? 0,
      stockOutcode: json['stock_outcode'] ?? '',
      stockName: json['stock_name'] ?? '',
      stockPack: json['stock_pack'] ?? '',
      stockQty: json['stock_qty'] ?? 0,
      stockUpdateBy: json['stock_update_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stock_item_id': stockItemId,
      'stock_outcode': stockOutcode,
      'stock_name': stockName,
      'stock_pack': stockPack,
      'stock_qty': stockQty,
      'stock_update_by': stockUpdateBy,
    };
  }
}

// class StockModel {
//   final String stockId;
//   final int stockGoldId;
//   final String stockOutcode;
//   final int stockItemId;
//   final String stockName;
//   final int stockQty;
//   final DateTime stockCreatedAt;
//   final DateTime stockLastUpdate;
//   final DateTime stockqtyUpdate;
//   final String? stockUpdateBy;

//   StockModel({
//     required this.stockId,
//     required this.stockGoldId,
//     required this.stockOutcode,
//     required this.stockItemId,
//     required this.stockName,
//     required this.stockQty,
//     required this.stockCreatedAt,
//     required this.stockLastUpdate,
//     required this.stockqtyUpdate,
//     required this.stockUpdateBy,
//   });

//   factory StockModel.fromJson(Map<String, dynamic> json) {
//     return StockModel(
//       stockId: json['stock_id'] ?? 0,
//       stockGoldId: json['stock_gold_id'] ?? 0,
//       stockOutcode: json['stock_outcode'] ?? '',
//       stockItemId: json['stock_item_id'] ?? 0,
//       stockName: json['stock_name'] ?? '',
//       stockQty: json['stock_qty'] ?? 0,
//       stockCreatedAt: json['stock_created_at'] ?? '',
//       stockLastUpdate: json['stock_last_update'] ?? '',
//       stockqtyUpdate: json['stock_qty_update'] ?? '',
//       stockUpdateBy: json['stock_update_by'],
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'stock_id': stockId,
//       'stock_gold_id': stockGoldId,
//       'stock_outcode': stockOutcode,
//       'stock_item_id': stockItemId,
//       'stock_name': stockName,
//       'stock_qty': stockQty,
//       'stock_created_at': stockCreatedAt,
//       'stock_last_update': stockLastUpdate,
//       'stock_qty_update': stockqtyUpdate,
//       'stock_update_by': stockUpdateBy,
//     };
//   }
// }

// ----------------------------------------------------------------------------
class StockResponse {
  final String stock_id;
  final int stock_gold_id;
  final String stock_outcode;
  final int stock_item_id;
  final String stock_name;
  final String stock_pack;
  final int stock_qty;
  final DateTime? stock_created_at;
  final DateTime? stock_last_updated;
  final DateTime? stock_qty_update;

  StockResponse({
    required this.stock_id,
    required this.stock_gold_id,
    required this.stock_outcode,
    required this.stock_item_id,
    required this.stock_name,
    required this.stock_pack,
    required this.stock_qty,
    required this.stock_created_at,
    required this.stock_last_updated,
    required this.stock_qty_update,
  });

  /// JSON → Object
  factory StockResponse.fromJson(Map<String, dynamic> json) {
    return StockResponse(
      stock_id: json["stock_id"],
      stock_gold_id: json["stock_gold_id"],
      stock_outcode: json["stock_outcode"] ?? "",
      stock_item_id: json["stock_item_id"] ?? "",
      stock_name: json["stock_name"] ?? "",
      stock_pack: json["stock_pack"] ?? "",
      stock_qty: json["stock_qty"] ?? "",
      stock_created_at: json["stock_created_at"] == null ||
              json["stock_created_at"] == "0001-01-01T00:00:00Z"
          ? null
          : DateTime.parse(json["stock_created_at"]),
      stock_last_updated: json["stock_last_updated"] == null ||
              json["stock_last_updated"] == "0001-01-01T00:00:00Z"
          ? null
          : DateTime.parse(json["stock_last_updated"]),
      stock_qty_update: json["stock_qty_update"] == null ||
              json["stock_qty_update"] == "0001-01-01T00:00:00Z"
          ? null
          : DateTime.parse(json["stock_qty_update"]),
    );
  }

  /// Object → JSON
  Map<String, dynamic> toJson() {
    return {
      "stock_id": stock_id,
      "stock_gold_id": stock_gold_id,
      'stock_outcode': stock_outcode,
      "stock_item_id": stock_item_id,
      "stock_name": stock_name,
      "stock_pack": stock_pack,
      "stock_qty": stock_qty,
      "stock_created_at": stock_created_at?.toIso8601String(),
      "stock_last_updated": stock_last_updated?.toIso8601String(),
      // "stock_created_at": stock_created_at.toIso8601String(),
      "stock_qty_update": stock_qty_update?.toIso8601String(),
    };
  }
}

// ----------------------------------------------------------------------------
class StockPagination {
  final List<StockResponse> data;
  final int page;
  final int limit;
  final int totalData;
  final int totalPage;

  StockPagination({
    required this.data,
    required this.page,
    required this.limit,
    required this.totalData,
    required this.totalPage,
  });

  factory StockPagination.fromJson(Map<String, dynamic> json) {
    return StockPagination(
      data:
          (json["data"] as List).map((e) => StockResponse.fromJson(e)).toList(),
      page: json["metadata"]["page"],
      limit: json["metadata"]["limit"],
      totalData: json["metadata"]["total_data"],
      totalPage: json["metadata"]["total_page"],
    );
  }
}
