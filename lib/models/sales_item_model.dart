class SalesItemModel {
  final String stockCode;
  final String stockName;
  final int stockQty;
  final String stockPack;
  final double stockPrice;
  final double stockTotalSales;  // qty * price

  SalesItemModel({
    required this.stockCode,
    required this.stockName,
    required this.stockQty,
    required this.stockPack,
    required this.stockPrice,
    required this.stockTotalSales,
  });

  // Create from form input
  factory SalesItemModel.create({
    required String stockCode,
    required String stockName,
    required int qty,
    required String stockPack,
    required double price,
  }) {
    return SalesItemModel(
      stockCode: stockCode,
      stockName: stockName,
      stockQty: qty,
      stockPack: stockPack,
      stockPrice: price,
      stockTotalSales: qty * price,
    );
  }

  // Update quantity (recalculate total)
  SalesItemModel copyWithQty(int newQty) {
    return SalesItemModel(
      stockCode: stockCode,
      stockName: stockName,
      stockQty: newQty,
      stockPack: stockPack,
      stockPrice: stockPrice,
      stockTotalSales: newQty * stockPrice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stock_code': stockCode,
      'stock_name': stockName,
      'stock_qty': stockQty,
      'stock_pack': stockPack,
      'stock_price': stockPrice,
      'stock_totalsales': stockTotalSales,
    };
  }
}
