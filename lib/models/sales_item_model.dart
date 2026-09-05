class SalesItemModel {
  final String stockId;
  final String stockCode;
  final String stockName;
  final int stockQty;
  final String stockPack;
  final double stockPrice;
  final double stockTotalSales; // qty * price

  /// booking terapi UNPAID yang dibayar lewat nota ini (dikirim sebagai
  /// booking_ids ke backend supaya booking ikut LUNAS); '' = bukan booking
  final String bookingId;

  /// baris hasil tambah booking (termasuk baris potongan booking yang sudah
  /// bayar) — qty terkunci 1 dan tidak bisa diedit
  final bool isBooking;

  /// Diskon yang otomatis aktif saat item ini masuk keranjang (null = tanpa
  /// diskon). originalStockPrice dipakai untuk restore harga kalau diskon
  /// dibatalkan per baris di keranjang.
  final int? discountId;
  final String? discountType; // PERCENT | NOMINAL
  final double? discountValue;
  final double? discountAmount; // potongan per unit x qty (nominal rupiah)
  final DateTime? discountCreatedAt;
  final double? originalStockPrice;

  SalesItemModel({
    required this.stockId,
    required this.stockCode,
    required this.stockName,
    required this.stockQty,
    required this.stockPack,
    required this.stockPrice,
    required this.stockTotalSales,
    this.bookingId = '',
    this.isBooking = false,
    this.discountId,
    this.discountType,
    this.discountValue,
    this.discountAmount,
    this.discountCreatedAt,
    this.originalStockPrice,
  });

  // Create from form input
  factory SalesItemModel.create({
    required String stockId,
    required String stockCode,
    required String stockName,
    required int qty,
    required String stockPack,
    required double price,
    String bookingId = '',
    bool isBooking = false,
    int? discountId,
    String? discountType,
    double? discountValue,
    double? discountAmount,
    DateTime? discountCreatedAt,
    double? originalStockPrice,
  }) {
    return SalesItemModel(
      stockId: stockId,
      stockCode: stockCode,
      stockName: stockName,
      stockQty: qty,
      stockPack: stockPack,
      stockPrice: price,
      stockTotalSales: qty * price,
      bookingId: bookingId,
      isBooking: isBooking,
      discountId: discountId,
      discountType: discountType,
      discountValue: discountValue,
      discountAmount: discountAmount,
      discountCreatedAt: discountCreatedAt,
      originalStockPrice: originalStockPrice,
    );
  }

  // Update quantity (recalculate total)
  SalesItemModel copyWithQty(int newQty) {
    return SalesItemModel(
      stockId: stockId,
      stockCode: stockCode,
      stockName: stockName,
      stockQty: newQty,
      stockPack: stockPack,
      stockPrice: stockPrice,
      stockTotalSales: newQty * stockPrice,
      bookingId: bookingId,
      isBooking: isBooking,
      discountId: discountId,
      discountType: discountType,
      discountValue: discountValue,
      discountAmount: discountAmount == null
          ? null
          : (discountAmount! / stockQty.clamp(1, 1 << 30)) * newQty,
      discountCreatedAt: discountCreatedAt,
      originalStockPrice: originalStockPrice,
    );
  }

  /// Batalkan diskon pada baris ini -- harga kembali ke originalStockPrice.
  SalesItemModel copyWithDiscountCancelled() {
    final restoredPrice = originalStockPrice ?? stockPrice;
    return SalesItemModel(
      stockId: stockId,
      stockCode: stockCode,
      stockName: stockName,
      stockQty: stockQty,
      stockPack: stockPack,
      stockPrice: restoredPrice,
      stockTotalSales: stockQty * restoredPrice,
      bookingId: bookingId,
      isBooking: isBooking,
    );
  }

  bool get hasDiscount => discountId != null;

  Map<String, dynamic> toJson() {
    return {
      'stock_id': stockId,
      'stock_code': stockCode,
      'stock_name': stockName,
      'stock_qty': stockQty,
      'stock_pack': stockPack,
      'stock_price': stockPrice,
      'stock_totalsales': stockTotalSales,
    };
  }

  /// Format detail sesuai body insert sales backend (TDSaleDetail)
  Map<String, dynamic> toSaleDetailJson() {
    final json = <String, dynamic>{
      'sale_stockid': stockId,
      'sale_stockname': stockName,
      'sale_qty': stockQty,
      'sale_salesprice': stockPrice.toStringAsFixed(0),
      'sale_totalsalesprice': stockTotalSales.toStringAsFixed(0),
      'sale_pack': stockPack,
    };
    if (hasDiscount) {
      json['sale_discount_id'] = discountId;
      json['sale_discount_type'] = discountType;
      json['sale_discount_value'] = discountValue?.toStringAsFixed(2);
      json['sale_discount_amount'] = discountAmount?.toStringAsFixed(0);
      json['sale_discount_created_at'] =
          discountCreatedAt?.toIso8601String();
    }
    return json;
  }
}
