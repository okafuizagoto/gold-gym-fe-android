class StockModel {
  final String stockCode;
  final String stockName;
  final String stockPack;      // unit (e.g., "PCS", "BOX")
  final int stockQty;
  final double stockPrice;
  final DateTime? stockQtyUpdate;
  final DateTime? stockLastUpdate;
  final String? stockUpdateBy;

  StockModel({
    required this.stockCode,
    required this.stockName,
    required this.stockPack,
    required this.stockQty,
    required this.stockPrice,
    this.stockQtyUpdate,
    this.stockLastUpdate,
    this.stockUpdateBy,
  });

  factory StockModel.fromJson(Map<String, dynamic> json) {
    return StockModel(
      stockCode: json['stock_code'] ?? '',
      stockName: json['stock_name'] ?? '',
      stockPack: json['stock_pack'] ?? '',
      stockQty: json['stock_qty'] ?? 0,
      stockPrice: (json['stock_price'] ?? 0).toDouble(),
      stockQtyUpdate: json['stock_qty_update'] != null
          ? DateTime.parse(json['stock_qty_update'])
          : null,
      stockLastUpdate: json['stock_last_update'] != null
          ? DateTime.parse(json['stock_last_update'])
          : null,
      stockUpdateBy: json['stock_update_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stock_code': stockCode,
      'stock_name': stockName,
      'stock_pack': stockPack,
      'stock_qty': stockQty,
      'stock_price': stockPrice,
      'stock_qty_update': stockQtyUpdate?.toIso8601String(),
      'stock_last_update': stockLastUpdate?.toIso8601String(),
      'stock_update_by': stockUpdateBy,
    };
  }
}
