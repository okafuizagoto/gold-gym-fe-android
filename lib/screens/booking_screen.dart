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
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
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
    if (slot.full) return AppColors.error; // fix, tidak bisa digantikan
    if (slot.hasUnpaid) return AppColors.warning; // ada yang belum bayar
    return AppColors.success; // tersedia
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

          final textTheme = Theme.of(context).textTheme;
          return AlertDialog(
            title: Text('Booking ${slot.start}'),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            content: SizedBox(
              width: context.dialogMaxWidth(480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipe terapi
                    Text('Tipe terapi', style: textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
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
                    Text('Durasi', style: textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('30 menit'),
                          selected: duration == 30,
                          onSelected: (_) =>
                              setDialogState(() => duration = 30),
                        ),
                        ChoiceChip(
                          label: const Text('1 jam'),
                          selected: duration == 60,
                          onSelected: (_) =>
                              setDialogState(() => duration = 60),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.blueLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        'Harga ${_therapyLabel(therapyType)} ${duration == 60 ? "1 jam" : "30 menit"}: '
                        '${TextFormatter.formatRupiah(_priceFor(therapyType, duration).toDouble())}',
                        style: textTheme.titleSmall
                            ?.copyWith(color: AppColors.blueDark),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pembeli (khusus penjual; pembeli otomatis atas nama sendiri)
                    if (_isSeller) ...[
                      TextField(
                        controller: buyerSearchController,
                        decoration: const InputDecoration(
                          labelText: 'Cari pembeli terdaftar',
                          prefixIcon: Icon(Icons.search_rounded),
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
                          margin: const EdgeInsets.only(top: 6),
                          constraints: const BoxConstraints(maxHeight: 140),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            children: buyerSuggestions
                                .map((b) => ListTile(
                                      dense: true,
                                      leading: const Icon(
                                          Icons.verified_user_rounded,
                                          color: AppColors.tealDark,
                                          size: 18),
                                      title: Text(b.nama,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      subtitle: Text(b.email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
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
                            avatar: const Icon(Icons.verified_user_rounded,
                                color: AppColors.tealDark, size: 16),
                            backgroundColor: AppColors.tealLight,
                            label: Text(
                              '${selectedBuyer!.nama} (TERDAFTAR)',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.tealDark),
                            ),
                            onDeleted: () => setDialogState(() {
                              selectedBuyer = null;
                              buyerSearchController.clear();
                            }),
                            deleteIconColor: AppColors.tealDark,
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        enabled: selectedBuyer == null,
                        decoration: const InputDecoration(
                          labelText: 'Atau nama pembeli (belum terdaftar)',
                          isDense: true,
                          helperText:
                              'Nama manual ditandai sebagai BELUM TERDAFTAR',
                          helperMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                            isDense: true,
                          ),
                        ),
                    ],
                  ],
                ),
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
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: context.screenHeight * 0.9,
        maxWidth: 720,
      ),
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    children: [
                      Text(
                        'Slot ${slot.start} - ${slot.end}  (${slot.used}/${slot.capacity})',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _legend(AppColors.warning, 'Belum bayar'),
                          _legend(AppColors.error, 'Sudah bayar'),
                          _legend(AppColors.success, 'Tersedia'),
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
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_seat_rounded,
                            color: AppColors.successDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${slot.available} tempat masih tersedia',
                            style: const TextStyle(
                              color: AppColors.successDark,
                              fontWeight: FontWeight.bold,
                            ),
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
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('BOOKING SLOT INI'),
                        onPressed: () {
                          Navigator.pop(context);
                          _showBookingDialog(slot);
                        },
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 12),
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
    final accent = b.isPaid ? AppColors.error : AppColors.warning;
    final accentDark = b.isPaid ? AppColors.errorDark : AppColors.warningDark;
    final bg = b.isPaid ? AppColors.errorLight : AppColors.warningLight;
    final textTheme = Theme.of(sheetContext).textTheme;
    final subtitle = 'Mulai ${b.start} • ${b.duration} menit'
        '${b.therapyLabel.isNotEmpty ? " • ${b.therapyLabel}" : ""}'
        '${b.price > 0 && !b.isPaid ? " • Harga custom ${TextFormatter.formatRupiah(b.price.toDouble())}" : ""}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            b.isPaid
                ? Icons.check_circle_rounded
                : Icons.hourglass_bottom_rounded,
            color: accentDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // nama pembeli wrap per kata: "tester wowza" turun jadi
                // "tester" / "wowza", tidak terpotong di tengah kata
                Text(
                  b.custName,
                  softWrap: true,
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                // badge status di bawah nama pembeli
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent,
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.chipBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('BELUM TERDAFTAR',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.muted)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: textTheme.bodySmall),
                if (_isSeller && !b.isPaid) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _showPayBookingDialog(b);
                        },
                        child: const Text('BAYAR'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.error),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _removeBooking(b);
                        },
                        child: const Text('HAPUS'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
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

          final textTheme = Theme.of(context).textTheme;
          return AlertDialog(
            title: Text(
              'Bayar booking ${booking.custName}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            content: SizedBox(
              width: context.dialogMaxWidth(480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasType) ...[
                      Text(
                        '${booking.therapyLabel} • ${booking.duration} menit',
                        style: textTheme.titleSmall,
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
                          style: const TextStyle(
                              color: AppColors.tealDark,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'Jika ada booking 30 menit bersebelahan atas nama & tipe '
                        'yang sama (belum bayar), nota otomatis digabung jadi '
                        '1 jam dengan harga 1 jam.',
                        style: textTheme.bodySmall,
                      ),
                    ] else
                      DropdownButtonFormField<ItemResponse>(
                        initialValue: selectedItem,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Item terapi',
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
                        onChanged: (v) =>
                            setDialogState(() => selectedItem = v),
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
                            isDense: true,
                          ),
                        ),
                    ],
                  ],
                ),
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
              backgroundColor: AppColors.error,
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
    final columns = context.columnsFor(minTileWidth: 100, min: 3, max: 8);
    final pad = context.pagePadding;

    return PrivateRoute(
      child: Scaffold(
        appBar: AppBarCustom(
          title: 'Booking Terapi',
          actions: [
            IconButton(
              tooltip: 'Muat ulang',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadSlots,
            ),
          ],
        ),
        drawer: const AppDrawer(),
        body: ContentWidth(
          child: Column(
            children: [
              // Pilih tanggal + legenda
              Padding(
                padding: EdgeInsets.fromLTRB(pad, pad, pad, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(
                        DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                            .format(_selectedDate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _pickDate,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        _legend(AppColors.success, 'Tersedia'),
                        _legend(AppColors.warning, 'Belum bayar'),
                        _legend(AppColors.error, 'Penuh (fix)'),
                        _legend(AppColors.disabled, 'Lewat'),
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
                        child: _slots.isEmpty
                            ? ListView(
                                children: const [
                                  EmptyState(
                                    icon: Icons.event_busy_rounded,
                                    title: 'Belum ada slot',
                                    description:
                                        'Slot terapi untuk tanggal ini belum tersedia. Coba tanggal lain atau muat ulang.',
                                  ),
                                ],
                              )
                            : GridView.builder(
                                padding: EdgeInsets.fromLTRB(pad, 4, pad, pad),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisExtent: 64,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: _slots.length,
                                itemBuilder: (context, index) {
                                  final slot = _slots[index];
                                  final color = _slotColor(slot);
                                  return Material(
                                    color:
                                        slot.past ? AppColors.disabled : color,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                    child: InkWell(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md),
                                      onTap: () => slot.bookings.isEmpty
                                          ? _showBookingDialog(slot)
                                          : _showSlotDetail(slot),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            slot.start,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            '${slot.used}/${slot.capacity}',
                                            maxLines: 1,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12),
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
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}
