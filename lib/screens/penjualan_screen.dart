import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/private_route.dart';
import '../widgets/modal_wrapper.dart';
import '../widgets/currency_input.dart';
import '../widgets/meja_picker_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/info_row.dart';
import '../widgets/search_field.dart';
import '../widgets/segmented_tabs.dart';
import '../utils/responsive.dart';
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

// Warna brand aplikasi -- alias token tema (lib/config/theme.dart) supaya
// layar ini tetap satu bahasa visual dengan layar lain & web.
const Color _kBrandBlue = AppColors.blue;
const Color _kBrandTeal = AppColors.tealDark;

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

  // Kartu info transaksi bisa dilipat supaya daftar produk tetap kelihatan
  // di layar pendek (HP landscape). null = ikuti default: terbuka di
  // portrait, terlipat di layar pendek.
  bool? _headerExpanded;

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
              : () =>
                  _customerMode == 'PESERTA' ? _pickPeserta() : _pickCustomer(),
          decoration: InputDecoration(
            isDense: true,
            labelText: (_customerRequired && !isTherapy)
                ? '${langProvider.get('Customer Name', 'Nama Customer')} *'
                : langProvider.get('Customer Name', 'Nama Customer'),
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
            suffixIcon: manual ? null : const Icon(Icons.search_rounded),
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
          final listHeight =
              (MediaQuery.sizeOf(ctx).height * 0.4).clamp(140.0, 260.0);
          return AlertDialog(
            title: Text(title),
            scrollable: true,
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtl,
                    decoration: const InputDecoration(
                      labelText: 'Cari',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                    onSubmitted: run,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: listHeight,
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
                                  onTap: () => Navigator.pop(
                                      dialogContext, items[i].name),
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
                    color: _customTransAt == null
                        ? AppColors.tealDark
                        : AppColors.muted),
                const SizedBox(width: 8),
                const Expanded(child: Text('Sekarang (live)')),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'custom'),
            child: Row(
              children: [
                Icon(Icons.edit_calendar,
                    color: _customTransAt != null
                        ? AppColors.tealDark
                        : AppColors.muted),
                const SizedBox(width: 8),
                const Expanded(child: Text('Pilih tanggal & jam')),
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
        Toast.error(context, "Failed to fetch items");
      }
    } catch (e) {
      print("ERROR: $e");
      Toast.error(context, "Error fetching items");
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
      Provider.of<CartProvider>(context, listen: false).setActiveDiscounts(map);
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
      Toast.error(
          context, 'Booking lama tanpa tipe terapi — bayar dari menu Booking');
      return false;
    }
    if (stock == null) {
      Toast.error(context,
          'Item ${_therapyItemName(b.therapyType, b.duration)} tidak ditemukan di stok');
      return false;
    }

    double price =
        b.price > 0 ? b.price.toDouble() : stock.stock_price.toDouble();
    if (price <= 0) {
      price =
          (_defaultTherapyPrices[b.therapyType]?[b.duration] ?? 0).toDouble();
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
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(builder: (context, setSheetState) {
          future ??= _fetchBookingsFor(pickerDate);
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Booking Terapi',
                          style: Theme.of(context).textTheme.titleMedium,
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
                      if (snapshot.connectionState == ConnectionState.waiting) {
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
                        return EmptyState(
                          icon: Icons.event_busy_rounded,
                          title: 'Belum ada booking',
                          description: 'Tidak ada booking pada tanggal '
                              '${DateFormat('dd-MM-yyyy').format(pickerDate)}',
                          compact: true,
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
                                      ? AppColors.errorLight
                                      : AppColors.warningLight,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                      color: b.isPaid
                                          ? AppColors.error
                                          : AppColors.warning),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(
                                    b.isPaid
                                        ? Icons.check_circle
                                        : Icons.hourglass_bottom,
                                    color: b.isPaid
                                        ? AppColors.errorDark
                                        : AppColors.warningDark,
                                  ),
                                  title: Text(
                                    '${b.custName} • ${b.start}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(0, 36),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                    ),
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
      scrollable: true,
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                langProvider.get('Add Product', 'Tambah Produk'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),

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
                            return items.where((item) =>
                                item.stock_name.toLowerCase().contains(query));
                          },
                          displayStringForOption: (option) => option.stock_name,
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                clipBehavior: Clip.antiAlias,
                                child: Container(
                                  // ikut lebar dialog (dulu 500 tetap ->
                                  // meluap di HP)
                                  width: context.dialogMaxWidth() - 56,
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
                                                    suggestion.stock_name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
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
                              _salesStockIDController.text = selection.stock_id;
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
                                prefixIcon:
                                    const Icon(Icons.search_rounded, size: 20),
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
                ),
              ),
              const SizedBox(height: 16),

              // Harga (informasi) + opsi harga custom
              if (_selectedStock != null) ...[
                InfoRow(
                  label: langProvider.get('Price', 'Harga'),
                  value: TextFormatter.formatRupiah(
                      _selectedStock!.stock_price.toDouble()),
                  bold: true,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(langProvider.get('Custom price', 'Harga custom')),
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
                ),
              ),
              const SizedBox(height: 20),

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
    final idx = cart.items
        .indexWhere((i) => i.stockId == stock.stock_id && !i.isBooking);
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
    final idx = cart.items
        .indexWhere((i) => i.stockId == stock.stock_id && !i.isBooking);
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
  Future<void> _editQtyDialog(BuildContext context, CartProvider cart,
      int index, int currentQty) async {
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
      scrollable: true,
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
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            InfoRow(
              label: langProvider.get('Total to pay', 'Total tagihan'),
              value: TextFormatter.formatRupiah(cart.grandTotal),
              bold: true,
            ),
            const SizedBox(height: 12),

            // Jenis pembayaran: Tunai atau Transfer Bank
            DropdownButtonFormField<String>(
              key: ValueKey(cart.paymentType),
              initialValue: cart.paymentType.isEmpty ? null : cart.paymentType,
              decoration: InputDecoration(
                labelText: langProvider.get('Payment Type', 'Jenis Pembayaran'),
                prefixIcon: const Icon(Icons.payments_outlined, size: 20),
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
                        prefixIcon: const Icon(
                            Icons.confirmation_number_outlined,
                            size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _applyVoucher(cart, setModalState),
                      child: Text(langProvider.get('Apply', 'Terapkan')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.confirmation_number,
                        size: 18, color: AppColors.successDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${cart.voucherCode} (${cart.voucherPercent!.toStringAsFixed(0)}%) diterapkan',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.successDark,
                            fontWeight: FontWeight.w600),
                      ),
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
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(_proofImage == null
                      ? Icons.upload_file_outlined
                      : Icons.check_circle_rounded),
                  label: Text(
                    _proofImage == null
                        ? 'Upload foto bukti pembayaran'
                        : 'Bukti terpilih — ganti foto',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _proofImage == null
                        ? AppColors.tealDark
                        : AppColors.successDark,
                    side: BorderSide(
                        color: (_proofImage == null
                                ? AppColors.tealDark
                                : AppColors.successDark)
                            .withValues(alpha: 0.5)),
                  ),
                  onPressed: () async {
                    final file = await _pickProofImage();
                    if (file != null) {
                      setModalState(() => _proofImage = file);
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text('Wajib untuk transfer bank, maksimal 5 MB',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              if (_proofImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.file(
                      _proofImage!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 20),

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
                  onPressed: canConfirm ? () => Navigator.pop(context) : null,
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
          // Tablet (>= 900dp): dua panel -- katalog/manual di kiri, pesanan
          // & pembayaran selalu terlihat di kanan. HP: tab seperti biasa.
          final twoPane = context.isExpanded;
          final leftTab = twoPane ? _activeTab.clamp(0, 1) : _activeTab;
          final pad = context.pagePadding;

          final leftColumn = Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
                child: _buildHeaderInfo(langProvider),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 10, pad, 0),
                child: _buildTabSelector(cart, langProvider, twoPane: twoPane),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: IndexedStack(
                  index: leftTab,
                  children: [
                    _buildKatalogTab(cart, langProvider),
                    _buildManualTab(cart, langProvider),
                    if (!twoPane) _buildPesananTab(context, cart, langProvider),
                  ],
                ),
              ),
              if (!twoPane && _activeTab != 2)
                _buildMiniSummaryBar(cart, langProvider),
            ],
          );

          return Scaffold(
            appBar: AppBarCustom(
              title: langProvider.get('Point of Sale', 'Penjualan'),
            ),
            drawer: const AppDrawer(),
            body: SafeArea(
              top: false,
              child: twoPane
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: leftColumn),
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: (context.screenWidth * 0.4).clamp(360, 460),
                          child: ColoredBox(
                            color: AppColors.surface,
                            child:
                                _buildPesananTab(context, cart, langProvider),
                          ),
                        ),
                      ],
                    )
                  : leftColumn,
            ),
          );
        },
      ),
    );
  }

  // ---------- Info transaksi (waktu, customer, kasir) ----------

  bool _headerIsExpanded(BuildContext context) =>
      _headerExpanded ?? !context.isShort;

  Widget _buildHeaderInfo(LanguageProvider langProvider) {
    final textTheme = Theme.of(context).textTheme;
    final expanded = _headerIsExpanded(context);
    final customer = _receiptController.text.trim();
    final summary = [
      customer.isEmpty
          ? langProvider.get('No customer', 'Tanpa customer')
          : customer,
      _salesPersonController.text,
      _customTransAt == null
          ? langProvider.get('Live', 'Live')
          : DateFormat('dd-MM HH:mm').format(_customTransAt!),
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // baris judul + tombol lipat: di layar pendek (HP landscape)
            // kartu ini terlipat supaya daftar produk tetap kelihatan
            InkWell(
              onTap: () => setState(() => _headerExpanded = !expanded),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined,
                      size: 18, color: AppColors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: expanded
                        ? Text(
                            langProvider.get(
                                'Transaction info', 'Info Transaksi'),
                            style: textTheme.titleSmall,
                          )
                        : Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall
                                ?.copyWith(color: AppColors.ink),
                          ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 10),
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
                          : langProvider.get('Custom transaction time',
                              'Waktu transaksi (custom)'),
                      prefixIcon: const Icon(Icons.schedule_rounded, size: 20),
                      helperStyle: const TextStyle(fontSize: 10),
                      helperText: _isAdmin
                          ? langProvider.get('Tap to choose: live / custom',
                              'Ketuk utk pilih: live / custom')
                          : null,
                      suffixIcon: _isAdmin
                          ? Icon(Icons.edit_calendar,
                              size: 18,
                              color: _customTransAt == null
                                  ? AppColors.muted
                                  : _kBrandBlue)
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
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- Pill segmented tab: Katalog / Manual / Pesanan ----------

  Widget _buildTabSelector(CartProvider cart, LanguageProvider langProvider,
      {bool twoPane = false}) {
    final qtyCount = cart.items.fold<int>(0, (s, i) => s + i.stockQty);
    return SegmentedTabs<int>(
      value: twoPane ? _activeTab.clamp(0, 1) : _activeTab,
      onChanged: (i) => setState(() => _activeTab = i),
      tabs: [
        SegmentedTab(
          value: 0,
          icon: Icons.grid_view_rounded,
          label: langProvider.get('Catalog', 'Katalog'),
        ),
        SegmentedTab(
          value: 1,
          icon: Icons.edit_note,
          label: langProvider.get('Manual', 'Manual'),
        ),
        if (!twoPane)
          SegmentedTab(
            value: 2,
            icon: Icons.receipt_long,
            label: langProvider.get('Order', 'Pesanan'),
            badge: qtyCount,
          ),
      ],
    );
  }

  // ---------- Tab Katalog: cari & tambah produk cepat ----------

  Widget _buildKatalogTab(CartProvider cart, LanguageProvider langProvider) {
    final pad = context.pagePadding;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 8),
          child: Row(
            children: [
              Expanded(
                child: SearchField(
                  controller: _catalogSearchController,
                  hintText: langProvider.get('Search product', 'Cari produk'),
                  onChanged: (v) =>
                      _debouncer.run(() => getAllStock(v, 1, 200)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showAddProductModal(context, langProvider),
                icon: const Icon(Icons.tune, size: 18),
                label: Text(langProvider.get('Options', 'Opsi')),
              ),
              if (_outletType == AppConstants.outletTherapy) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      _showBookingPickerModal(context, langProvider, cart),
                  icon: const Icon(Icons.event_available, size: 18),
                  label: const Text('Booking'),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<StockPagination?>(
            valueListenable: stockPaginationNotifier,
            builder: (context, pagination, _) {
              final items = pagination?.data ?? [];
              if (items.isEmpty) {
                return SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: langProvider.get(
                        'No products found', 'Produk tidak ditemukan'),
                    description: langProvider.get(
                        'Try another keyword or add stock first',
                        'Coba kata kunci lain atau tambah stok dulu'),
                    compact: true,
                  ),
                );
              }
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
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
                color:
                    stock.isTherapy ? AppColors.tealLight : AppColors.blueLight,
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
                          stock.isTherapy
                              ? Icons.spa
                              : Icons.inventory_2_outlined,
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
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  stock.isTherapy
                      ? '${langProvider.get('Service', 'Jasa')} • ${TextFormatter.formatRupiah(stock.stock_price.toDouble())}'
                      : '${langProvider.get('Stock', 'Stok')}: ${stock.stock_qty} • ${TextFormatter.formatRupiah(stock.stock_price.toDouble())}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
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
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
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
                  size: 16, color: qty > 0 ? AppColors.ink : AppColors.border),
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
    final displayPrice =
        _manualPriceDigits.isEmpty ? 0 : int.parse(_manualPriceDigits);
    final short = context.isShort;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, short ? 8 : 24, 24, 8),
            child: Column(
              children: [
                Text(langProvider.get('Unit Price', 'Harga Satuan'),
                    style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    TextFormatter.formatRupiah(displayPrice.toDouble()),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: short ? 28 : 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: displayPrice == 0
                          ? AppColors.disabled
                          : AppColors.ink,
                    ),
                  ),
                ),
                SizedBox(height: short ? 4 : 12),
                if (!_manualShowNote)
                  TextButton.icon(
                    onPressed: () => setState(() => _manualShowNote = true),
                    icon: const Icon(Icons.add),
                    label:
                        Text(langProvider.get('Add Note', 'Tambah Keterangan')),
                  )
                else
                  TextField(
                    controller: _manualNoteController,
                    decoration: InputDecoration(
                      labelText: langProvider.get(
                          'Note (item name)', 'Keterangan (nama item)'),
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
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink)),
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
      final price =
          _manualPriceDigits.isEmpty ? 0 : int.parse(_manualPriceDigits);
      if (price <= 0) {
        Toast.error(
            context,
            langProvider.get(
                'Enter a price first', 'Isi harga terlebih dahulu'));
        return;
      }
      final name = _manualNoteController.text.trim();
      cart.addItem(SalesItemModel.create(
        // stock_id sintetis (bukan item stok asli) -- backend menyimpan apa
        // adanya & melewati pengurangan stok untuk id yang tidak dikenal,
        // sama seperti item jasa THERAPY (lihat catatan di sales_master.go).
        stockId: 'MANUAL-${DateTime.now().millisecondsSinceEpoch}',
        stockCode: '-',
        stockName: name.isEmpty
            ? langProvider.get('Manual Item', 'Item Manual')
            : name,
        qty: 1,
        stockPack: 'PCS',
        price: price.toDouble(),
      ));
      setState(() {
        _manualPriceDigits = '';
        _manualNoteController.clear();
        _manualShowNote = false;
      });
      Toast.success(context,
          langProvider.get('Added to order', 'Ditambahkan ke pesanan'));
    }

    // keypad lebih pendek di HP landscape supaya tampilan harga tetap muat
    return SizedBox(
      height: context.isShort ? 176 : 240,
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
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: const Icon(Icons.backspace_outlined,
                          color: AppColors.ink),
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
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 28),
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
    final pad = context.pagePadding;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            langProvider.get('Order Items', 'Item Pesanan'),
            style: Theme.of(context).textTheme.titleMedium,
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
      return Card(
        child: EmptyState(
          icon: Icons.shopping_cart_outlined,
          title: langProvider.get('No items in cart', 'Keranjang masih kosong'),
          description: langProvider.get(
              'Add products from the Catalog or Manual tab',
              'Tambah produk dari tab Katalog atau Manual'),
          compact: true,
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
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.lg),
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
                            child: Icon(Icons.local_offer,
                                size: 14, color: AppColors.warning),
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
                      '${langProvider.get('Code', 'Kode')}: ${item.stockCode}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.disabled),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (item.hasDiscount)
                          Text(
                            TextFormatter.formatRupiah(
                                item.originalStockPrice ?? 0),
                            style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: AppColors.disabled,
                                fontSize: 12),
                          ),
                        Text(
                          '${TextFormatter.formatRupiah(item.stockPrice)} / ${item.stockPack}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted),
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
                      child: Text(
                          '${langProvider.get('Qty', 'Jumlah')}: ${item.stockQty}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    )
                  else
                    _buildQtyStepper(
                      qty: item.stockQty,
                      onAdd: () => cart.updateItemQty(i, item.stockQty + 1),
                      onRemove: () => item.stockQty <= 1
                          ? cart.removeItem(i)
                          : cart.updateItemQty(i, item.stockQty - 1),
                      onTapQty: () =>
                          _editQtyDialog(context, cart, i, item.stockQty),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.hasDiscount)
                        IconButton(
                          icon: const Icon(Icons.cancel, size: 18),
                          color: AppColors.warning,
                          visualDensity: VisualDensity.compact,
                          tooltip: langProvider.get(
                              'Cancel discount', 'Batalkan diskon'),
                          onPressed: () => cart.cancelDiscountForLine(i),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: AppColors.error,
                        visualDensity: VisualDensity.compact,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blueLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_outlined,
                  size: 18, color: AppColors.blueDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  langProvider.get('Payment detail', 'Rincian Pembayaran'),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: AppColors.blueDark),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          InfoRow(
            label: langProvider.get('Subtotal', 'Subtotal'),
            value: TextFormatter.formatRupiah(cart.total),
          ),
          if (cart.activeTotalDiscount != null)
            InfoRow(
              label:
                  '${langProvider.get('Total discount', 'Diskon Total')} (${cart.activeTotalDiscount!.discountValue.toStringAsFixed(0)}%)',
              value: '-${TextFormatter.formatRupiah(cart.totalDiscountAmount)}',
              color: AppColors.warningDark,
            ),
          if (cart.voucherCode != null)
            InfoRow(
              label:
                  '${langProvider.get('Voucher', 'Voucher')} ${cart.voucherCode}',
              value:
                  '-${TextFormatter.formatRupiah(cart.voucherDiscountAmount)}',
              color: AppColors.warningDark,
            ),
          InfoRow(
            label: langProvider.get('Total', 'Total'),
            value: TextFormatter.formatRupiah(cart.grandTotal),
            bold: true,
          ),
          InfoRow(
            label: langProvider.get('Payment', 'Pembayaran'),
            value: TextFormatter.formatRupiah(cart.cashAmount),
          ),
          InfoRow(
            label: langProvider.get('Change', 'Kembalian'),
            value: TextFormatter.formatRupiah(cart.change),
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMejaSelector(CartProvider cart) {
    return InkWell(
      onTap: () => _pickMeja(cart),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
              color: cart.hasMeja ? AppColors.blue : AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.table_bar,
                color: cart.hasMeja ? _kBrandBlue : AppColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cart.hasMeja
                    ? 'Meja: ${cart.mejaNames.join(', ')}'
                    : '+ Pilih Meja',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cart.hasMeja ? AppColors.ink : AppColors.muted,
                  fontWeight:
                      cart.hasMeja ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.disabled),
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
    final payButton = ElevatedButton.icon(
      onPressed: cart.hasItems
          ? () => _showPaymentModal(context, langProvider, cart)
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.tealDark,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      icon: const Icon(Icons.payments_outlined, size: 18),
      label: Text(langProvider.get('PAYMENT', 'BAYAR'),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    );

    final cancelButton = OutlinedButton.icon(
      onPressed: cart.hasItems
          ? () async {
              if (cart.hasMeja) {
                final outcode = await Storage.get(AppConstants.outcode) ?? '';
                if (outcode.isNotEmpty) {
                  // best-effort, tidak menghalangi BATAL kalau gagal
                  await _mejaApi.releaseMeja(outcode, cart.mejaIds);
                }
              }
              cart.clear();
              if (!context.mounted) return;
              Toast.info(context,
                  langProvider.get('Cart cleared', 'Keranjang dikosongkan'));
            }
          : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      icon: const Icon(Icons.close_rounded, size: 18),
      label: Text(langProvider.get('CANCEL', 'BATAL'),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    );

    final saveButton = ElevatedButton.icon(
      onPressed: cart.canSave && !_isSaving
          ? () => _saveTransaction(context, cart, langProvider)
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.successDark,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      icon: _isSaving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.check_rounded, size: 18),
      label: Text(langProvider.get('SAVE', 'SIMPAN'),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    );

    // HP sempit: SIMPAN lebar penuh di baris sendiri supaya label tiga
    // tombol tidak saling berebut ruang.
    if (context.screenWidth < 420) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: payButton),
              const SizedBox(width: 10),
              Expanded(child: cancelButton),
            ],
          ),
          const SizedBox(height: 10),
          saveButton,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: payButton),
        const SizedBox(width: 12),
        Expanded(child: cancelButton),
        const SizedBox(width: 12),
        Expanded(child: saveButton),
      ],
    );
  }

  // ---------- Bar total ringkas (tab Katalog & Manual) ----------

  Widget _buildMiniSummaryBar(
      CartProvider cart, LanguageProvider langProvider) {
    final qtyCount = cart.items.fold<int>(0, (s, i) => s + i.stockQty);
    final short = context.isShort;
    return Container(
      padding: EdgeInsets.fromLTRB(context.pagePadding, short ? 8 : 12,
          context.pagePadding, short ? 8 : 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(langProvider.get('Total Order', 'Total Pesanan'),
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
                Text(TextFormatter.formatRupiah(cart.grandTotal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: short ? 16 : 18)),
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
                onTap:
                    cart.hasItems ? () => setState(() => _activeTab = 2) : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 18, vertical: short ? 10 : 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (qtyCount > 0) ...[
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.white,
                          child: Text('$qtyCount',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: _kBrandBlue,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(langProvider.get('View Order', 'Lihat Pesanan'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
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
        customerSource:
            _receiptController.text.trim().isEmpty ? '' : _customerMode,
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
        final wasBankTransfer = cart.paymentType == AppConstants.paymentBank;
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
          langProvider.get(
              'Failed to save transaction', 'Gagal menyimpan transaksi'),
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
