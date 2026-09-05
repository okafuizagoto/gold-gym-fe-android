class ItemForOutlet {
  final int itemId;
  final String itemName;
  final int itemPrice;

  ItemForOutlet({
    required this.itemId,
    required this.itemName,
    required this.itemPrice,
  });

  factory ItemForOutlet.fromJson(Map<String, dynamic> json) {
    return ItemForOutlet(
      itemId: json["item_id"] ?? 0,
      itemName: json["item_name"] ?? "",
      itemPrice: json["item_price"] ?? 0,
    );
  }
}

// ----------------------------------------------------------------------------
class DiscountResponse {
  final int discountId;
  final int discountGoldId;
  final String discountOutcode;
  final String discountScope; // ITEM | TOTAL
  final int discountItemId;
  final String discountItemName;
  final String discountType; // PERCENT | NOMINAL
  final double discountValue;
  final String discountStatus; // ACTIVE | NONACTIVE
  final String discountCreatedBy;
  final DateTime discountCreatedAt;
  final DateTime? discountUpdatedAt;

  DiscountResponse({
    required this.discountId,
    required this.discountGoldId,
    required this.discountOutcode,
    required this.discountScope,
    required this.discountItemId,
    required this.discountItemName,
    required this.discountType,
    required this.discountValue,
    required this.discountStatus,
    required this.discountCreatedBy,
    required this.discountCreatedAt,
    this.discountUpdatedAt,
  });

  bool get isTotalScope => discountScope == 'TOTAL';

  factory DiscountResponse.fromJson(Map<String, dynamic> json) {
    return DiscountResponse(
      discountId: json["discount_id"] ?? 0,
      discountGoldId: json["discount_gold_id"] ?? 0,
      discountOutcode: json["discount_outcode"] ?? "",
      discountScope: json["discount_scope"] ?? "ITEM",
      discountItemId: json["discount_item_id"] ?? 0,
      discountItemName: json["discount_item_name"] ?? "",
      discountType: json["discount_type"] ?? "PERCENT",
      discountValue: (json["discount_value"] ?? 0).toDouble(),
      discountStatus: json["discount_status"] ?? "ACTIVE",
      discountCreatedBy: json["discount_created_by"] ?? "",
      discountCreatedAt:
          DateTime.tryParse('${json["discount_created_at"] ?? ''}') ??
              DateTime.now(),
      discountUpdatedAt: json["discount_updated_at"] == null
          ? null
          : DateTime.tryParse('${json["discount_updated_at"]}'),
    );
  }
}

class DiscountPagination {
  final List<DiscountResponse> data;
  final int page;
  final int limit;
  final int totalData;
  final int totalPage;

  DiscountPagination({
    required this.data,
    required this.page,
    required this.limit,
    required this.totalData,
    required this.totalPage,
  });

  factory DiscountPagination.fromJson(Map<String, dynamic> json) {
    return DiscountPagination(
      data: (json["data"] as List)
          .map((e) => DiscountResponse.fromJson(e))
          .toList(),
      page: json["metadata"]["page"],
      limit: json["metadata"]["limit"],
      totalData: json["metadata"]["total_data"],
      totalPage: json["metadata"]["total_page"],
    );
  }
}

// ----------------------------------------------------------------------------
class DiscountHistoryResponse {
  final int historyId;
  final int historyDiscountId;
  final String historyAction; // INSERT | UPDATE | DELETE
  final String historyActorName;
  final String historyActorRole;
  final String historyItemName;
  final String historyDiscountType;
  final double historyDiscountValue;
  final String historyDiscountStatus;
  final DateTime historyChangedAt;

  DiscountHistoryResponse({
    required this.historyId,
    required this.historyDiscountId,
    required this.historyAction,
    required this.historyActorName,
    required this.historyActorRole,
    required this.historyItemName,
    required this.historyDiscountType,
    required this.historyDiscountValue,
    required this.historyDiscountStatus,
    required this.historyChangedAt,
  });

  factory DiscountHistoryResponse.fromJson(Map<String, dynamic> json) {
    return DiscountHistoryResponse(
      historyId: json["history_id"] ?? 0,
      historyDiscountId: json["history_discount_id"] ?? 0,
      historyAction: json["history_action"] ?? "",
      historyActorName: json["history_actor_name"] ?? "",
      historyActorRole: json["history_actor_role"] ?? "",
      historyItemName: json["history_item_name"] ?? "",
      historyDiscountType: json["history_discount_type"] ?? "",
      historyDiscountValue: (json["history_discount_value"] ?? 0).toDouble(),
      historyDiscountStatus: json["history_discount_status"] ?? "",
      historyChangedAt:
          DateTime.tryParse('${json["history_changed_at"] ?? ''}') ??
              DateTime.now(),
    );
  }
}

class DiscountHistoryPagination {
  final List<DiscountHistoryResponse> data;
  final int page;
  final int limit;
  final int totalData;
  final int totalPage;

  DiscountHistoryPagination({
    required this.data,
    required this.page,
    required this.limit,
    required this.totalData,
    required this.totalPage,
  });

  factory DiscountHistoryPagination.fromJson(Map<String, dynamic> json) {
    return DiscountHistoryPagination(
      data: (json["data"] as List)
          .map((e) => DiscountHistoryResponse.fromJson(e))
          .toList(),
      page: json["metadata"]["page"],
      limit: json["metadata"]["limit"],
      totalData: json["metadata"]["total_data"],
      totalPage: json["metadata"]["total_page"],
    );
  }
}

// ----------------------------------------------------------------------------
// DiscountInfo: dipakai CartProvider (POS) untuk auto-apply diskon per item,
// bersumber dari DiscountResponse tapi hanya field yang relevan di keranjang.
class DiscountInfo {
  final int discountId;
  final String discountType; // PERCENT | NOMINAL
  final double discountValue;
  final DateTime discountCreatedAt;

  DiscountInfo({
    required this.discountId,
    required this.discountType,
    required this.discountValue,
    required this.discountCreatedAt,
  });

  factory DiscountInfo.fromDiscountResponse(DiscountResponse d) {
    return DiscountInfo(
      discountId: d.discountId,
      discountType: d.discountType,
      discountValue: d.discountValue,
      discountCreatedAt: d.discountCreatedAt,
    );
  }
}

// ----------------------------------------------------------------------------
class VoucherResponse {
  final int voucherId;
  final String voucherCode;
  final double voucherPercent;
  final DateTime? voucherExpiredAt;
  final String voucherCreatedBy;
  final DateTime voucherCreatedAt;

  VoucherResponse({
    required this.voucherId,
    required this.voucherCode,
    required this.voucherPercent,
    this.voucherExpiredAt,
    required this.voucherCreatedBy,
    required this.voucherCreatedAt,
  });

  factory VoucherResponse.fromJson(Map<String, dynamic> json) {
    return VoucherResponse(
      voucherId: json["voucher_id"] ?? 0,
      voucherCode: json["voucher_code"] ?? "",
      voucherPercent: (json["voucher_percent"] ?? 0).toDouble(),
      voucherExpiredAt: json["voucher_expired_at"] == null
          ? null
          : DateTime.tryParse('${json["voucher_expired_at"]}'),
      voucherCreatedBy: json["voucher_created_by"] ?? "",
      voucherCreatedAt:
          DateTime.tryParse('${json["voucher_created_at"] ?? ''}') ??
              DateTime.now(),
    );
  }
}

class VoucherPagination {
  final List<VoucherResponse> data;
  final int page;
  final int limit;
  final int totalData;
  final int totalPage;

  VoucherPagination({
    required this.data,
    required this.page,
    required this.limit,
    required this.totalData,
    required this.totalPage,
  });

  factory VoucherPagination.fromJson(Map<String, dynamic> json) {
    return VoucherPagination(
      data: (json["data"] as List)
          .map((e) => VoucherResponse.fromJson(e))
          .toList(),
      page: json["metadata"]["page"],
      limit: json["metadata"]["limit"],
      totalData: json["metadata"]["total_data"],
      totalPage: json["metadata"]["total_page"],
    );
  }
}

class VoucherHistoryResponse {
  final int historyId;
  final String historyVoucherCode;
  final double historyPercent;
  final String historyStatus; // USED | EXPIRED | DELETED
  final String? historySaleId;
  final String historyActorName;
  final String historyActorRole;
  final DateTime historyChangedAt;

  VoucherHistoryResponse({
    required this.historyId,
    required this.historyVoucherCode,
    required this.historyPercent,
    required this.historyStatus,
    this.historySaleId,
    required this.historyActorName,
    required this.historyActorRole,
    required this.historyChangedAt,
  });

  factory VoucherHistoryResponse.fromJson(Map<String, dynamic> json) {
    return VoucherHistoryResponse(
      historyId: json["history_id"] ?? 0,
      historyVoucherCode: json["history_voucher_code"] ?? "",
      historyPercent: (json["history_percent"] ?? 0).toDouble(),
      historyStatus: json["history_status"] ?? "",
      historySaleId: json["history_sale_id"],
      historyActorName: json["history_actor_name"] ?? "",
      historyActorRole: json["history_actor_role"] ?? "",
      historyChangedAt:
          DateTime.tryParse('${json["history_changed_at"] ?? ''}') ??
              DateTime.now(),
    );
  }
}

class VoucherHistoryPagination {
  final List<VoucherHistoryResponse> data;
  final int page;
  final int limit;
  final int totalData;
  final int totalPage;

  VoucherHistoryPagination({
    required this.data,
    required this.page,
    required this.limit,
    required this.totalData,
    required this.totalPage,
  });

  factory VoucherHistoryPagination.fromJson(Map<String, dynamic> json) {
    return VoucherHistoryPagination(
      data: (json["data"] as List)
          .map((e) => VoucherHistoryResponse.fromJson(e))
          .toList(),
      page: json["metadata"]["page"],
      limit: json["metadata"]["limit"],
      totalData: json["metadata"]["total_data"],
      totalPage: json["metadata"]["total_page"],
    );
  }
}
