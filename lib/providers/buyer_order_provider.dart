import 'package:flutter/foundation.dart';
import '../models/order_model.dart';

/// Satu baris keranjang pesanan pembeli.
class OrderCartLine {
  final CatalogItem item;
  int qty;
  OrderCartLine(this.item, this.qty);

  double get total => item.price.toDouble() * qty;
}

/// Keranjang alur pesanan pembeli. Terikat ke satu outlet tujuan (beserta
/// gold_id pemilik outlet, wajib karena outlet_code tidak unik global).
/// Ganti outlet mengosongkan keranjang.
class BuyerOrderProvider with ChangeNotifier {
  int _outletGoldId = 0;
  String _outcode = '';
  String _outletName = '';
  final List<OrderCartLine> _lines = [];

  int get outletGoldId => _outletGoldId;
  String get outcode => _outcode;
  String get outletName => _outletName;
  List<OrderCartLine> get lines => _lines;
  bool get hasOutlet => _outcode.isNotEmpty && _outletGoldId > 0;
  int get itemCount => _lines.fold(0, (sum, l) => sum + l.qty);
  double get total => _lines.fold(0, (sum, l) => sum + l.total);

  void selectOutlet(int goldId, String code, String name) {
    if (goldId != _outletGoldId || code != _outcode) {
      _lines.clear();
    }
    _outletGoldId = goldId;
    _outcode = code;
    _outletName = name;
    notifyListeners();
  }

  /// Tambah 1 qty; false jika melebihi stok tersedia.
  bool addItem(CatalogItem item) {
    final existing = _lines.where((l) => l.item.stockId == item.stockId);
    if (existing.isNotEmpty) {
      if (existing.first.qty + 1 > item.stockQty) return false;
      existing.first.qty++;
    } else {
      if (item.stockQty < 1) return false;
      _lines.add(OrderCartLine(item, 1));
    }
    notifyListeners();
    return true;
  }

  void decrease(OrderCartLine line) {
    if (line.qty > 1) {
      line.qty--;
    } else {
      _lines.remove(line);
    }
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  /// Payload lines untuk dikirim ke backend saat checkout.
  List<Map<String, dynamic>> toLinesPayload() {
    return _lines
        .map((l) => {
              "stock_id": l.item.stockId,
              "stock_name": l.item.stockName,
              "qty": l.qty,
              "price": l.item.price,
              "pack": l.item.stockPack,
            })
        .toList();
  }
}
