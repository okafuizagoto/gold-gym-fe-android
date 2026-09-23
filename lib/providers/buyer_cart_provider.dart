import 'package:flutter/foundation.dart';
import '../models/stock_model.dart';

class BuyerCartLine {
  final StockResponse stock;
  int qty;
  BuyerCartLine(this.stock, this.qty);

  double get total => stock.stock_price.toDouble() * qty;
}

/// Keranjang belanja mode pembeli — dipakai bersama menu List Barang
/// (cari & tambah barang) dan menu Point of Sale pembeli (checkout).
/// Keranjang terikat ke satu outlet tujuan; ganti outlet mengosongkan
/// keranjang supaya tidak tercampur barang lintas outlet.
class BuyerCartProvider with ChangeNotifier {
  String _outcode = '';
  String _outletName = '';
  final List<BuyerCartLine> _lines = [];

  String get outcode => _outcode;
  String get outletName => _outletName;
  List<BuyerCartLine> get lines => _lines;
  bool get hasOutlet => _outcode.isNotEmpty;
  int get itemCount => _lines.fold(0, (sum, l) => sum + l.qty);
  double get total => _lines.fold(0, (sum, l) => sum + l.total);

  void selectOutlet(String code, String name) {
    if (code != _outcode) {
      _lines.clear();
    }
    _outcode = code;
    _outletName = name;
    notifyListeners();
  }

  /// Tambah 1 qty; false jika stok tidak cukup (jasa THERAPY tanpa batas).
  bool addItem(StockResponse stock) {
    final existing = _lines.where((l) => l.stock.stock_id == stock.stock_id);
    if (existing.isNotEmpty) {
      if (!stock.isTherapy && existing.first.qty + 1 > stock.stock_qty) {
        return false;
      }
      existing.first.qty++;
    } else {
      if (!stock.isTherapy && stock.stock_qty < 1) return false;
      _lines.add(BuyerCartLine(stock, 1));
    }
    notifyListeners();
    return true;
  }

  void decrease(BuyerCartLine line) {
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
}
