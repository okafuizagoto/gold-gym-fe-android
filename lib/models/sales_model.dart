/// Model header transaksi (th_sale) untuk history sales.
class SaleHistoryModel {
  final String saleId;
  final String saleOutcode;
  final String saleTrancnum;
  final String saleTranstime;
  final DateTime? saleTransdate;
  final double saleTranstotal;
  final double saleTranspayment;
  final double saleTranschange;
  final String saleSalesperson;
  final String saleSalescustomer;
  final String salePaymentyn; // 'Y' = lunas, 'N' = belum bayar
  // Metode pembayaran (TUNAI/BANK/DEBIT/TRANSFER) -- null utk nota lama
  // sebelum kolom ini ada.
  final String? salePayType;
  // Nomor meja gabungan (mis. "A1, A3"), null kalau tidak ada meja dipilih
  // (outlet non-retail, atau kasir tidak memilih meja) -- lihat fitur Atur Meja.
  final String? saleMejaNames;
  final double? saleTotalDiscountPercent;
  final double? saleTotalDiscountAmount;
  final String? saleVoucherCode;
  final double? saleVoucherPercent;
  final double? saleVoucherAmount;

  SaleHistoryModel({
    required this.saleId,
    required this.saleOutcode,
    required this.saleTrancnum,
    required this.saleTranstime,
    required this.saleTransdate,
    required this.saleTranstotal,
    required this.saleTranspayment,
    required this.saleTranschange,
    required this.saleSalesperson,
    required this.saleSalescustomer,
    required this.salePaymentyn,
    this.salePayType,
    this.saleMejaNames,
    this.saleTotalDiscountPercent,
    this.saleTotalDiscountAmount,
    this.saleVoucherCode,
    this.saleVoucherPercent,
    this.saleVoucherAmount,
  });

  bool get isPaid => salePaymentyn == 'Y';
  bool get hasTotalDiscount => saleTotalDiscountAmount != null;
  bool get hasVoucher => saleVoucherAmount != null;
  bool get hasMeja => saleMejaNames != null && saleMejaNames!.isNotEmpty;

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  factory SaleHistoryModel.fromJson(Map<String, dynamic> json) {
    return SaleHistoryModel(
      saleId: json['sale_id'] ?? '',
      saleOutcode: json['sale_outcode'] ?? '',
      saleTrancnum: json['sale_trancnum'] ?? '',
      saleTranstime: json['sale_transtime'] ?? '',
      saleTransdate: json['sale_transdate'] == null
          ? null
          : DateTime.tryParse(json['sale_transdate']),
      saleTranstotal: _toDouble(json['sale_transtotal']),
      saleTranspayment: _toDouble(json['sale_transpayment']),
      saleTranschange: _toDouble(json['sale_transchange']),
      saleSalesperson: json['sale_salesperson'] ?? '',
      saleSalescustomer: json['sale_salescustomer'] ?? '',
      salePaymentyn: json['sale_paymentyn'] ?? 'N',
      salePayType: json['sale_pay_type'],
      saleMejaNames: json['sale_meja_names'],
      saleTotalDiscountPercent: json['sale_total_discount_percent'] == null
          ? null
          : _toDouble(json['sale_total_discount_percent']),
      saleTotalDiscountAmount: json['sale_total_discount_amount'] == null
          ? null
          : _toDouble(json['sale_total_discount_amount']),
      saleVoucherCode: json['sale_voucher_code'],
      saleVoucherPercent: json['sale_voucher_percent'] == null
          ? null
          : _toDouble(json['sale_voucher_percent']),
      saleVoucherAmount: json['sale_voucher_amount'] == null
          ? null
          : _toDouble(json['sale_voucher_amount']),
    );
  }
}

/// Model satu baris item (td_sale) di layar Detail Sales.
class SaleDetailLineModel {
  final int tdId;
  final String saleStockid;
  final String saleStockname;
  final int saleQty;
  final double saleSalesprice;
  final double saleTotalsalesprice;
  final String salePack;
  final String? saleDiscountType; // PERCENT | NOMINAL
  final double? saleDiscountValue;
  final double? saleDiscountAmount;
  final DateTime? saleDiscountCreatedAt;

  SaleDetailLineModel({
    required this.tdId,
    required this.saleStockid,
    required this.saleStockname,
    required this.saleQty,
    required this.saleSalesprice,
    required this.saleTotalsalesprice,
    required this.salePack,
    this.saleDiscountType,
    this.saleDiscountValue,
    this.saleDiscountAmount,
    this.saleDiscountCreatedAt,
  });

  bool get hasDiscount => saleDiscountValue != null;

  factory SaleDetailLineModel.fromJson(Map<String, dynamic> json) {
    return SaleDetailLineModel(
      tdId: json['td_id'] ?? 0,
      saleStockid: json['sale_stockid'] ?? '',
      saleStockname: json['sale_stockname'] ?? '',
      saleQty: json['sale_qty'] ?? 0,
      saleSalesprice: SaleHistoryModel._toDouble(json['sale_salesprice']),
      saleTotalsalesprice:
          SaleHistoryModel._toDouble(json['sale_totalsalesprice']),
      salePack: json['sale_pack'] ?? '',
      saleDiscountType: json['sale_discount_type'],
      saleDiscountValue: json['sale_discount_value'] == null
          ? null
          : SaleHistoryModel._toDouble(json['sale_discount_value']),
      saleDiscountAmount: json['sale_discount_amount'] == null
          ? null
          : SaleHistoryModel._toDouble(json['sale_discount_amount']),
      saleDiscountCreatedAt: json['sale_discount_created_at'] == null
          ? null
          : DateTime.tryParse(json['sale_discount_created_at']),
    );
  }
}

/// Response gabungan header (th_sale) + detail (td_sale) untuk layar Detail Sales.
class SaleDetailResponse {
  final SaleHistoryModel header;
  final List<SaleDetailLineModel> detail;

  SaleDetailResponse({required this.header, required this.detail});

  factory SaleDetailResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return SaleDetailResponse(
      header: SaleHistoryModel.fromJson(
          data['header'] as Map<String, dynamic>? ?? {}),
      detail: ((data['detail'] as List?) ?? [])
          .map((e) => SaleDetailLineModel.fromJson(e))
          .toList(),
    );
  }
}

class SaleHistoryPagination {
  final List<SaleHistoryModel> data;
  final int page;
  final int limit;
  final int totalData;
  final int totalPage;

  SaleHistoryPagination({
    required this.data,
    required this.page,
    required this.limit,
    required this.totalData,
    required this.totalPage,
  });

  factory SaleHistoryPagination.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] as List? ?? [])
        .map((e) => SaleHistoryModel.fromJson(e))
        .toList();
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    return SaleHistoryPagination(
      data: list,
      page: metadata['page'] ?? 1,
      limit: metadata['limit'] ?? list.length,
      totalData: metadata['total_data'] ?? list.length,
      totalPage: metadata['total_page'] ?? 1,
    );
  }
}
