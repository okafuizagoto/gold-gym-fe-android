// Model untuk alur pesanan pembeli (BUYER order flow).

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

/// Outlet yang bisa dipilih pembeli (semua outlet non-THERAPY, lintas penjual).
class PublicOutlet {
  final int outletGoldId;
  final String outletCode;
  final String outletName;
  final String outletType;
  final String outletAddress;
  final String ownerName;
  // hanya relevan di daftar admin: true jika outlet sudah boleh dilihat pembeli
  final bool visible;

  PublicOutlet({
    required this.outletGoldId,
    required this.outletCode,
    required this.outletName,
    required this.outletType,
    required this.outletAddress,
    required this.ownerName,
    this.visible = false,
  });

  factory PublicOutlet.fromJson(Map<String, dynamic> json) => PublicOutlet(
        outletGoldId: _toInt(json['outlet_gold_id']),
        outletCode: json['outlet_code'] ?? '',
        outletName: json['outlet_name'] ?? '',
        outletType: json['outlet_type'] ?? 'RETAIL',
        outletAddress: json['outlet_address'] ?? '',
        ownerName: json['owner_name'] ?? '',
        visible: json['visible'] == true ||
            json['visible'] == 1 ||
            json['visible'] == '1',
      );
}

/// Barang yang bisa dipesan dari satu outlet.
class CatalogItem {
  final String stockId;
  final String stockName;
  final String stockPack;
  final int stockQty;
  final int price;
  final String brand;

  CatalogItem({
    required this.stockId,
    required this.stockName,
    required this.stockPack,
    required this.stockQty,
    required this.price,
    required this.brand,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json) => CatalogItem(
        stockId: json['stock_id']?.toString() ?? '',
        stockName: json['stock_name'] ?? '',
        stockPack: json['stock_pack'] ?? '',
        stockQty: _toInt(json['stock_qty']),
        price: _toInt(json['price']),
        brand: json['brand'] ?? '',
      );
}

/// Header pesanan (dashboard pembeli & menu pesanan penjual).
class BuyerOrder {
  final String orderId;
  final int orderBuyerId;
  final String orderBuyerName;
  final int orderGoldId;
  final String orderOutcode;
  final String orderOutletName;
  final double orderTotal;
  final String orderPayType;
  final String orderPaidYN;
  final String orderStatus;
  final String? orderRejectReason;
  final String? orderSaleId;
  final DateTime? orderCreatedAt;

  BuyerOrder({
    required this.orderId,
    required this.orderBuyerId,
    required this.orderBuyerName,
    required this.orderGoldId,
    required this.orderOutcode,
    required this.orderOutletName,
    required this.orderTotal,
    required this.orderPayType,
    required this.orderPaidYN,
    required this.orderStatus,
    this.orderRejectReason,
    this.orderSaleId,
    this.orderCreatedAt,
  });

  bool get isPaid => orderPaidYN == 'Y';

  factory BuyerOrder.fromJson(Map<String, dynamic> json) => BuyerOrder(
        orderId: json['order_id'] ?? '',
        orderBuyerId: _toInt(json['order_buyer_id']),
        orderBuyerName: json['order_buyer_name'] ?? '',
        orderGoldId: _toInt(json['order_gold_id']),
        orderOutcode: json['order_outcode'] ?? '',
        orderOutletName: json['order_outlet_name'] ?? '',
        orderTotal: _toDouble(json['order_total']),
        orderPayType: json['order_pay_type'] ?? '',
        orderPaidYN: json['order_paid_yn'] ?? 'N',
        orderStatus: json['order_status'] ?? '',
        orderRejectReason: json['order_reject_reason'],
        orderSaleId: json['order_sale_id'],
        orderCreatedAt: DateTime.tryParse('${json['order_created_at'] ?? ''}'),
      );
}

/// Baris item pesanan.
class BuyerOrderDetail {
  final String stockName;
  final int qty;
  final double price;
  final double total;
  final String? pack;

  BuyerOrderDetail({
    required this.stockName,
    required this.qty,
    required this.price,
    required this.total,
    this.pack,
  });

  factory BuyerOrderDetail.fromJson(Map<String, dynamic> json) =>
      BuyerOrderDetail(
        stockName: json['od_stock_name'] ?? '',
        qty: _toInt(json['od_qty']),
        price: _toDouble(json['od_price']),
        total: _toDouble(json['od_total']),
        pack: json['od_pack'],
      );
}

/// Detail pesanan (header + item).
class BuyerOrderWithDetail {
  final BuyerOrder header;
  final List<BuyerOrderDetail> detail;

  BuyerOrderWithDetail({required this.header, required this.detail});

  factory BuyerOrderWithDetail.fromJson(Map<String, dynamic> json) =>
      BuyerOrderWithDetail(
        header: BuyerOrder.fromJson(json['header'] ?? {}),
        detail: ((json['detail'] ?? []) as List)
            .map((e) => BuyerOrderDetail.fromJson(e))
            .toList(),
      );
}

/// Label status pesanan (Bahasa Indonesia) untuk ditampilkan.
String orderStatusLabel(String status) {
  switch (status) {
    case 'WAITING':
      return 'Menunggu konfirmasi penjual';
    case 'PROCESS':
      return 'Sedang diproses';
    case 'FINISH':
      return 'Selesai';
    case 'REJECT':
      return 'Ditolak penjual';
    default:
      return status;
  }
}
