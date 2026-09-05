import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/private_route.dart';
import '../widgets/modal_wrapper.dart';
import '../widgets/currency_input.dart';
import '../widgets/meja_picker_sheet.dart';
import '../services/meja_api.dart';
import '../services/stock_api.dart';
import '../services/sales_api.dart';
import '../services/booking_api.dart';
import '../services/customer_api.dart';
import '../services/discount_api.dart';
import '../services/items_api.dart';
import '../models/stock_model.dart';
import '../models/sales_item_model.dart';
import '../models/discount_model.dart';
import '../models/booking_model.dart';
import '../providers/cart_provider.dart';
import '../providers/language_provider.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../utils/debouncer.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../extensions/string_extension.dart';
import 'payment_success_screen.dart';

// Warna brand aplikasi (samakan dengan lib/config/theme.dart: primaryBlue &
// primaryTeal) supaya layar ini tetap satu bahasa visual dengan layar lain.
const Color _kBrandBlue = Color(0xFF267BE4);
const Color _kBrandTeal = Color(0xFF6DBAB9);

class PenjualanScreen extends StatefulWidget {
  const PenjualanScreen({super.key});

  @override
  State<PenjualanScreen> createState() => _PenjualanScreenState();
}

class _PenjualanScreenState extends State<PenjualanScreen> {
  final _salesApi = SalesApi();
  final _discountApi = DiscountApi();
  final _bookingApi = BookingApi();
  final _mejaApi = MejaApi();
  final _debouncer = Debouncer(milliseconds: 400);

  // outlet THERAPY: booking terapi bisa ditambahkan sebagai item nota
  String _outletType = 'RETAIL';

  // jumlah pelanggan terakhir diisi saat memilih meja -- dipakai lagi kalau
  // picker meja dibuka ulang untuk edit pilihan (tidak tanya ulang).
  int _lastMejaCustomerCount = 0;

  // Referensi CartProvider untuk best-effort release meja di dispose() kalau
  // layar ditinggal tanpa BATAL/SIMPAN (lihat _releaseMejaOnLeave).
  late CartProvider _cartRef;

  // ADMIN bisa memilih tanggal & jam transaksi sendiri (default: live/sekarang)
  bool _isAdmin = false;
  DateTime? _customTransAt; // null = waktu sekarang (live)

  // foto bukti pembayaran (wajib untuk Transfer Bank, maks 5 MB);
  // diupload setelah transaksi tersimpan (butuh sale_id)
  File? _proofImage;

  // admin bisa menyembunyikan fitur upload bukti pembayaran (global/per
  // outlet/per user) lewat menu Akses Admin > Visibilitas Bukti Pembayaran.
  // Default true supaya tidak berubah sebelum status terkonfirmasi dari server.
  bool _proofFeatureEnabled = true;

  // 0 = Katalog, 1 = Manual, 2 = Pesanan (tab tampilan POS)
  int _activeTab = 0;

  // Input harga bebas di tab Manual (digit mentah, tanpa pemisah ribuan)
  String _manualPriceDigits = '';
  bool _manualShowNote = false;
  final _manualNoteController = TextEditingController();

  /// Pilih foto bukti pembayaran dari kamera/galeri, validasi maks 5 MB.
  Future<File?> _pickProofImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Foto Bukti Pembayaran'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ImageSource.camera),
            child: const Row(children: [
              Icon(Icons.photo_camera),
              SizedBox(width: 8),
              Text('Ambil dari Kamera'),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ImageSource.gallery),
            child: const Row(children: [
              Icon(Icons.photo_library),
              SizedBox(width: 8),
              Text('Pilih dari Galeri'),
            ]),
          ),
        ],
      ),
    );
    if (source == null) return null;

    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return null;
    final file = File(picked.path);
    final size = await file.length();
    if (size > 5 * 1024 * 1024) {
      if (mounted) Toast.error(context, 'Ukuran foto maksimal 5 MB');
      return null;
    }
    return file;
  }

  /// Upload bukti transfer setelah nota tersimpan; kuota penyimpanan penuh
  /// (10 GB) memunculkan alert "tolong hubungi admin".
  Future<void> _uploadProof(String saleId, File file) async {
    try {
      final response = await _salesApi.uploadPaymentProof(saleId, file);
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) Toast.success(context, 'Bukti pembayaran terupload');
        return;
      }
      String message = 'Gagal upload bukti pembayaran';
      try {
        message = jsonDecode(response.body)['error'] ?? message;
      } catch (_) {}
      if (!mounted) return;
      if (message.toLowerCase().contains('hubungi admin')) {
        await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Penyimpanan Penuh'),
            content: Text(message),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        Toast.error(context, message);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal upload bukti pembayaran');
    }
  }

  // Form controllers
  final _receiptController = TextEditingController();
  final _transactionDateController = TextEditingController();
  final _salesPersonController = TextEditingController();
  final _typeController = TextEditingController();

  // Customer POS: sumber nama customer (PESERTA/CUSTOMER/MANUAL),
  // toggle tampil di nota (khusus THERAPY), dan wajib-isi (khusus RETAIL,
  // kecuali admin membuka akses "POS tanpa customer").
  String _customerMode = 'MANUAL';
  bool _customerShow = true;
  bool _customerRequired = false;

  // Katalog: pencarian produk (tab Katalog)
  final _catalogSearchController = TextEditingController();

  // Add product modal controllers (dipakai modal "Opsi" -- cari + harga custom)
  final _itemCodeController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _qtyController = TextEditingController();
  // Payment modal controllers
  final _cashAmountController = TextEditingController();
  final _voucherCodeController = TextEditingController();
  final _salesNameController = TextEditingController();
  final _salesStockIDController = TextEditingController();

  // Harga custom (opsi penjual/admin): default pakai harga item,
  // bisa diganti dengan harga input sendiri per baris penjualan.
  final _customPriceController = TextEditingController();
  bool _useCustomPrice = false;

  StockResponse? _selectedStock;

  int lengths = 5;
  int pages = 1;

  bool _isLoadingSuggestions = false;
  bool _isSaving = false;

  ValueNotifier<StockPagination?> stockPaginationNotifier = ValueNotifier(null);

  TextEditingController? _autoCompleteController;
  FocusNode _autoCompleteFocusNode = FocusNode();

  /// Header auth untuk Image.network foto item di kartu katalog -- diambil
  /// sekali di initState supaya tidak refetch tiap rebuild list.
  Map<String, String> _photoHeaders = {};

  @override
  void initState() {
    super.initState();
    _transactionDateController.text = DateTime.now().toString();
    _loadUserName();
    _typeController.text = 'Cash';
    // prefetch daftar stok untuk katalog & autocomplete tambah produk
    getAllStock('', 1, 200);
    ItemsApi().getAuthHeaders().then((headers) {
      if (mounted) setState(() => _photoHeaders = headers);
    });
  }

  Future<void> _loadUserName() async {
    final name = await Storage.get('userNIP');
    final outletType =
        await Storage.get(AppConstants.outletTypeKey) ?? 'RETAIL';
    final role = await Storage.get(AppConstants.userRoleKey) ?? '';
    // apakah outlet ini wajib mengisi customer (RETAIL & belum dibuka akses admin)
    bool required = false;
    if (outletType != AppConstants.outletTherapy) {
      final outcode = await Storage.get(AppConstants.outcode) ?? '';
      if (outcode.isNotEmpty) {
        try {
          final r = await SalesApi().customerRequired(outcode);
          if (r.statusCode == 200) {
            required = jsonDecode(r.body)['required'] == true;
          }
        } catch (_) {}
      }
    }
    // visibilitas fitur bukti pembayaran (admin bisa matikan global/per
    // outlet/per user) — gagal load dianggap aktif (default aman)
    bool proofEnabled = true;
    try {
      final outcode = await Storage.get(AppConstants.outcode) ?? '';
      final r = await SalesApi().getProofVisibility(outcode);
      if (r.statusCode == 200) {
        proofEnabled = jsonDecode(r.body)['enabled'] != false;
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _salesPersonController.text = name?.toTitleCase() ?? 'Guest';
      _outletType = outletType;
      _isAdmin = role == AppConstants.roleAdmin;
      _customerRequired = required;
      _proofFeatureEnabled = proofEnabled;
    });
  }

  // ---------- Pemilih customer (POS) ----------

  /// Field customer POS: 3 sumber (Data Peserta / Customer / Ketik) + wajib
  /// untuk RETAIL; untuk THERAPY ada toggle tampilkan-nama-di-nota.
  Widget _buildCustomerField(LanguageProvider langProvider) {
    final isTherapy = _outletType == AppConstants.outletTherapy;
    final manual = _customerMode == 'MANUAL';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Data Peserta'),
              selected: _customerMode == 'PESERTA',
              onSelected: (_) {
                setState(() => _customerMode = 'PESERTA');
                _pickPeserta();
              },
            ),
            ChoiceChip(
              label: const Text('Customer'),
              selected: _customerMode == 'CUSTOMER',
              onSelected: (_) {
                setState(() => _customerMode = 'CUSTOMER');
                _pickCustomer();
              },
            ),
            ChoiceChip(
              label: const Text('Ketik'),
              selected: manual,
              onSelected: (_) => setState(() => _customerMode = 'MANUAL'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _receiptController,
          readOnly: !manual,
          style: const TextStyle(fontSize: 13),
          onTap: manual
              ? null
              : () => _customerMode == 'PESERTA' ? _pickPeserta() : _pickCustomer(),
          decoration: InputDecoration(
            isDense: true,
            labelText: (_customerRequired && !isTherapy)
                ? '${langProvider.get('Customer Name', 'Nama Customer')} *'
                : langProvider.get('Customer Name', 'Nama Customer'),
            border: const OutlineInputBorder(),
            suffixIcon: manual
                ? null
                : const Icon(Icons.search),
          ),
        ),
        if (isTherapy) ...[
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Tampilkan nama customer di nota'),
            value: _customerShow,
            onChanged: (v) => setState(() => _customerShow = v),
          ),
        ],
      ],
    );
  }

  Future<void> _pickPeserta() async {
    final picked = await _pickFromApi(
      title: 'Pilih Data Peserta',
      fetch: (q) async {
        final r = await BookingApi().searchBuyers(q);
        if (r.statusCode != 200) return [];
        final data = (jsonDecode(r.body)['data'] ?? []) as List;
        return data.map<_CustPick>((e) {
          final toko = (e['gold_toko'] ?? '').toString();
          final nama = (e['gold_nama'] ?? '').toString();
          return _CustPick(
              toko.isNotEmpty ? toko : nama, nama.isNotEmpty ? nama : toko);
        }).toList();
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _receiptController.text = picked;
        _customerMode = 'PESERTA';
      });
    }
  }

  Future<void> _pickCustomer() async {
    final outcode = await Storage.get(AppConstants.outcode) ?? '';
    if (!mounted) return;
    final picked = await _pickFromApi(
      title: 'Pilih Customer',
      fetch: (q) async {
        final r = await CustomerApi().getAllCustomer(q, outcode);
        if (r.statusCode != 200) return [];
        final data = (jsonDecode(r.body)['data'] ?? []) as List;
        return data.map<_CustPick>((e) {
          final nama = (e['cust_name'] ?? '').toString();
          final toko = (e['cust_outlet_name'] ?? '').toString();
          return _CustPick(nama.isNotEmpty ? nama : toko, toko);
        }).toList();
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _receiptController.text = picked;
        _customerMode = 'CUSTOMER';
      });
    }
  }

  /// Dialog pencarian generik: mengembalikan nama terpilih (atau null).
  Future<String?> _pickFromApi({
    required String title,
    required Future<List<_CustPick>> Function(String query) fetch,
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final searchCtl = TextEditingController();
        List<_CustPick> items = [];
        bool loading = true;
        return StatefulBuilder(builder: (ctx, setLocal) {
          Future<void> run(String q) async {
            setLocal(() => loading = true);
            final res = await fetch(q);
            setLocal(() {
              items = res;
              loading = false;
            });
          }

          if (loading && items.isEmpty && searchCtl.text.isEmpty) {
            run('');
          }
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtl,
                    decoration: const InputDecoration(
                      labelText: 'Cari',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onSubmitted: run,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 260,
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : items.isEmpty
                            ? const Center(child: Text('Tidak ada data'))
                            : ListView.builder(
                                itemCount: items.length,
                                itemBuilder: (c, i) => ListTile(
                                  dense: true,
                                  title: Text(items[i].name),
                                  subtitle: items[i].sub.isEmpty
                                      ? null
                                      : Text(items[i].sub),
                                  onTap: () =>
                                      Navigator.pop(dialogContext, items[i].name),
                                ),
                              ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal')),
            ],
          );
        });
      },
    );
  }

  // ---------- Waktu transaksi (khusus ADMIN) ----------

  String get _transLabel => _customTransAt == null
      ? DateTime.now().toString()
      : DateFormat('dd-MM-yyyy HH:mm').format(_customTransAt!);

  /// Modal ADMIN: pakai waktu sekarang (live) atau pilih tanggal & jam sendiri.
  Future<void> _showTransTimePicker() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Waktu Transaksi'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'live'),
            child: Row(
              children: [
                Icon(Icons.access_time,
                    color: _customTransAt == null ? Colors.teal : Colors.grey),
                const SizedBox(width: 8),
                const Text('Sekarang (live)'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'custom'),
            child: Row(
              children: [
                Icon(Icons.edit_calendar,
                    color: _customTransAt != null ? Colors.teal : Colors.grey),
                const SizedBox(width: 8),
                const Text('Pilih tanggal & jam'),
              ],
            ),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'live') {
      setState(() {
        _customTransAt = null;
        _transactionDateController.text = _transLabel;
      });
      return;
    }

    final base = _customTransAt ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;

    setState(() {
      _customTransAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _transactionDateController.text = _transLabel;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cartRef = Provider.of<CartProvider>(context, listen: false);
  }

  /// Best-effort: kalau layar POS ditinggalkan (back button dsb) TANPA lewat
  /// BATAL atau SIMPAN sukses (keduanya sudah mengosongkan mejaIds duluan),
  /// lepas reservasi meja yang masih tersisa supaya tidak "nyangkut" ISI.
  /// Sengaja tidak di-await -- dispose() tidak boleh async.
  void _releaseMejaOnLeave() {
    final ids = _cartRef.mejaIds;
    if (ids.isEmpty) return;
    Storage.get(AppConstants.outcode).then((outcode) {
      if (outcode != null && outcode.isNotEmpty) {
        _mejaApi.releaseMeja(outcode, ids);
      }
    });
  }

  @override
  void dispose() {
    _releaseMejaOnLeave();
    _receiptController.dispose();
    _transactionDateController.dispose();
    _salesPersonController.dispose();
    _typeController.dispose();
    _catalogSearchController.dispose();
    _itemCodeController.dispose();
    _itemNameController.dispose();
    _qtyController.dispose();
    _cashAmountController.dispose();
    _voucherCodeController.dispose();
    _customPriceController.dispose();
    _manualNoteController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> getAllStock(String name, int page, int length) async {
    try {
      final outcode = await Storage.get(AppConstants.outcode) ?? '';
      final stockApi = StockApi();

      final response = await stockApi.getAllStock(name, outcode, page, length);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // final pagination = ItemPagination.fromJson(data);
        final pagination = StockPagination.fromJson(data);

        stockPaginationNotifier.value = pagination;

        pages = page;
        lengths = length;

        // Muat diskon aktif outlet ini sekali per load stok -- dipakai
        // auto-apply saat item ditambah ke keranjang (lihat _addToCart).
        _loadActiveDiscounts(outcode);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to fetch items"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error fetching items"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadActiveDiscounts(String outcode) async {
    try {
      final resp = await _discountApi.getActiveByOutlet(outcode);
      if (resp.statusCode != 200) return;
      final rows = (jsonDecode(resp.body)['data'] as List? ?? []);
      final map = <int, DiscountInfo>{};
      DiscountInfo? totalDiscount;
      for (final row in rows) {
        final d = DiscountResponse.fromJson(row);
        if (d.isTotalScope) {
          totalDiscount ??= DiscountInfo.fromDiscountResponse(d);
          continue;
        }
        map[d.discountItemId] = DiscountInfo.fromDiscountResponse(d);
      }
      if (!mounted) return;
      Provider.of<CartProvider>(context, listen: false)
          .setActiveTotalDiscount(totalDiscount);
      Provider.of<CartProvider>(context, listen: false)
          .setActiveDiscounts(map);
    } catch (_) {
      // gagal muat diskon aktif -- POS tetap jalan tanpa auto-apply diskon
    }
  }

  // ---------- Booking terapi sebagai item nota POS ----------

  // Harga default per tipe & durasi (fallback jika item tidak ada di stok)
  static const Map<String, Map<int, int>> _defaultTherapyPrices = {
    AppConstants.therapySofa: {30: 15000, 60: 25000},
    AppConstants.therapyDragon: {30: 25000, 60: 35000},
    AppConstants.therapyKursi: {30: 10000, 60: 20000},
  };

  String _therapyItemName(String type, int duration) {
    String prefix = 'SOFA';
    if (type == AppConstants.therapyDragon) {
      prefix = 'KURSI DRAGON';
    } else if (type == AppConstants.therapyKursi) {
      prefix = 'KURSI';
    }
    return duration == 60 ? '$prefix 1 JAM' : '$prefix 30 MENIT';
  }

  StockResponse? _findTherapyStock(String type, int duration) {
    final name = _therapyItemName(type, duration);
    for (final st in stockPaginationNotifier.value?.data ?? <StockResponse>[]) {
      if (st.stock_name.toUpperCase() == name) return st;
    }
    return null;
  }

  /// Booking satu tanggal (PAID & UNPAID) — booking 1 jam muncul di 2 jendela
  /// slot, jadi di-dedup berdasarkan booking_id.
  Future<List<SlotBookingModel>> _fetchBookingsFor(DateTime date) async {
    final outcode = await Storage.get(AppConstants.outcode) ?? '';
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final response = await _bookingApi.getSlots(outcode, dateStr);
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat booking');
    }
    final data = jsonDecode(response.body);
    final seen = <String>{};
    final result = <SlotBookingModel>[];
    for (final s in (data['data'] ?? []) as List) {
      final slot = SlotModel.fromJson(s);
      for (final b in slot.bookings) {
        if (seen.add(b.bookingId)) result.add(b);
      }
    }
    return result;
  }

  /// Tambah booking ke keranjang:
  /// - BELUM BAYAR: satu baris dengan harga booking (custom tersimpan atau
  ///   default) — ikut ditagih & booking otomatis LUNAS di nota ini.
  /// - SUDAH BAYAR: dua baris — harga (mis. 15.000) dan potongan -(15.000)
  ///   sehingga netto 0; yang ditagih hanya barang lain di keranjang.
  bool _addBookingToCart(CartProvider cart, SlotBookingModel b, DateTime date) {
    if (cart.hasBooking(b.bookingId)) {
      Toast.info(context, 'Booking sudah ada di keranjang');
      return false;
    }
    final stock = _findTherapyStock(b.therapyType, b.duration);
    if (stock == null && b.therapyType.isEmpty) {
      Toast.error(context, 'Booking lama tanpa tipe terapi — bayar dari menu Booking');
      return false;
    }
    if (stock == null) {
      Toast.error(context,
          'Item ${_therapyItemName(b.therapyType, b.duration)} tidak ditemukan di stok');
      return false;
    }

    double price = b.price > 0
        ? b.price.toDouble()
        : stock.stock_price.toDouble();
    if (price <= 0) {
      price = (_defaultTherapyPrices[b.therapyType]?[b.duration] ?? 0)
          .toDouble();
    }
    final label =
        '${stock.stock_name} (Booking ${DateFormat('dd-MM').format(date)} ${b.start} - ${b.custName})';
    final pack = stock.stock_pack.isEmpty ? 'SESI' : stock.stock_pack;

    cart.addItem(SalesItemModel.create(
      stockId: stock.stock_id,
      stockCode: stock.stock_item_id.toString(),
      stockName: b.isPaid ? '$label (SUDAH BAYAR)' : label,
      qty: 1,
      stockPack: pack,
      price: price,
      bookingId: b.bookingId,
      isBooking: true,
    ));
    if (b.isPaid) {
      // baris potongan: -(harga) supaya total booking yang sudah dibayar = 0
      cart.addItem(SalesItemModel.create(
        stockId: stock.stock_id,
        stockCode: stock.stock_item_id.toString(),
        stockName: 'POTONGAN SUDAH BAYAR (${b.custName} ${b.start})',
        qty: 1,
        stockPack: pack,
        price: -price,
        bookingId: b.bookingId,
        isBooking: true,
      ));
    }
    return true;
  }

  /// Modal daftar booking per tanggal (default hari ini, bisa pilih tanggal
  /// lain): kuning = belum bayar (bisa ditagih di nota ini), merah = sudah
  /// bayar (masuk nota dengan potongan, netto 0).
  void _showBookingPickerModal(
      BuildContext context, LanguageProvider langProvider, CartProvider cart) {
    // pastikan stok termuat untuk lookup harga item terapi
    getAllStock('', 1, 200);

    // ikuti tanggal transaksi yang dipilih admin (custom); default hari ini (live)
    DateTime pickerDate = _customTransAt ?? DateTime.now();
    Future<List<SlotBookingModel>>? future;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(builder: (context, setSheetState) {
          future ??= _fetchBookingsFor(pickerDate);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Booking Terapi',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      // pilih tanggal booking (default hari ini)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label:
                            Text(DateFormat('dd-MM-yyyy').format(pickerDate)),
                        onPressed: () async {
                          // rentang disamakan dengan pemilih waktu transaksi
                          // (±1 tahun) agar tanggal custom admin selalu valid
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: pickerDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 365)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setSheetState(() {
                              pickerDate = picked;
                              future = _fetchBookingsFor(pickerDate);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: FutureBuilder<List<SlotBookingModel>>(
                    future: future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: Text('Gagal memuat booking')),
                        );
                      }
                      final bookings = snapshot.data ?? [];
                      if (bookings.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                              child: Text('Belum ada booking tanggal '
                                  '${DateFormat('dd-MM-yyyy').format(pickerDate)}')),
                        );
                      }
                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...bookings.map((b) {
                              final inCart = cart.hasBooking(b.bookingId);
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                decoration: BoxDecoration(
                                  color: b.isPaid
                                      ? Colors.red.shade100
                                      : Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: b.isPaid
                                          ? Colors.red.shade400
                                          : Colors.amber.shade400),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(
                                    b.isPaid
                                        ? Icons.check_circle
                                        : Icons.hourglass_bottom,
                                    color: b.isPaid
                                        ? Colors.red.shade700
                                        : Colors.amber.shade800,
                                  ),
                                  title: Text(
                                    '${b.custName} • ${b.start}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                      '${b.therapyLabel.isNotEmpty ? "${b.therapyLabel} • " : ""}'
                                      '${b.duration} menit • '
                                      '${b.isPaid ? "SUDAH BAYAR (masuk nota Rp0)" : "BELUM BAYAR"}'),
                                  trailing: ElevatedButton(
                                    onPressed: inCart
                                        ? null
                                        : () {
                                            if (_addBookingToCart(
                                                cart, b, pickerDate)) {
                                              setSheetState(() {});
                                              Toast.success(this.context,
                                                  'Booking masuk keranjang');
                                            }
                                          },
                                    child: Text(inCart ? 'SUDAH' : 'TAMBAH'),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showAddProductModal(
      BuildContext context, LanguageProvider langProvider) {
    _itemCodeController.clear();
    _itemNameController.clear();
    _qtyController.clear();
    _customPriceController.clear();
    _useCustomPrice = false;
    _selectedStock = null;

    // refresh stok terbaru setiap buka modal
    getAllStock('', 1, 200);

    showModalDialog(
      context: context,
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                langProvider.get('Add Product', 'Tambah Produk'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Autocomplete cari produk
              Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<StockPagination?>(
                      valueListenable: stockPaginationNotifier,
                      builder: (context, pagination, _) {
                        return Autocomplete<StockResponse>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            final items =
                                stockPaginationNotifier.value?.data ?? [];

                            final query = textEditingValue.text.toLowerCase();
                            if (textEditingValue.text.isEmpty) {
                              return items;
                            }
                            return items.where((item) => item.stock_name
                                .toLowerCase()
                                .contains(query));
                          },
                          displayStringForOption: (option) => option.stock_name,
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                child: Container(
                                  width: 500,
                                  constraints:
                                      const BoxConstraints(maxHeight: 200),
                                  child: _isLoadingSuggestions
                                      ? const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            ),
                                          ),
                                        )
                                      : options.isEmpty
                                          ? const ListTile(
                                              leading: Icon(Icons.search_off),
                                              title: Text('Tidak ada hasil'),
                                            )
                                          : ListView.separated(
                                              padding: EdgeInsets.zero,
                                              itemCount: options.length,
                                              separatorBuilder: (_, __) =>
                                                  const Divider(height: 1),
                                              itemBuilder: (context, index) {
                                                final suggestion =
                                                    options.elementAt(index);
                                                return ListTile(
                                                  dense: true,
                                                  leading: const Icon(
                                                      Icons.inventory_2),
                                                  title: Text(
                                                      suggestion.stock_name),
                                                  subtitle: Text(
                                                    suggestion.isTherapy
                                                        ? 'Jasa | ${TextFormatter.formatRupiah(suggestion.stock_price.toDouble())}'
                                                        : 'Stok: ${suggestion.stock_qty} | ${TextFormatter.formatRupiah(suggestion.stock_price.toDouble())}',
                                                  ),
                                                  onTap: () =>
                                                      onSelected(suggestion),
                                                );
                                              },
                                            ),
                                ),
                              ),
                            );
                          },
                          onSelected: (StockResponse selection) {
                            setModalState(() {
                              _selectedStock = selection;
                              _itemNameController.text = selection.stock_name;
                              _salesNameController.text = selection.stock_name;
                              _salesStockIDController.text =
                                  selection.stock_id;
                            });
                            _autoCompleteController?.text =
                                selection.stock_name;
                            _autoCompleteFocusNode.unfocus();
                          },
                          fieldViewBuilder: (context, controller, focusNode,
                              onFieldSubmitted) {
                            _autoCompleteController = controller;
                            _autoCompleteFocusNode = focusNode;
                            return TextField(
                              controller: controller,
                              focusNode: _autoCompleteFocusNode,
                              decoration: InputDecoration(
                                hintText: langProvider.get(
                                    'Enter name', 'Masukkan nama'),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (value) {
                                _debouncer
                                    .run(() => getAllStock(value, 1, 200));
                              },
                            );
                          },
                        );
                      },
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),

              // Item Name (disabled)
              TextField(
                controller: _itemNameController,
                enabled: false,
                decoration: InputDecoration(
                  labelText: langProvider.get('Item Name', 'Nama Barang'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Harga (informasi) + opsi harga custom
              if (_selectedStock != null) ...[
                Text(
                  '${langProvider.get('Price', 'Harga')}: ${TextFormatter.formatRupiah(_selectedStock!.stock_price.toDouble())}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      langProvider.get('Custom price', 'Harga custom')),
                  subtitle: Text(_useCustomPrice
                      ? langProvider.get(
                          'Enter your own price', 'Input harga sendiri')
                      : langProvider.get(
                          'Use default price', 'Pakai harga default')),
                  value: _useCustomPrice,
                  onChanged: (v) => setModalState(() => _useCustomPrice = v),
                ),
                if (_useCustomPrice)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      controller: _customPriceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: langProvider.get(
                            'Custom price (Rp)', 'Harga custom (Rp)'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],

              // Quantity
              TextField(
                controller: _qtyController,
                enabled: _selectedStock != null,
                keyboardType: TextInputType.number,
                onChanged: (_) => setModalState(() {}),
                decoration: InputDecoration(
                  labelText: langProvider.get('Quantity', 'Jumlah'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(langProvider.get('CANCEL', 'BATAL')),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedStock != null &&
                            (int.tryParse(_qtyController.text) ?? 0) > 0
                        ? () {
                            _addToCart(context);
                            Navigator.pop(context);
                          }
                        : null,
                    child: Text(langProvider.get('OK', 'OK')),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// Rakit satu baris SalesItemModel dari stok + qty (opsional harga custom),
  /// termasuk validasi stok & auto-apply diskon aktif -- logika inti yang
  /// dipakai baik oleh modal "Opsi" (_addToCart) maupun quick add/remove di
  /// tab Katalog, supaya keduanya berperilaku identik.
  SalesItemModel? _buildSalesItem(
      BuildContext context, StockResponse stock, int qty,
      {double? customPrice}) {
    if (qty <= 0) return null;

    // item jasa (brand THERAPY) tidak dibatasi stok
    if (!stock.isTherapy && qty > stock.stock_qty) {
      Toast.error(
        context,
        'Stok tidak cukup (tersisa ${stock.stock_qty})',
      );
      return null;
    }

    final useCustom = customPrice != null;
    double price = stock.stock_price.toDouble();
    if (useCustom) {
      if (customPrice <= 0) {
        Toast.error(context, 'Isi harga custom yang valid');
        return null;
      }
      price = customPrice;
    }

    final cart = Provider.of<CartProvider>(context, listen: false);

    // Diskon otomatis aktif kalau item ini punya diskon aktif -- dilewati
    // kalau kasir sedang pakai harga custom (harga custom = keputusan manual
    // kasir, tidak ditimpa diskon otomatis).
    int? discountId;
    String? discountType;
    double? discountValue;
    double? discountAmount;
    DateTime? discountCreatedAt;
    final originalPrice = price;
    if (!useCustom) {
      final disc = cart.discountForItem(stock.stock_item_id);
      if (disc != null) {
        discountId = disc.discountId;
        discountType = disc.discountType;
        discountValue = disc.discountValue;
        discountCreatedAt = disc.discountCreatedAt;
        final perUnitDiscount = disc.discountType == 'PERCENT'
            ? price * (disc.discountValue / 100)
            : disc.discountValue;
        final discountedPrice = (price - perUnitDiscount).clamp(0, price);
        discountAmount = (price - discountedPrice) * qty;
        price = discountedPrice.toDouble();
      }
    }

    return SalesItemModel.create(
      stockId: stock.stock_id,
      stockCode: stock.stock_item_id.toString(),
      stockName: stock.stock_name,
      qty: qty,
      stockPack: stock.stock_pack,
      price: price,
      discountId: discountId,
      discountType: discountType,
      discountValue: discountValue,
      discountAmount: discountAmount,
      discountCreatedAt: discountCreatedAt,
      originalStockPrice: discountId != null ? originalPrice : null,
    );
  }

  void _addToCart(BuildContext context) {
    if (_selectedStock == null) return;

    final qty = int.tryParse(_qtyController.text) ?? 0;
    double? customPrice;
    if (_useCustomPrice) {
      customPrice = (int.tryParse(_customPriceController.text
                  .replaceAll('.', '')
                  .replaceAll(',', '')) ??
              0)
          .toDouble();
    }

    final item = _buildSalesItem(context, _selectedStock!, qty,
        customPrice: customPrice);
    if (item == null) return;

    Provider.of<CartProvider>(context, listen: false).addItem(item);
  }

  /// Total qty produk [stock] yang sudah ada di keranjang (badge stepper
  /// katalog); baris booking tidak dihitung (booking tidak bisa diubah dari
  /// katalog, hanya dari modal Booking).
  int _cartQtyFor(CartProvider cart, StockResponse stock) {
    int total = 0;
    for (final i in cart.items) {
      if (i.stockId == stock.stock_id && !i.isBooking) total += i.stockQty;
    }
    return total;
  }

  /// Tambah cepat dari katalog: gabung ke baris yang sama kalau sudah ada
  /// (qty + 1), atau buat baris baru dengan harga default (diskon aktif
  /// tetap otomatis diterapkan lewat _buildSalesItem).
  void _quickAdd(StockResponse stock) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final idx =
        cart.items.indexWhere((i) => i.stockId == stock.stock_id && !i.isBooking);
    if (idx != -1) {
      final newQty = cart.items[idx].stockQty + 1;
      if (!stock.isTherapy && newQty > stock.stock_qty) {
        Toast.error(context, 'Stok tidak cukup (tersisa ${stock.stock_qty})');
        return;
      }
      cart.updateItemQty(idx, newQty);
      return;
    }
    final item = _buildSalesItem(context, stock, 1);
    if (item != null) cart.addItem(item);
  }

  /// Kurangi cepat dari katalog: qty - 1, atau hapus baris kalau sudah 1.
  void _quickRemove(StockResponse stock) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final idx =
        cart.items.indexWhere((i) => i.stockId == stock.stock_id && !i.isBooking);
    if (idx == -1) return;
    final currentQty = cart.items[idx].stockQty;
    if (currentQty <= 1) {
      cart.removeItem(idx);
    } else {
      cart.updateItemQty(idx, currentQty - 1);
    }
  }

  /// Dialog ketik jumlah persis untuk satu baris keranjang (tab Pesanan) --
  /// pengganti input inline lama, jumlah 0 = hapus baris.
  Future<void> _editQtyDialog(
      BuildContext context, CartProvider cart, int index, int currentQty) async {
    final ctl = TextEditingController(text: '$currentQty');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ubah Jumlah'),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, int.tryParse(ctl.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (result <= 0) {
      cart.removeItem(index);
    } else {
      cart.updateItemQty(index, result);
    }
  }

  /// Pratinjau kode voucher (TIDAK mengonsumsi) -- kalau valid, terapkan ke
  /// CartProvider supaya total/kembalian terkoreksi sebelum kasir input tunai.
  Future<void> _applyVoucher(
      CartProvider cart, void Function(void Function()) setModalState) async {
    final code = _voucherCodeController.text.trim();
    if (code.isEmpty) {
      Toast.error(context, 'Isi kode voucher terlebih dahulu');
      return;
    }
    try {
      final outcode = await Storage.get(AppConstants.outcode) ?? '';
      final resp = await _discountApi.checkVoucher(outcode, code);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body)['data'];
        final percent = (data['voucher_percent'] ?? 0).toDouble();
        cart.setVoucherPreview(code.toUpperCase(), percent);
        setModalState(() {});
      } else {
        final data = jsonDecode(resp.body);
        if (mounted) {
          Toast.error(
              context, data['error']?.toString() ?? 'Kode voucher tidak valid');
        }
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memeriksa kode voucher');
    }
  }

  void _showPaymentModal(
      BuildContext context, LanguageProvider langProvider, CartProvider cart) {
    _cashAmountController.clear();
    _proofImage = null;

    showModalDialog(
      context: context,
      child: StatefulBuilder(builder: (context, setModalState) {
        final isBank = cart.paymentType == AppConstants.paymentBank;
        // Transfer Bank wajib melampirkan foto bukti pembayaran — KECUALI
        // admin menyembunyikan fitur ini (Akses Admin > Visibilitas Bukti
        // Pembayaran), maka tidak ada cara upload jadi tidak diwajibkan.
        final canConfirm = cart.canSave &&
            (!isBank || !_proofFeatureEnabled || _proofImage != null);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              langProvider.get('Payment', 'Pembayaran'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Jenis pembayaran: Tunai atau Transfer Bank
            DropdownButtonFormField<String>(
              value: cart.paymentType.isEmpty ? null : cart.paymentType,
              decoration: InputDecoration(
                labelText: langProvider.get('Payment Type', 'Jenis Pembayaran'),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: AppConstants.paymentCash,
                  child: Text(langProvider.get('Cash', 'Tunai')),
                ),
                DropdownMenuItem(
                  value: AppConstants.paymentBank,
                  child:
                      Text(langProvider.get('Bank Transfer', 'Transfer Bank')),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  cart.setPaymentType(value);
                  setModalState(() {});
                }
              },
            ),
            const SizedBox(height: 16),

            // Kode voucher (opsional) -- pratinjau dulu (tidak konsumsi),
            // baru benar-benar dipakai/dikonsumsi saat SIMPAN transaksi.
            if (cart.voucherCode == null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _voucherCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText:
                            langProvider.get('Voucher code', 'Kode Voucher'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _applyVoucher(cart, setModalState),
                    child: Text(langProvider.get('Apply', 'Terapkan')),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Icon(Icons.confirmation_number,
                        size: 18, color: Colors.green[700]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          '${cart.voucherCode} (${cart.voucherPercent!.toStringAsFixed(0)}%) diterapkan'),
                    ),
                    TextButton(
                      onPressed: () {
                        cart.clearVoucher();
                        _voucherCodeController.clear();
                        setModalState(() {});
                      },
                      child: Text(langProvider.get('Remove', 'Hapus')),
                    ),
                  ],
                ),
              ),

            // Cash Amount (only for TUNAI)
            if (cart.paymentType == AppConstants.paymentCash)
              CurrencyInput(
                controller: _cashAmountController,
                labelText: langProvider.get('Amount', 'Jumlah'),
                onChanged: (value) {
                  cart.setCashAmount(value);
                  setModalState(() {});
                },
              ),

            // Transfer Bank: upload foto bukti pembayaran (maks 5 MB) —
            // disembunyikan jika admin menonaktifkan fitur ini
            if (isBank && _proofFeatureEnabled) ...[
              OutlinedButton.icon(
                icon: Icon(_proofImage == null
                    ? Icons.upload_file
                    : Icons.check_circle),
                label: Text(_proofImage == null
                    ? 'UPLOAD FOTO BUKTI PEMBAYARAN (maks 5 MB)'
                    : 'Bukti terpilih — ganti foto'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _proofImage == null ? Colors.teal : Colors.green,
                ),
                onPressed: () async {
                  final file = await _pickProofImage();
                  if (file != null) {
                    setModalState(() => _proofImage = file);
                  }
                },
              ),
              if (_proofImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _proofImage!,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    cart.setPaymentType('');
                    cart.setCashAmount(0);
                    _proofImage = null;
                    Navigator.pop(context);
                  },
                  child: Text(langProvider.get('CANCEL', 'BATAL')),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed:
                      canConfirm ? () => Navigator.pop(context) : null,
                  child: Text(langProvider.get('OK', 'OK')),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Consumer2<CartProvider, LanguageProvider>(
        builder: (context, cart, langProvider, child) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBarCustom(
              title: langProvider.get('Point of Sale', 'Penjualan'),
            ),
            drawer: const AppDrawer(),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _buildHeaderInfo(langProvider),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _buildTabSelector(cart, langProvider),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: IndexedStack(
                    index: _activeTab,
                    children: [
                      _buildKatalogTab(cart, langProvider),
                      _buildManualTab(cart, langProvider),
                      _buildPesananTab(context, cart, langProvider),
                    ],
                  ),
                ),
                if (_activeTab != 2) _buildMiniSummaryBar(cart, langProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------- Info transaksi (waktu, customer, kasir) ----------

  Widget _buildHeaderInfo(LanguageProvider langProvider) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ADMIN: ketuk field waktu (atau ikon kalender) untuk memilih
            // live / tanggal & jam sendiri
            GestureDetector(
              onTap: _isAdmin ? _showTransTimePicker : null,
              child: AbsorbPointer(
                child: TextField(
                  controller: _transactionDateController,
                  enabled: false,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: _customTransAt == null
                        ? langProvider.get('Now (live)', 'Sekarang (live)')
                        : langProvider.get(
                            'Custom transaction time', 'Waktu transaksi (custom)'),
                    border: const OutlineInputBorder(),
                    helperStyle: const TextStyle(fontSize: 10),
                    helperText: _isAdmin
                        ? langProvider.get('Tap to choose: live / custom',
                            'Ketuk utk pilih: live / custom')
                        : null,
                    suffixIcon: _isAdmin
                        ? Icon(Icons.edit_calendar,
                            size: 18,
                            color: _customTransAt == null ? Colors.grey : _kBrandBlue)
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildCustomerField(langProvider),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    enabled: false,
                    controller: _salesPersonController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: langProvider.get('Sales Person', 'Kasir'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _typeController,
                    enabled: false,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: langProvider.get('Type', 'Tipe'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Pill segmented tab: Katalog / Manual / Pesanan ----------

  Widget _buildTabSelector(CartProvider cart, LanguageProvider langProvider) {
    final qtyCount = cart.items.fold<int>(0, (s, i) => s + i.stockQty);
    final tabs = <_TabDef>[
      _TabDef(Icons.grid_view_rounded, langProvider.get('Catalog', 'Katalog')),
      _TabDef(Icons.edit_note, langProvider.get('Manual', 'Manual')),
      _TabDef(Icons.receipt_long,
          langProvider.get('Order', 'Pesanan')),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _activeTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? _kBrandBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tabs[i].icon,
                        size: 16,
                        color: selected ? Colors.white : Colors.grey[700]),
                    const SizedBox(width: 6),
                    Text(
                      tabs[i].label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (i == 2 && qtyCount > 0) ...[
                      const SizedBox(width: 6),
                      CircleAvatar(
                        radius: 9,
                        backgroundColor:
                            selected ? Colors.white : _kBrandBlue,
                        child: Text(
                          '$qtyCount',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: selected ? _kBrandBlue : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---------- Tab Katalog: cari & tambah produk cepat ----------

  Widget _buildKatalogTab(CartProvider cart, LanguageProvider langProvider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _catalogSearchController,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: langProvider.get('Search product', 'Cari produk'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => _debouncer.run(() => getAllStock(v, 1, 200)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showAddProductModal(context, langProvider),
                icon: const Icon(Icons.tune, size: 18),
                label: Text(langProvider.get('Options', 'Opsi')),
              ),
            ],
          ),
        ),
        if (_outletType == AppConstants.outletTherapy)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _showBookingPickerModal(context, langProvider, cart),
                icon: const Icon(Icons.event_available, size: 18),
                label: const Text('Booking'),
              ),
            ),
          ),
        Expanded(
          child: ValueListenableBuilder<StockPagination?>(
            valueListenable: stockPaginationNotifier,
            builder: (context, pagination, _) {
              final items = pagination?.data ?? [];
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    langProvider.get('No products found', 'Produk tidak ditemukan'),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                itemBuilder: (context, i) =>
                    _buildCatalogRow(cart, items[i], langProvider),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCatalogRow(
      CartProvider cart, StockResponse stock, LanguageProvider langProvider) {
    final qtyInCart = _cartQtyFor(cart, stock);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            // tap gambar = tambah 1 ke pesanan, sama seperti tombol "+" stepper
            onTap: () => _quickAdd(stock),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: stock.isTherapy
                    ? _kBrandTeal.withOpacity(0.15)
                    : _kBrandBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: stock.stock_photo.isEmpty
                  ? Icon(
                      stock.isTherapy ? Icons.spa : Icons.inventory_2_outlined,
                      color: stock.isTherapy ? _kBrandTeal : _kBrandBlue,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        ItemsApi().itemPhotoUrl(stock.stock_item_id),
                        headers: _photoHeaders,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          stock.isTherapy ? Icons.spa : Icons.inventory_2_outlined,
                          color: stock.isTherapy ? _kBrandTeal : _kBrandBlue,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stock.stock_name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  stock.isTherapy
                      ? '${langProvider.get('Service', 'Jasa')} • ${TextFormatter.formatRupiah(stock.stock_price.toDouble())}'
                      : '${langProvider.get('Stock', 'Stok')}: ${stock.stock_qty} • ${TextFormatter.formatRupiah(stock.stock_price.toDouble())}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildQtyStepper(
            qty: qtyInCart,
            onAdd: () => _quickAdd(stock),
            onRemove: () => _quickRemove(stock),
          ),
        ],
      ),
    );
  }

  /// Stepper -/qty/+ generik dipakai di katalog (qty = total di keranjang)
  /// dan di daftar pesanan (qty = jumlah baris tsb, bisa diketik langsung
  /// lewat [onTapQty]).
  Widget _buildQtyStepper({
    required int qty,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
    VoidCallback? onTapQty,
  }) {
    final qtyWidget = SizedBox(
      width: 26,
      child: Text(
        '$qty',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: qty > 0 ? onRemove : null,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.remove,
                  size: 16, color: qty > 0 ? Colors.black87 : Colors.grey[300]),
            ),
          ),
          onTapQty != null
              ? GestureDetector(onTap: onTapQty, child: qtyWidget)
              : qtyWidget,
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onAdd,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.add, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Tab Manual: harga bebas via keypad ----------

  Widget _buildManualTab(CartProvider cart, LanguageProvider langProvider) {
    final displayPrice = _manualPriceDigits.isEmpty ? 0 : int.parse(_manualPriceDigits);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              children: [
                Text(langProvider.get('Unit Price', 'Harga Satuan'),
                    style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text(
                  TextFormatter.formatRupiah(displayPrice.toDouble()),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: displayPrice == 0 ? Colors.grey[350] : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                if (!_manualShowNote)
                  TextButton.icon(
                    onPressed: () => setState(() => _manualShowNote = true),
                    icon: const Icon(Icons.add),
                    label: Text(langProvider.get('Add Note', 'Tambah Keterangan')),
                  )
                else
                  TextField(
                    controller: _manualNoteController,
                    decoration: InputDecoration(
                      labelText:
                          langProvider.get('Note (item name)', 'Keterangan (nama item)'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
              ],
            ),
          ),
        ),
        _buildManualKeypad(cart, langProvider),
      ],
    );
  }

  Widget _buildManualKeypad(CartProvider cart, LanguageProvider langProvider) {
    Widget numKey(String label, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!)),
            child: Text(label,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          ),
        ),
      );
    }

    void addDigit(String d) => setState(() {
          if (_manualPriceDigits.length < 12) _manualPriceDigits += d;
        });
    void backspace() => setState(() {
          if (_manualPriceDigits.isNotEmpty) {
            _manualPriceDigits =
                _manualPriceDigits.substring(0, _manualPriceDigits.length - 1);
          }
        });
    void clearAll() => setState(() => _manualPriceDigits = '');
    void confirmAdd() {
      final price = _manualPriceDigits.isEmpty ? 0 : int.parse(_manualPriceDigits);
      if (price <= 0) {
        Toast.error(
            context, langProvider.get('Enter a price first', 'Isi harga terlebih dahulu'));
        return;
      }
      final name = _manualNoteController.text.trim();
      cart.addItem(SalesItemModel.create(
        // stock_id sintetis (bukan item stok asli) -- backend menyimpan apa
        // adanya & melewati pengurangan stok untuk id yang tidak dikenal,
        // sama seperti item jasa THERAPY (lihat catatan di sales_master.go).
        stockId: 'MANUAL-${DateTime.now().millisecondsSinceEpoch}',
        stockCode: '-',
        stockName: name.isEmpty ? langProvider.get('Manual Item', 'Item Manual') : name,
        qty: 1,
        stockPack: 'PCS',
        price: price.toDouble(),
      ));
      setState(() {
        _manualPriceDigits = '';
        _manualNoteController.clear();
        _manualShowNote = false;
      });
      Toast.success(context, langProvider.get('Added to order', 'Ditambahkan ke pesanan'));
    }

    return SizedBox(
      height: 240,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  child: Row(children: [
                    numKey('1', () => addDigit('1')),
                    numKey('2', () => addDigit('2')),
                    numKey('3', () => addDigit('3')),
                  ]),
                ),
                Expanded(
                  child: Row(children: [
                    numKey('4', () => addDigit('4')),
                    numKey('5', () => addDigit('5')),
                    numKey('6', () => addDigit('6')),
                  ]),
                ),
                Expanded(
                  child: Row(children: [
                    numKey('7', () => addDigit('7')),
                    numKey('8', () => addDigit('8')),
                    numKey('9', () => addDigit('9')),
                  ]),
                ),
                Expanded(
                  child: Row(children: [
                    numKey('C', clearAll),
                    numKey('0', () => addDigit('0')),
                    numKey('000', () => addDigit('000')),
                  ]),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: backspace,
                    child: Container(
                      alignment: Alignment.center,
                      decoration:
                          BoxDecoration(border: Border.all(color: Colors.grey[200]!)),
                      child: const Icon(Icons.backspace_outlined),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: confirmAdd,
                    child: Container(
                      alignment: Alignment.center,
                      color: _kBrandBlue,
                      child: const Icon(Icons.add, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Tab Pesanan: keranjang, rincian bayar, aksi ----------

  Widget _buildPesananTab(
      BuildContext context, CartProvider cart, LanguageProvider langProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            langProvider.get('Order Items', 'Item Pesanan'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildOrderList(cart, langProvider),
          const SizedBox(height: 16),
          _buildPaymentSummary(cart, langProvider),
          if (_outletType != AppConstants.outletTherapy) ...[
            const SizedBox(height: 16),
            _buildMejaSelector(cart),
          ],
          const SizedBox(height: 24),
          _buildBottomButtons(context, cart, langProvider),
        ],
      ),
    );
  }

  Widget _buildOrderList(CartProvider cart, LanguageProvider langProvider) {
    if (cart.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration:
            BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
        child: Center(
          child: Text(
            langProvider.get('No items in cart', 'Tidak ada item di keranjang'),
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Column(
      children: cart.items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.hasDiscount)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.local_offer, size: 14, color: Colors.orange),
                          ),
                        Expanded(
                          child: Text(
                            item.stockName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      langProvider.get('Code', 'Kode') + ': ${item.stockCode}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.hasDiscount) ...[
                          Text(
                            TextFormatter.formatRupiah(item.originalStockPrice ?? 0),
                            style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                                fontSize: 12),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          '${TextFormatter.formatRupiah(item.stockPrice)} / ${item.stockPack}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(TextFormatter.formatRupiah(item.stockTotalSales),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.isBooking)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('${langProvider.get('Qty', 'Jumlah')}: ${item.stockQty}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    )
                  else
                    _buildQtyStepper(
                      qty: item.stockQty,
                      onAdd: () => cart.updateItemQty(i, item.stockQty + 1),
                      onRemove: () => item.stockQty <= 1
                          ? cart.removeItem(i)
                          : cart.updateItemQty(i, item.stockQty - 1),
                      onTapQty: () => _editQtyDialog(context, cart, i, item.stockQty),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.hasDiscount)
                        IconButton(
                          icon: const Icon(Icons.cancel, size: 18),
                          color: Colors.orange,
                          tooltip: langProvider.get('Cancel discount', 'Batalkan diskon'),
                          onPressed: () => cart.cancelDiscountForLine(i),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: Colors.red,
                        onPressed: () => cart.removeItem(i),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentSummary(
      CartProvider cart, LanguageProvider langProvider) {
    return Card(
      color: Colors.blue[50],
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              langProvider.get('PAYMENT DETAIL', 'RINCIAN PEMBAYARAN'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(),
            _buildSummaryRow(
              langProvider.get('Subtotal:', 'Subtotal:'),
              TextFormatter.formatRupiah(cart.total),
            ),
            if (cart.activeTotalDiscount != null)
              _buildSummaryRow(
                langProvider.get('Total discount:', 'Diskon Total:') +
                    ' (${cart.activeTotalDiscount!.discountValue.toStringAsFixed(0)}%)',
                '-${TextFormatter.formatRupiah(cart.totalDiscountAmount)}',
              ),
            if (cart.voucherCode != null)
              _buildSummaryRow(
                '${langProvider.get('Voucher:', 'Voucher:')} ${cart.voucherCode}',
                '-${TextFormatter.formatRupiah(cart.voucherDiscountAmount)}',
              ),
            _buildSummaryRow(
              langProvider.get('Total:', 'Total:'),
              TextFormatter.formatRupiah(cart.grandTotal),
            ),
            _buildSummaryRow(
              langProvider.get('Payment:', 'Pembayaran:'),
              TextFormatter.formatRupiah(cart.cashAmount),
            ),
            _buildSummaryRow(
              langProvider.get('Change:', 'Kembalian:'),
              TextFormatter.formatRupiah(cart.change),
              highlight: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight ? Colors.green[700] : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMejaSelector(CartProvider cart) {
    return InkWell(
      onTap: () => _pickMeja(cart),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.table_bar,
                color: cart.hasMeja ? _kBrandBlue : Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cart.hasMeja
                    ? 'Meja: ${cart.mejaNames.join(', ')}'
                    : '+ Pilih Meja',
                style: TextStyle(
                  color: cart.hasMeja ? Colors.black : Colors.grey[600],
                  fontWeight: cart.hasMeja ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  /// Buka picker meja. Kalau cart sudah punya meja terpilih, langsung buka
  /// picker untuk diedit (tidak tanya ulang jumlah pelanggan); kalau belum,
  /// tanya jumlah pelanggan dulu.
  Future<void> _pickMeja(CartProvider cart) async {
    int jumlahPelanggan = _lastMejaCustomerCount;

    if (!cart.hasMeja) {
      final controller = TextEditingController();
      final entered = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Jumlah Pelanggan'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'mis. 4'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final n = int.tryParse(controller.text.trim()) ?? 0;
                Navigator.pop(dialogContext, n);
              },
              child: const Text('Lanjut'),
            ),
          ],
        ),
      );
      if (entered == null || entered < 1) return;
      jumlahPelanggan = entered;
      _lastMejaCustomerCount = entered;
    }

    if (!mounted) return;
    final outcode = await Storage.get(AppConstants.outcode) ?? '';
    if (outcode.isEmpty) {
      if (mounted) Toast.error(context, 'Outlet belum dipilih');
      return;
    }

    if (!mounted) return;
    final result = await showMejaPickerSheet(
      context,
      outcode: outcode,
      jumlahPelanggan: jumlahPelanggan,
      currentMejaIds: cart.mejaIds,
    );
    if (result != null) {
      cart.setMeja(result.ids, result.names);
    }
  }

  Widget _buildBottomButtons(
      BuildContext context, CartProvider cart, LanguageProvider langProvider) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: cart.hasItems
                ? () => _showPaymentModal(context, langProvider, cart)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF21b6ae),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(langProvider.get('PAYMENT', 'BAYAR')),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: cart.hasItems
                ? () async {
                    if (cart.hasMeja) {
                      final outcode =
                          await Storage.get(AppConstants.outcode) ?? '';
                      if (outcode.isNotEmpty) {
                        // best-effort, tidak menghalangi BATAL kalau gagal
                        await _mejaApi.releaseMeja(outcode, cart.mejaIds);
                      }
                    }
                    cart.clear();
                    if (!context.mounted) return;
                    Toast.info(
                        context,
                        langProvider.get(
                            'Cart cleared', 'Keranjang dikosongkan'));
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD2042D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(langProvider.get('CANCEL', 'BATAL')),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: cart.canSave && !_isSaving
                ? () => _saveTransaction(context, cart, langProvider)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2cae6b),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(langProvider.get('SAVE', 'SIMPAN')),
          ),
        ),
      ],
    );
  }

  // ---------- Bar total ringkas (tab Katalog & Manual) ----------

  Widget _buildMiniSummaryBar(CartProvider cart, LanguageProvider langProvider) {
    final qtyCount = cart.items.fold<int>(0, (s, i) => s + i.stockQty);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(langProvider.get('Total Order', 'Total Pesanan'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                Text(TextFormatter.formatRupiah(cart.grandTotal),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          Opacity(
            opacity: cart.hasItems ? 1 : 0.5,
            child: Material(
              color: _kBrandBlue,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: cart.hasItems ? () => setState(() => _activeTab = 2) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (qtyCount > 0) ...[
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.white,
                          child: Text('$qtyCount',
                              style: const TextStyle(
                                  fontSize: 11, color: _kBrandBlue, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(langProvider.get('View Order', 'Lihat Pesanan'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Simpan transaksi: seluruh item cart (array) dikirim sekali ke backend,
  /// backend memasukkan ke antrian Kafka lalu consumer insert ke database.
  Future<void> _saveTransaction(BuildContext context, CartProvider cart,
      LanguageProvider langProvider) async {
    // customer wajib untuk RETAIL yang belum diberi akses "POS tanpa customer"
    if (_customerRequired &&
        _outletType != AppConstants.outletTherapy &&
        _receiptController.text.trim().isEmpty) {
      Toast.error(context, 'Nama customer wajib diisi');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final outcode = await Storage.get(AppConstants.outcode) ?? '';
      final payload = cart.buildInsertPayload(
        outcode: outcode,
        salesPerson: _salesPersonController.text,
        salesCustomer: _receiptController.text,
        customerSource: _receiptController.text.trim().isEmpty ? '' : _customerMode,
        customerShow: _customerShow ? 'Y' : 'N',
        // waktu transaksi manual (khusus ADMIN); kosong = live
        transDate: _isAdmin && _customTransAt != null
            ? DateFormat('yyyy-MM-dd').format(_customTransAt!)
            : '',
        transTime: _isAdmin && _customTransAt != null
            ? DateFormat('HH:mm').format(_customTransAt!)
            : '',
      );

      final response = await _salesApi.insertSales(payload);

      if (response.statusCode == 202 || response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final saleId = body['sale_id']?.toString() ?? '';
        // simpan info pembayaran & total SEBELUM cart di-reset (cart.total
        // jadi 0 setelah cart.clear())
        final wasBankTransfer =
            cart.paymentType == AppConstants.paymentBank;
        final proofToUpload = _proofImage;
        final savedTotal = cart.grandTotal;

        // Pindah ke layar sukses DULU, sebelum cart.clear()/setState di
        // bawah (yang memicu rebuild POS lewat Consumer2 pada frame
        // berikutnya) -- supaya navigasi tidak pernah tertunda/ketimpa oleh
        // rebuild halaman POS di belakang layar.
        if (saleId.isNotEmpty && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PaymentSuccessScreen(saleId: saleId, amount: savedTotal),
            ),
          );
        } else if (mounted) {
          // diagnostik sementara: kalau sampai sini, transaksi TETAP
          // tersimpan (lihat Sales History) tapi respons backend tidak
          // memuat sale_id yang valid -- tampilkan apa adanya biar kelihatan
          // penyebabnya, bukan gagal diam-diam.
          Toast.error(context,
              'Transaksi tersimpan tapi sale_id kosong. Respons: ${response.body}');
        }

        cart.clear();
        if (mounted) {
          setState(() {
            // kembali ke waktu live setelah transaksi tersimpan
            _customTransAt = null;
            _proofImage = null;
            _transactionDateController.text = DateTime.now().toString();
            _activeTab = 0;
          });
        }
        // transfer bank: upload foto bukti pembayaran (butuh sale_id) --
        // jalan di belakang layar, tidak perlu ditunggu sebelum pindah ke
        // layar sukses (punya penanganan error/toast sendiri)
        if (wasBankTransfer && proofToUpload != null && saleId.isNotEmpty) {
          _uploadProof(saleId, proofToUpload);
        }
      } else {
        String message = 'Gagal menyimpan transaksi';
        try {
          final body = jsonDecode(response.body);
          message = body['error']?.toString() ?? message;
        } catch (_) {}
        if (!mounted) return;
        Toast.error(context, message);
      }
    } catch (e) {
      debugPrint('Error saving transaction: $e');
      if (mounted) {
        Toast.error(
          context,
          langProvider.get('Failed to save transaction',
              'Gagal menyimpan transaksi'),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

}

/// Item hasil pencarian customer (nama + subjudul) untuk dialog pemilih.
class _CustPick {
  final String name;
  final String sub;
  _CustPick(this.name, this.sub);
}

/// Definisi satu segmen pill tab (ikon + label).
class _TabDef {
  final IconData icon;
  final String label;
  _TabDef(this.icon, this.label);
}
