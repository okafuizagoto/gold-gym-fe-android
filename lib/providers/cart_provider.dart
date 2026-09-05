import 'package:flutter/foundation.dart';
import '../models/sales_item_model.dart';
import '../models/discount_model.dart';
import '../utils/constants.dart';

class CartProvider with ChangeNotifier {
  final List<SalesItemModel> _items = [];
  String _paymentType = ''; // 'TUNAI' | 'BANK' | 'DEBIT' | ''
  double _cashAmount = 0.0;

  /// Diskon aktif per item_id di outlet yang sedang dibuka -- dimuat sekali
  /// saat load stok POS, dipakai auto-apply saat item ditambah ke keranjang.
  final Map<int, DiscountInfo> _activeDiscountsByItemId = {};

  void setActiveDiscounts(Map<int, DiscountInfo> discounts) {
    _activeDiscountsByItemId
      ..clear()
      ..addAll(discounts);
  }

  DiscountInfo? discountForItem(int itemId) => _activeDiscountsByItemId[itemId];

  /// Batalkan diskon pada satu baris keranjang (harga baris kembali normal).
  void cancelDiscountForLine(int index) {
    if (index < 0 || index >= _items.length) return;
    _items[index] = _items[index].copyWithDiscountCancelled();
    notifyListeners();
  }

  /// Diskon TOTAL (persen dari total belanja, auto-aktif per outlet) --
  /// null kalau tidak ada diskon total aktif di outlet ini.
  DiscountInfo? _activeTotalDiscount;
  DiscountInfo? get activeTotalDiscount => _activeTotalDiscount;

  void setActiveTotalDiscount(DiscountInfo? discount) {
    _activeTotalDiscount = discount;
    notifyListeners();
  }

  /// Kode voucher yang diketik kasir + persentase hasil pratinjau (checkvoucher,
  /// TIDAK mengonsumsi) -- persen baru terisi setelah kasir menekan "Terapkan"
  /// dan kode terbukti valid. Konsumsi sungguhan (sekali pakai) terjadi
  /// server-side saat SIMPAN transaksi.
  String? _voucherCode;
  double? _voucherPercent;
  String? get voucherCode => _voucherCode;
  double? get voucherPercent => _voucherPercent;

  void setVoucherPreview(String code, double percent) {
    _voucherCode = code;
    _voucherPercent = percent;
    notifyListeners();
  }

  void clearVoucher() {
    _voucherCode = null;
    _voucherPercent = null;
    notifyListeners();
  }

  /// Meja yang direservasi kasir di picker POS untuk transaksi ini (lihat
  /// modul meja & meja_picker_sheet.dart). Diisi lewat setMeja() setelah
  /// reserveMeja() sukses, dikirim ke backend sebagai meja_ids saat SIMPAN.
  List<int> _mejaIds = [];
  List<String> _mejaNames = [];
  List<int> get mejaIds => _mejaIds;
  List<String> get mejaNames => _mejaNames;
  bool get hasMeja => _mejaIds.isNotEmpty;

  void setMeja(List<int> ids, List<String> names) {
    _mejaIds = ids;
    _mejaNames = names;
    notifyListeners();
  }

  /// Reset state meja LOKAL saja (tanpa panggilan network) -- release
  /// eksplisit ke backend dilakukan oleh caller (tombol BATAL di
  /// penjualan_screen.dart) SEBELUM memanggil clear()/ini, supaya jalur
  /// SIMPAN yang sukses (meja sudah dikonfirmasi backend lewat
  /// ConfirmSaleMeja) tidak ikut memicu release yang tidak perlu.
  void clearMejaSelectionLocal() {
    _mejaIds = [];
    _mejaNames = [];
    notifyListeners();
  }

  List<SalesItemModel> get items => _items;
  String get paymentType => _paymentType;
  double get cashAmount => _cashAmount;

  /// Jumlah kotor (sesudah diskon per-item, sebelum diskon total & voucher).
  double get total {
    return _items.fold(0, (sum, item) => sum + item.stockTotalSales);
  }

  double get totalDiscountAmount {
    if (_activeTotalDiscount == null) return 0;
    return total * (_activeTotalDiscount!.discountValue / 100);
  }

  /// Total setelah diskon per-item + diskon total -- INI yang dikirim
  /// sebagai sale_transtotal (backend menghitung potongan voucher dari
  /// nilai ini juga, supaya menumpuk secara berurutan, bukan dari total kotor).
  double get payableTotal => total - totalDiscountAmount;

  double get voucherDiscountAmount {
    if (_voucherPercent == null) return 0;
    return payableTotal * (_voucherPercent! / 100);
  }

  /// Jumlah akhir yang benar-benar harus dibayar pelanggan (dipakai untuk
  /// hitung kembalian) -- estimasi sisi klien berdasar pratinjau voucher.
  double get grandTotal => payableTotal - voucherDiscountAmount;

  // Calculate change
  double get change {
    if (_paymentType != AppConstants.paymentCash) return 0;
    if (_cashAmount == 0) return 0;
    return _cashAmount - grandTotal;
  }

  bool get canSave {
    if (_items.isEmpty || _paymentType.isEmpty) return false;
    // nota berisi booking sudah bayar bisa bertotal 0 (harga + potongan)
    final minTotal = _items.any((i) => i.isBooking) ? 0 : 1;
    if (_paymentType == AppConstants.paymentCash) {
      // uang tunai harus cukup
      return _cashAmount >= grandTotal && grandTotal >= minTotal;
    }
    return grandTotal >= minTotal;
  }

  bool get hasItems => _items.isNotEmpty;

  /// booking yang sudah ada di keranjang (mencegah dobel tambah)
  bool hasBooking(String bookingId) =>
      _items.any((i) => i.bookingId == bookingId && bookingId.isNotEmpty);

  /// id booking UNPAID di keranjang — dikirim ke backend supaya booking
  /// ditandai LUNAS dengan sale_id nota gabungan ini
  List<String> get bookingIds => _items
      .where((i) => i.bookingId.isNotEmpty)
      .map((i) => i.bookingId)
      .toSet()
      .toList();

  /// Body request insert sales sesuai format backend:
  /// { "data": { "header": {...}, "detail": [ ...seluruh item cart... ] } }
  Map<String, dynamic> buildInsertPayload({
    required String outcode,
    required String salesPerson,
    String salesCustomer = '',
    // sumber nama customer: PESERTA / CUSTOMER / MANUAL (kosong = tidak dikirim)
    String customerSource = '',
    // toggle tampil customer di nota untuk THERAPY: 'Y'/'N' (default 'Y')
    String customerShow = 'Y',
    // waktu transaksi manual (khusus ADMIN); kosong = waktu sekarang (live)
    String transDate = '',
    String transTime = '',
  }) {
    final paidAmount =
        _paymentType == AppConstants.paymentCash ? _cashAmount : grandTotal;
    return {
      'data': {
        'header': {
          'sale_outcode': outcode,
          // sale_cust_id sengaja tidak dikirim dari sini — backend yang
          // menentukan (gold_id akun BUYER kalau checkout sebagai pembeli,
          // NULL untuk transaksi kasir/walk-in biasa)
          // sale_transtotal = SETELAH diskon per-item & diskon total, SEBELUM
          // voucher (backend hitung potongan voucher dari nilai ini juga saat
          // redeem, supaya menumpuk berurutan -- lihat komentar payableTotal).
          'sale_transtotal': payableTotal.toStringAsFixed(0),
          'sale_transpayment': paidAmount.toStringAsFixed(0),
          'sale_transchange': change.toStringAsFixed(0),
          'sale_salesperson': salesPerson,
          'sale_salescustomer': salesCustomer,
          if (customerSource.isNotEmpty) 'sale_customer_source': customerSource,
          'sale_customer_show': customerShow,
          'sale_paymentyn': 'Y',
          if (_paymentType.isNotEmpty) 'sale_pay_type': _paymentType,
          if (_activeTotalDiscount != null) ...{
            'sale_total_discount_percent':
                _activeTotalDiscount!.discountValue.toStringAsFixed(2),
            'sale_total_discount_amount':
                totalDiscountAmount.toStringAsFixed(0),
          },
          if (_voucherCode != null) 'sale_voucher_code': _voucherCode,
        },
        'detail': _items.map((item) => item.toSaleDetailJson()).toList(),
        if (bookingIds.isNotEmpty) 'booking_ids': bookingIds,
        if (_mejaIds.isNotEmpty) 'meja_ids': _mejaIds,
        if (transDate.isNotEmpty) 'trans_date': transDate,
        if (transTime.isNotEmpty) 'trans_time': transTime,
      },
    };
  }

  void addItem(SalesItemModel item) {
    _items.add(item);
    notifyListeners();
  }

  void updateItemQty(int index, int newQty) {
    if (index >= 0 && index < _items.length) {
      // baris booking (termasuk baris potongan) qty terkunci 1
      if (_items[index].isBooking) return;
      _items[index] = _items[index].copyWithQty(newQty);
      notifyListeners();
    }
  }

  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      final bid = _items[index].bookingId;
      if (bid.isNotEmpty) {
        // baris booking dihapus berpasangan (harga + potongan sudah bayar)
        _items.removeWhere((i) => i.bookingId == bid);
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void setPaymentType(String type) {
    _paymentType = type;
    if (type == AppConstants.paymentBank || type == AppConstants.paymentDebit) {
      _cashAmount = grandTotal; // non-tunai selalu bayar pas
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
    _activeTotalDiscount = null;
    _voucherCode = null;
    _voucherPercent = null;
    // Reset lokal saja -- release ke backend (kalau memang perlu, jalur
    // BATAL) sudah/harus dipanggil terpisah oleh caller SEBELUM clear() ini.
    _mejaIds = [];
    _mejaNames = [];
    notifyListeners();
  }
}
