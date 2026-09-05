import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../config/theme.dart';
import '../models/booking_model.dart';
import '../models/item_model.dart';
import '../services/booking_api.dart';
import '../services/items_api.dart';
import '../services/sales_api.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

/// Booking slot terapi (outlet type THERAPY).
/// Warna slot: hijau = tersedia, kuning = ada booking belum bayar,
/// merah = penuh (fix). Booking UNPAID yang lewat jamnya otomatis
/// kadaluarsa di backend sehingga slot kembali hijau.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _bookingApi = BookingApi();
  final _itemsApi = ItemsApi();
  final _salesApi = SalesApi();

  DateTime _selectedDate = DateTime.now();
  List<SlotModel> _slots = [];
  bool _isLoading = false;
  String _outcode = '';
  String _role = AppConstants.roleSeller;
  List<ItemResponse> _items = [];

  bool get _isSeller => _role != AppConstants.roleBuyer;

  // Harga default per tipe terapi & durasi (fallback jika item belum termuat):
  // Sofa 30mnt 15rb / 1jam 25rb; Kursi Dragon 30mnt 25rb / 1jam 35rb;
  // Kursi 30mnt 10rb / 1jam 20rb.
  static const Map<String, Map<int, int>> _defaultPrices = {
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

  int _priceFor(String type, int duration) {
    final name = _therapyItemName(type, duration);
    for (final item in _items) {
      if (item.item_name.toUpperCase() == name) return item.item_price;
    }
    return _defaultPrices[type]?[duration] ?? 0;
  }

  String _therapyLabel(String type) {
    if (type == AppConstants.therapyDragon) return 'Kursi Dragon';
    if (type == AppConstants.therapyKursi) return 'Kursi';
    return 'Sofa';
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _outcode = await Storage.get(AppConstants.outcode) ?? '';
    _role =
        await Storage.get(AppConstants.userRoleKey) ?? AppConstants.roleSeller;
    await Future.wait([_loadSlots(), _loadItems()]);
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _loadSlots() async {
    if (_outcode.isEmpty) {
      if (mounted) Toast.error(context, 'Outlet belum dipilih');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await _bookingApi.getSlots(_outcode, _dateStr);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _slots = ((data['data'] ?? []) as List)
              .map((e) => SlotModel.fromJson(e))
              .toList();
        });
      } else {
        String message = 'Gagal memuat slot';
        try {
          message = jsonDecode(response.body)['error'] ?? message;
        } catch (_) {}
        if (mounted) Toast.error(context, message);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal memuat slot');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadItems() async {
    try {
      final response = await _itemsApi.getAllItems('', _outcode, 1, 200);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // hanya item jasa terapi (merek THERAPY) yang bisa dipilih untuk booking
          _items = ((data['data'] ?? []) as List)
              .map((e) => ItemResponse.fromJson(e))
              .where((item) => item.item_brand.toUpperCase() == 'THERAPY')
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _loadSlots();
    }
  }

  Color _slotColor(SlotModel slot) {
    if (slot.full) return Colors.red.shade400; // fix, tidak bisa digantikan
    if (slot.hasUnpaid) return Colors.amber.shade400; // ada yang belum bayar
    return Colors.green.shade400; // tersedia
  }

  Future<void> _printReceipt(String saleId) async {
    Toast.info(context, 'Menyiapkan nota...');
    final pdfBytes = await _salesApi.getReceiptPdfWithRetry(saleId);
    if (pdfBytes != null) {
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } else {
      if (mounted) {
        Toast.error(context, 'Nota belum siap, coba dari History Sales');
      }
    }
  }

  void _showBookingDialog(SlotModel slot) {
    if (slot.past) {
      Toast.info(context, 'Jam ini sudah lewat');
      return;
    }
    if (slot.full) {
      Toast.info(context, 'Slot sudah penuh');
      return;
    }

    int duration = 30;
    bool paid = false;
    String therapyType = AppConstants.therapySofa;
    bool useCustomPrice = false;
    BuyerModel? selectedBuyer;
    final priceController = TextEditingController();
    final nameController = TextEditingController();
    final buyerSearchController = TextEditingController();
    List<BuyerModel> buyerSuggestions = [];
    Timer? debounce;
    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          Future<void> searchBuyers(String q) async {
            try {
              final response = await _bookingApi.searchBuyers(q);
              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                setDialogState(() {
                  buyerSuggestions = ((data['data'] ?? []) as List)
                      .map((e) => BuyerModel.fromJson(e))
                      .toList();
                });
              }
            } catch (_) {}
          }

          Future<void> save() async {
            if (_isSeller &&
                selectedBuyer == null &&
                nameController.text.trim().isEmpty) {
              Toast.error(
                  context, 'Pilih pembeli terdaftar atau isi nama pembeli');
              return;
            }
            int customPrice = 0;
            if (_isSeller && useCustomPrice) {
              customPrice = int.tryParse(priceController.text
                      .replaceAll('.', '')
                      .replaceAll(',', '')) ??
                  0;
              if (customPrice <= 0) {
                Toast.error(context, 'Isi harga custom yang valid');
                return;
              }
            }
            setDialogState(() => saving = true);
            try {
              final response = await _bookingApi.insertBooking(
                outcode: _outcode,
                date: _dateStr,
                start: slot.start,
                duration: duration,
                custId: _isSeller ? (selectedBuyer?.goldId ?? 0) : 0,
                custName: _isSeller ? nameController.text.trim() : '',
                paid: paid,
                therapyType: therapyType,
                customPrice: customPrice,
              );
              final body = jsonDecode(response.body);
              if (response.statusCode == 201) {
                if (mounted) {
                  Navigator.pop(dialogContext);
                  Toast.success(this.context, 'Booking berhasil');
                  await _loadSlots();
                  final saleId = body['sale_id'];
                  if (saleId != null && saleId.toString().isNotEmpty) {
                    await _printReceipt(saleId);
                  }
                  await _offerContinueShopping();
                }
              } else {
                setDialogState(() => saving = false);
                Toast.error(context, body['error'] ?? 'Booking gagal');
              }
            } catch (e) {
              setDialogState(() => saving = false);
              Toast.error(context, 'Booking gagal');
            }
          }

          return AlertDialog(
            title: Text('Booking ${slot.start}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tipe terapi
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Tipe: '),
                      ChoiceChip(
                        label: const Text('Sofa'),
                        selected: therapyType == AppConstants.therapySofa,
                        onSelected: (_) => setDialogState(
                            () => therapyType = AppConstants.therapySofa),
                      ),
                      ChoiceChip(
                        label: const Text('Kursi Dragon'),
                        selected: therapyType == AppConstants.therapyDragon,
                        onSelected: (_) => setDialogState(
                            () => therapyType = AppConstants.therapyDragon),
                      ),
                      ChoiceChip(
                        label: const Text('Kursi'),
                        selected: therapyType == AppConstants.therapyKursi,
                        onSelected: (_) => setDialogState(
                            () => therapyType = AppConstants.therapyKursi),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Durasi
                  Row(
                    children: [
                      const Text('Durasi: '),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('30 menit'),
                        selected: duration == 30,
                        onSelected: (_) => setDialogState(() => duration = 30),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('1 jam'),
                        selected: duration == 60,
                        onSelected: (_) => setDialogState(() => duration = 60),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Harga ${_therapyLabel(therapyType)} ${duration == 60 ? "1 jam" : "30 menit"}: '
                    '${TextFormatter.formatRupiah(_priceFor(therapyType, duration).toDouble())}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Pembeli (khusus penjual; pembeli otomatis atas nama sendiri)
                  if (_isSeller) ...[
                    TextField(
                      controller: buyerSearchController,
                      decoration: const InputDecoration(
                        labelText: 'Cari pembeli terdaftar',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        debounce?.cancel();
                        debounce = Timer(const Duration(milliseconds: 400),
                            () => searchBuyers(value));
                      },
                    ),
                    if (buyerSuggestions.isNotEmpty && selectedBuyer == null)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 140),
                        child: ListView(
                          shrinkWrap: true,
                          children: buyerSuggestions
                              .map((b) => ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.verified_user,
                                        color: Colors.teal, size: 18),
                                    title: Text(b.nama),
                                    subtitle: Text(b.email),
                                    onTap: () {
                                      setDialogState(() {
                                        selectedBuyer = b;
                                        buyerSearchController.text = b.nama;
                                        nameController.clear();
                                      });
                                    },
                                  ))
                              .toList(),
                        ),
                      ),
                    if (selectedBuyer != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Chip(
                          avatar: const Icon(Icons.verified_user,
                              color: Colors.white, size: 16),
                          backgroundColor: Colors.teal,
                          label: Text(
                            '${selectedBuyer!.nama} (TERDAFTAR)',
                            style: const TextStyle(color: Colors.white),
                          ),
                          onDeleted: () => setDialogState(() {
                            selectedBuyer = null;
                            buyerSearchController.clear();
                          }),
                          deleteIconColor: Colors.white,
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      enabled: selectedBuyer == null,
                      decoration: const InputDecoration(
                        labelText: 'Atau nama pembeli (belum terdaftar)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        helperText:
                            'Nama manual ditandai sebagai BELUM TERDAFTAR',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Status bayar
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bayar sekarang'),
                    subtitle: Text(paid
                        ? 'Slot langsung fix (merah) + nota PDF'
                        : 'Booking ditandai kuning (belum bayar)'),
                    value: paid,
                    onChanged: (v) => setDialogState(() => paid = v),
                  ),

                  // Harga custom (khusus penjual/admin): abaikan harga default,
                  // ketik harga sendiri. Untuk booking belum bayar, harga custom
                  // dikunci di booking dan dipakai saat pembayaran nanti.
                  if (_isSeller) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Harga custom'),
                      subtitle: Text(useCustomPrice
                          ? (paid
                              ? 'Input harga sendiri (abaikan harga default)'
                              : 'Harga dikunci & dipakai saat pembayaran nanti')
                          : 'Pakai harga default'),
                      value: useCustomPrice,
                      onChanged: (v) =>
                          setDialogState(() => useCustomPrice = v),
                    ),
                    if (useCustomPrice)
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga custom (Rp)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('BATAL'),
              ),
              ElevatedButton(
                onPressed: saving ? null : save,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('BOOKING'),
              ),
            ],
          );
        });
      },
    );
  }

  /// Modal detail satu slot: siapa yang SUDAH BAYAR (merah), siapa yang
  /// BELUM BAYAR (kuning), dan sisa tempat yang masih tersedia (hijau).
  void _showSlotDetail(SlotModel slot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Slot ${slot.start} - ${slot.end}  (${slot.used}/${slot.capacity})',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _legend(Colors.amber.shade400, 'Belum bayar'),
                          const SizedBox(width: 12),
                          _legend(Colors.red.shade400, 'Sudah bayar'),
                          const SizedBox(width: 12),
                          _legend(Colors.green.shade400, 'Tersedia'),
                        ],
                      ),
                    ],
                  ),
                ),
                ...slot.bookings.map((b) => _slotBookingTile(context, b)),
                if (slot.available > 0)
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade400),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_seat, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '${slot.available} tempat masih tersedia',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!slot.full && !slot.past)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('BOOKING SLOT INI'),
                        onPressed: () {
                          Navigator.pop(context);
                          _showBookingDialog(slot);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Kartu satu booking dalam modal detail slot: kuning = belum bayar,
  /// merah = sudah bayar; penjual melihat tombol BAYAR / HAPUS untuk
  /// booking yang belum dibayar.
  Widget _slotBookingTile(BuildContext sheetContext, SlotBookingModel b) {
    final baseColor = b.isPaid ? Colors.red : Colors.amber;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: b.isPaid ? Colors.red.shade100 : Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: b.isPaid ? Colors.red.shade400 : Colors.amber.shade400),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          b.isPaid ? Icons.check_circle : Icons.hourglass_bottom,
          color: b.isPaid ? Colors.red.shade700 : Colors.amber.shade800,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // nama pembeli wrap per kata: "tester wowza" turun jadi
            // "tester" / "wowza", tidak terpotong di tengah kata
            Text(
              b.custName,
              softWrap: true,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            // badge status di bawah nama pembeli
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: baseColor.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    b.isPaid ? 'SUDAH BAYAR' : 'BELUM BAYAR',
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                if (!b.isRegistered)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('BELUM TERDAFTAR',
                        style: TextStyle(fontSize: 10)),
                  ),
              ],
            ),
          ],
        ),
        subtitle: Text('Mulai ${b.start} • ${b.duration} menit'
            '${b.therapyLabel.isNotEmpty ? " • ${b.therapyLabel}" : ""}'
            '${b.price > 0 && !b.isPaid ? " • Harga custom ${TextFormatter.formatRupiah(b.price.toDouble())}" : ""}'),
        trailing: (_isSeller && !b.isPaid)
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showPayBookingDialog(b);
                    },
                    child: const Text('BAYAR'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _removeBooking(b);
                    },
                    child: const Text('HAPUS'),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  void _showPayBookingDialog(SlotBookingModel booking) {
    ItemResponse? selectedItem; // hanya untuk booking lama tanpa tipe terapi
    bool useCustomPrice = false;
    final priceController = TextEditingController();
    bool saving = false;
    final hasType = booking.therapyType.isNotEmpty;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          Future<void> pay() async {
            if (!hasType && selectedItem == null) {
              Toast.error(context, 'Pilih item terapi');
              return;
            }
            int customPrice = 0;
            if (useCustomPrice) {
              customPrice = int.tryParse(priceController.text
                      .replaceAll('.', '')
                      .replaceAll(',', '')) ??
                  0;
              if (customPrice <= 0) {
                Toast.error(context, 'Isi harga custom yang valid');
                return;
              }
            }
            setDialogState(() => saving = true);
            try {
              final response = await _bookingApi.payBooking(
                booking.bookingId,
                selectedItem?.item_id ?? 0,
                customPrice: customPrice,
              );
              final body = jsonDecode(response.body);
              if (response.statusCode == 200) {
                if (mounted) {
                  Navigator.pop(dialogContext);
                  Toast.success(this.context, 'Booking lunas');
                  await _loadSlots();
                  final saleId = body['sale_id'];
                  if (saleId != null && saleId.toString().isNotEmpty) {
                    await _printReceipt(saleId);
                  }
                  await _offerContinueShopping();
                }
              } else {
                setDialogState(() => saving = false);
                Toast.error(context, body['error'] ?? 'Gagal membayar');
              }
            } catch (e) {
              setDialogState(() => saving = false);
              Toast.error(context, 'Gagal membayar');
            }
          }

          return AlertDialog(
            title: Text('Bayar booking ${booking.custName}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasType) ...[
                    Text(
                      '${booking.therapyLabel} • ${booking.duration} menit',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Harga default: ${TextFormatter.formatRupiah(_priceFor(booking.therapyType, booking.duration).toDouble())}',
                    ),
                    if (booking.price > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Harga custom tersimpan: '
                        '${TextFormatter.formatRupiah(booking.price.toDouble())} '
                        '(dipakai saat bayar kecuali diubah)',
                        style: TextStyle(
                            color: Colors.teal.shade700,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Text(
                      'Jika ada booking 30 menit bersebelahan atas nama & tipe '
                      'yang sama (belum bayar), nota otomatis digabung jadi '
                      '1 jam dengan harga 1 jam.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ] else
                    DropdownButtonFormField<ItemResponse>(
                      value: selectedItem,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Item terapi',
                        border: OutlineInputBorder(),
                      ),
                      items: _items
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                  '${item.item_name} — ${TextFormatter.formatRupiah(item.item_price.toDouble())}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedItem = v),
                    ),
                  if (_isSeller) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Harga custom'),
                      subtitle: Text(useCustomPrice
                          ? 'Input harga sendiri'
                          : 'Pakai harga default'),
                      value: useCustomPrice,
                      onChanged: (v) =>
                          setDialogState(() => useCustomPrice = v),
                    ),
                    if (useCustomPrice)
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga custom (Rp)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('BATAL'),
              ),
              ElevatedButton(
                onPressed: saving ? null : pay,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('BAYAR & CETAK NOTA'),
              ),
            ],
          );
        });
      },
    );
  }

  /// Setelah booking/pembayaran sukses, tawarkan lanjut beli item stock
  /// (mis. minuman) lewat menu Point of Sale.
  Future<void> _offerContinueShopping() async {
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah Pembelian'),
        content: const Text(
            'Lanjut tambah pembelian item (mis. minuman) di Point of Sale?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('NANTI'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('LANJUT'),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      Navigator.pushNamed(context, _isSeller ? '/penjualan' : '/belanja');
    }
  }

  /// Hapus booking UNPAID (penjual/admin) — tercatat di booking_remove_log.
  Future<void> _removeBooking(SlotBookingModel booking) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Booking'),
        content: Text('Hapus booking ${booking.custName} jam ${booking.start}? '
            'Penghapusan tercatat di log.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final response = await _bookingApi.removeBooking(booking.bookingId);
      if (response.statusCode == 200) {
        if (mounted) Toast.success(context, 'Booking dihapus');
        await _loadSlots();
      } else {
        String message = 'Gagal menghapus booking';
        try {
          message = jsonDecode(response.body)['error'] ?? message;
        } catch (_) {}
        if (mounted) Toast.error(context, message);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal menghapus booking');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Booking Terapi'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSlots,
            ),
          ],
        ),
        drawer: const AppDrawer(),
        body: Column(
          children: [
            // Pilih tanggal + legenda
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                              DateFormat('dd-MM-yyyy').format(_selectedDate)),
                          onPressed: _pickDate,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legend(Colors.green.shade400, 'Tersedia'),
                      const SizedBox(width: 12),
                      _legend(Colors.amber.shade400, 'Belum bayar'),
                      const SizedBox(width: 12),
                      _legend(Colors.red.shade400, 'Penuh (fix)'),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadSlots,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.6,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _slots.length,
                        itemBuilder: (context, index) {
                          final slot = _slots[index];
                          final color = _slotColor(slot);
                          return InkWell(
                            onTap: () => slot.bookings.isEmpty
                                ? _showBookingDialog(slot)
                                : _showSlotDetail(slot),
                            child: Container(
                              decoration: BoxDecoration(
                                color: slot.past ? Colors.grey.shade400 : color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    slot.start,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '${slot.used}/${slot.capacity}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
