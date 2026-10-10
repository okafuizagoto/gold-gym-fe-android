import 'package:flutter/foundation.dart';
import '../../models/sales_item_model.dart';
import 'offline_store.dart';

/// Hold/Parkir Transaksi (2026-10-10, QA POS #7): kasir bisa menahan keranjang saat ini (mis.
/// pelanggan belum selesai pilih barang / meninggalkan kasir sebentar) untuk melayani pelanggan
/// lain, lalu lanjutkan belakangan. Disimpan LOKAL saja (belum pernah dikirim ke server -- beda
/// dari antrean offline/SalesOutbox yang sudah "disimpan" tapi belum terkonfirmasi server).
class ParkedCart {
  final String id;
  final DateTime parkedAt;
  final String? note; // label bebas kasir, mis. "Meja 3" / nama pelanggan
  final List<Map<String, dynamic>> items; // SalesItemModel.toParkJson()
  final String paymentType;
  final double cashAmount;
  final Map<String, double> splitPayments;
  final String? voucherCode;
  final double? voucherPercent;
  final List<int> mejaIds;
  final List<String> mejaNames;
  final String customerName;
  final String customerMode;

  ParkedCart({
    required this.id,
    required this.parkedAt,
    this.note,
    required this.items,
    required this.paymentType,
    required this.cashAmount,
    required this.splitPayments,
    this.voucherCode,
    this.voucherPercent,
    required this.mejaIds,
    required this.mejaNames,
    required this.customerName,
    required this.customerMode,
  });

  int get itemCount =>
      items.fold(0, (sum, i) => sum + ((i['stock_qty'] as num?)?.toInt() ?? 0));

  double get total => items.fold(
      0.0, (sum, i) => sum + ((i['stock_totalsales'] as num?)?.toDouble() ?? 0));

  Map<String, dynamic> toJson() => {
        'id': id,
        'parked_at': parkedAt.toIso8601String(),
        'note': note,
        'items': items,
        'payment_type': paymentType,
        'cash_amount': cashAmount,
        'split_payments': splitPayments,
        'voucher_code': voucherCode,
        'voucher_percent': voucherPercent,
        'meja_ids': mejaIds,
        'meja_names': mejaNames,
        'customer_name': customerName,
        'customer_mode': customerMode,
      };

  factory ParkedCart.fromJson(Map<String, dynamic> json) {
    return ParkedCart(
      id: json['id'] ?? '',
      parkedAt: DateTime.tryParse(json['parked_at'] ?? '') ?? DateTime.now(),
      note: json['note'],
      items: ((json['items'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      paymentType: json['payment_type'] ?? '',
      cashAmount: (json['cash_amount'] as num?)?.toDouble() ?? 0,
      splitPayments: ((json['split_payments'] as Map?) ?? {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
      voucherCode: json['voucher_code'],
      voucherPercent: (json['voucher_percent'] as num?)?.toDouble(),
      mejaIds: ((json['meja_ids'] as List?) ?? []).map((e) => e as int).toList(),
      mejaNames:
          ((json['meja_names'] as List?) ?? []).map((e) => e.toString()).toList(),
      customerName: json['customer_name'] ?? '',
      customerMode: json['customer_mode'] ?? '',
    );
  }

  List<SalesItemModel> toSalesItems() =>
      items.map((e) => SalesItemModel.fromParkJson(e)).toList();
}

class ParkedCartsStore extends ChangeNotifier {
  ParkedCartsStore._();
  static final ParkedCartsStore instance = ParkedCartsStore._();

  static const _file = 'parked_carts';
  final List<ParkedCart> _items = [];
  bool _loaded = false;

  List<ParkedCart> get items => List.unmodifiable(_items);
  int get count => _items.length;

  Future<void> init() async {
    if (_loaded) return;
    final raw = await OfflineStore.instance.read(_file, []);
    _items
      ..clear()
      ..addAll((raw as List)
          .map((e) => ParkedCart.fromJson(Map<String, dynamic>.from(e))));
    _loaded = true;
    notifyListeners();
  }

  Future<void> park(ParkedCart cart) async {
    await init();
    _items.add(cart);
    await _persist();
  }

  Future<ParkedCart?> take(String id) async {
    await init();
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) return null;
    final cart = _items.removeAt(idx);
    await _persist();
    return cart;
  }

  Future<void> discard(String id) async {
    await init();
    _items.removeWhere((e) => e.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    await OfflineStore.instance.write(_file, _items.map((e) => e.toJson()).toList());
    notifyListeners();
  }
}
