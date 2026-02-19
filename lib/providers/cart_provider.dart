import 'package:flutter/foundation.dart';
import '../models/sales_item_model.dart';

class CartProvider with ChangeNotifier {
  List<SalesItemModel> _items = [];
  String _paymentType = '';  // 'TUNAI' | 'BANK' | ''
  double _cashAmount = 0.0;

  List<SalesItemModel> get items => _items;
  String get paymentType => _paymentType;
  double get cashAmount => _cashAmount;

  // Calculate total
  double get total {
    return _items.fold(0, (sum, item) => sum + item.stockTotalSales);
  }

  // Calculate change
  double get change {
    if (_paymentType == 'BANK') return 0;
    if (_cashAmount == 0) return 0;
    return _cashAmount - total;
  }

  bool get canSave {
    return _paymentType.isNotEmpty && _cashAmount > 0;
  }

  bool get hasItems => _items.isNotEmpty;

  void addItem(SalesItemModel item) {
    _items.add(item);
    notifyListeners();
  }

  void updateItemQty(int index, int newQty) {
    if (index >= 0 && index < _items.length) {
      _items[index] = _items[index].copyWithQty(newQty);
      notifyListeners();
    }
  }

  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void setPaymentType(String type) {
    _paymentType = type;
    if (type == 'BANK') {
      _cashAmount = total;  // Exact amount for bank transfer
    }
    notifyListeners();
  }

  void setCashAmount(double amount) {
    _cashAmount = amount;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _paymentType = '';
    _cashAmount = 0.0;
    notifyListeners();
  }
}
