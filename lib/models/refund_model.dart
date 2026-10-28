// Padanan models/refund.ts di web -- Refund Tahap 1 (kembalikan barang + uang) dan Tahap 2 (tukar barang).

double _n(dynamic v) => double.tryParse('$v') ?? 0;
int _i(dynamic v) => int.tryParse('$v') ?? (double.tryParse('$v')?.toInt() ?? 0);

// Sama dengan POS: Tunai atau Transfer Bank (backend juga menerima DEBIT/TRANSFER untuk data lama).
const List<String> refundMethods = ['TUNAI', 'BANK'];

String refundMethodLabel(String m) =>
    m == 'TUNAI' ? 'Tunai' : (m == 'BANK' ? 'Transfer Bank' : m);

/// Default metode refund mengikuti cara bayar nota: tunai/campur -> TUNAI, selain itu -> BANK.
String defaultRefundMethod(String payType) =>
    (payType.isEmpty || payType == 'TUNAI' || payType == 'CAMPUR') ? 'TUNAI' : 'BANK';

bool isExchangeMode(String mode) => mode == 'EXCHANGE';
String refundModeLabel(String mode) => mode == 'EXCHANGE' ? 'Tukar barang' : 'Refund';

class RefundHeader {
  final String mode; // MONEY_BACK | EXCHANGE
  final double exchangeTotal; // nilai barang pengganti
  final double net; // exchange - total: + pelanggan bayar, - dikembalikan
  final String netMethod;
  final double cashDelta;
  bool get isExchange => mode == 'EXCHANGE';
  final String refundId;
  final String refundNumber;
  final String outcode;
  final String saleId;
  final String saleNumber;
  final double total;
  final String method;
  final String reason;
  final String by;
  final String date; // YYYY-MM-DD
  final String time;

  RefundHeader({
    this.mode = 'MONEY_BACK',
    this.exchangeTotal = 0,
    this.net = 0,
    this.netMethod = '',
    this.cashDelta = 0,
    required this.refundId,
    required this.refundNumber,
    required this.outcode,
    required this.saleId,
    required this.saleNumber,
    required this.total,
    required this.method,
    required this.reason,
    required this.by,
    required this.date,
    required this.time,
  });

  factory RefundHeader.fromJson(Map<String, dynamic> j) => RefundHeader(
        mode: '${j['refund_mode'] ?? 'MONEY_BACK'}',
        exchangeTotal: _n(j['refund_exchange_total']),
        net: _n(j['refund_net']),
        netMethod: '${j['refund_net_method'] ?? ''}',
        cashDelta: _n(j['refund_cash_delta']),
        refundId: '${j['refund_id'] ?? ''}',
        refundNumber: '${j['refund_number'] ?? ''}',
        outcode: '${j['refund_outcode'] ?? ''}',
        saleId: '${j['refund_sale_id'] ?? ''}',
        saleNumber: '${j['refund_sale_number'] ?? ''}',
        total: _n(j['refund_total']),
        method: '${j['refund_method'] ?? ''}',
        reason: '${j['refund_reason'] ?? ''}',
        by: '${j['refund_by'] ?? ''}',
        date: '${j['refund_date'] ?? ''}'.split('T').first,
        time: '${j['refund_time'] ?? ''}',
      );
}

class RefundLine {
  final int tdId;
  final String stockName;
  final int qty;
  final double unitPrice;
  final double amount;
  final bool restock;

  RefundLine({
    required this.tdId,
    required this.stockName,
    required this.qty,
    required this.unitPrice,
    required this.amount,
    required this.restock,
  });

  factory RefundLine.fromJson(Map<String, dynamic> j) => RefundLine(
        tdId: _i(j['td_id']),
        stockName: '${j['stock_name'] ?? ''}',
        qty: _i(j['qty']),
        unitPrice: _n(j['unit_price']),
        amount: _n(j['refund_amount']),
        restock: '${j['restock_yn'] ?? 'Y'}' == 'Y',
      );
}

/// Barang PENGGANTI pada tukar barang.
class RefundNewLine {
  final String stockId;
  final String stockName;
  final int qty;
  final double unitPrice;
  final double amount;

  RefundNewLine({
    required this.stockId,
    required this.stockName,
    required this.qty,
    required this.unitPrice,
    required this.amount,
  });

  factory RefundNewLine.fromJson(Map<String, dynamic> j) => RefundNewLine(
        stockId: '${j['stock_id'] ?? ''}',
        stockName: '${j['stock_name'] ?? ''}',
        qty: _i(j['qty']),
        unitPrice: _n(j['unit_price']),
        amount: _n(j['line_amount']),
      );
}

class RefundDetail {
  final RefundHeader header;
  final List<RefundLine> lines;
  final List<RefundNewLine> newLines;
  final String outletName;
  final String outletAddress;

  RefundDetail({
    required this.header,
    required this.lines,
    this.newLines = const [],
    this.outletName = '',
    this.outletAddress = '',
  });

  factory RefundDetail.fromJson(Map<String, dynamic> j) => RefundDetail(
        header: RefundHeader.fromJson((j['header'] ?? {}) as Map<String, dynamic>),
        lines: ((j['lines'] ?? []) as List)
            .map((e) => RefundLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        newLines: ((j['new_lines'] ?? []) as List)
            .map((e) => RefundNewLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        outletName: '${j['outlet_name'] ?? ''}',
        outletAddress: '${j['outlet_address'] ?? ''}',
      );
}

class RefundableLine {
  final int tdId;
  final String stockName;
  final int qty;
  final int refundedQty;
  final int remaining;
  final double unitPrice;
  final double unitRefund;

  RefundableLine({
    required this.tdId,
    required this.stockName,
    required this.qty,
    required this.refundedQty,
    required this.remaining,
    required this.unitPrice,
    required this.unitRefund,
  });

  factory RefundableLine.fromJson(Map<String, dynamic> j) => RefundableLine(
        tdId: _i(j['td_id']),
        stockName: '${j['stock_name'] ?? ''}',
        qty: _i(j['qty']),
        refundedQty: _i(j['refunded_qty']),
        remaining: _i(j['remaining']),
        unitPrice: _n(j['unit_price']),
        unitRefund: _n(j['unit_refund']),
      );
}

class Refundable {
  final String saleId;
  final String saleNumber;
  final String payType;
  final double saleTotal;
  final double refundedTotal;
  final double maxRefundable;
  final List<RefundableLine> lines;

  Refundable({
    required this.saleId,
    required this.saleNumber,
    required this.payType,
    required this.saleTotal,
    required this.refundedTotal,
    required this.maxRefundable,
    required this.lines,
  });

  factory Refundable.fromJson(Map<String, dynamic> j) => Refundable(
        saleId: '${j['sale_id'] ?? ''}',
        saleNumber: '${j['sale_number'] ?? ''}',
        payType: '${j['pay_type'] ?? 'TUNAI'}',
        saleTotal: _n(j['sale_total']),
        refundedTotal: _n(j['refunded_total']),
        maxRefundable: _n(j['max_refundable']),
        lines: ((j['lines'] ?? []) as List)
            .map((e) => RefundableLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
