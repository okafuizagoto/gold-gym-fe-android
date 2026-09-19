import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/buyer_cart_provider.dart';
import '../services/sales_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/buyer_outlet_picker.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import 'receipt_preview_screen.dart';

/// Point of Sale mode pembeli: pilih outlet tujuan (mis. outlet TEST),
/// keranjang diisi dari menu List Barang (BuyerCartProvider bersama),
/// lalu checkout → satu nota; jika akun punya nama toko (gold_toko),
/// nota menampilkan keterangan pembeli dengan nama toko tersebut.
class BuyerShopScreen extends StatefulWidget {
  const BuyerShopScreen({super.key});

  @override
  State<BuyerShopScreen> createState() => _BuyerShopScreenState();
}

class _BuyerShopScreenState extends State<BuyerShopScreen> {
  final _salesApi = SalesApi();

  bool _isSaving = false;
  String _buyerName = '';
  int _buyerGoldId = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _buyerName = await Storage.get(AppConstants.userNIPKey) ?? '';
    _buyerGoldId =
        int.tryParse(await Storage.get(AppConstants.userGoldIdKey) ?? '') ?? 0;
  }

  Map<String, dynamic> _buildPayload(BuyerCartProvider cart, bool paid) {
    final total = cart.total.toStringAsFixed(0);
    return {
      'data': {
        'header': {
          'sale_outcode': cart.outcode,
          'sale_transtotal': total,
          'sale_transpayment': paid ? total : '0',
          'sale_transchange': '0',
          'sale_salesperson': 'ONLINE',
          'sale_salescustomer': _buyerName,
          'sale_paymentyn': paid ? 'Y' : 'N',
          // gold_id pembeli login → nota menampilkan nama toko (jika ada)
          'sale_cust_id': _buyerGoldId,
        },
        'detail': cart.lines
            .map((line) => {
                  'sale_stockid': line.stock.stock_id,
                  'sale_stockname': line.stock.stock_name,
                  'sale_qty': line.qty,
                  'sale_salesprice':
                      line.stock.stock_price.toDouble().toStringAsFixed(0),
                  'sale_totalsalesprice': line.total.toStringAsFixed(0),
                  'sale_pack': line.stock.stock_pack,
                })
            .toList(),
      }
    };
  }

  /// Pilih foto bukti pembayaran (kamera/galeri), validasi maks 5 MB.
  Future<File?> _pickProofImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Foto Bukti Pembayaran'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ImageSource.camera),
            child: const Row(children: [
              Icon(Icons.photo_camera_outlined),
              SizedBox(width: 8),
              Text('Ambil dari Kamera'),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ImageSource.gallery),
            child: const Row(children: [
              Icon(Icons.photo_library_outlined),
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

  Future<void> _checkout(BuyerCartProvider cart) async {
    if (!cart.hasOutlet) {
      Toast.error(context, 'Pilih outlet tujuan belanja dulu');
      return;
    }
    if (cart.lines.isEmpty) {
      Toast.error(context, 'Keranjang masih kosong — tambah dari List Barang');
      return;
    }

    // pilih cara bayar: BELUM BAYAR / TUNAI / TRANSFER BANK (wajib bukti foto)
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi Pembelian'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Outlet: ${cart.outletName.toUpperCase()}'),
              const SizedBox(height: 4),
              Text(
                  'Total: ${TextFormatter.formatRupiah(cart.total)} (${cart.itemCount} barang)'),
              const SizedBox(height: 12),
              const Text('Pilih jenis pembayaran:'),
            ],
          ),
        ),
        // OverflowBar: tombol turun baris sendiri di HP sempit
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'UNPAID'),
            child: const Text('BELUM BAYAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successDark,
            ),
            onPressed: () => Navigator.pop(dialogContext, 'TUNAI'),
            child: const Text('TUNAI'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, 'BANK'),
            child: const Text('TRANSFER BANK'),
          ),
        ],
      ),
    );
    if (choice == null) return;

    File? proof;
    if (choice == 'BANK') {
      proof = await _pickProofImage();
      if (proof == null) {
        if (mounted) {
          Toast.error(context, 'Transfer bank butuh foto bukti pembayaran');
        }
        return;
      }
    }
    final paid = choice != 'UNPAID';

    setState(() => _isSaving = true);
    try {
      final response = await _salesApi.insertSales(_buildPayload(cart, paid));
      if (response.statusCode == 202 || response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final saleId = body['sale_id']?.toString() ?? '';
        cart.clear();
        if (mounted) {
          Toast.success(
              context,
              paid
                  ? 'Pembelian tersimpan (LUNAS)'
                  : 'Pembelian tersimpan (BELUM LUNAS)');
        }
        // transfer bank: upload foto bukti pembayaran (butuh sale_id)
        if (choice == 'BANK' && proof != null && saleId.isNotEmpty) {
          await _uploadProof(saleId, proof);
        }
        if (saleId.isNotEmpty) {
          await _offerReceipt(saleId);
        }
      } else {
        String message = 'Gagal menyimpan pembelian';
        try {
          message = jsonDecode(response.body)['error'] ?? message;
        } catch (_) {}
        if (mounted) Toast.error(context, message);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal menyimpan pembelian');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Modal cetak struk; jika iya, PDF di-download lalu layar diarahkan
  /// ke tampilan PDF.
  Future<void> _offerReceipt(String saleId) async {
    if (!mounted) return;
    final wantPrint = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cetak Struk'),
        content: const Text('Cetak struk sekarang?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('TIDAK'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('YA, CETAK'),
          ),
        ],
      ),
    );
    if (wantPrint != true) return;

    final pdfBytes = await _salesApi.getReceiptPdfWithRetry(saleId);
    if (pdfBytes != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ReceiptPreviewScreen(pdfBytes: pdfBytes, title: 'Nota'),
        ),
      );
    } else {
      if (mounted) {
        Toast.error(context, 'Nota belum siap, coba dari Riwayat Belanja');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return PrivateRoute(
      child: Consumer<BuyerCartProvider>(
        builder: (context, cart, child) {
          final textTheme = Theme.of(context).textTheme;
          return Scaffold(
            appBar: const AppBarCustom(title: 'Point of Sale'),
            drawer: const AppDrawer(),
            body: SafeArea(
              top: false,
              child: ContentWidth(
                child: Column(
                  children: [
                    // outlet tujuan belanja terpilih (ganti via layar Pilih Outlet)
                    Padding(
                      padding: EdgeInsets.fromLTRB(pad, 12, pad, 8),
                      child: const BuyerOutletBar(),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.search_rounded, size: 18),
                          label: const Text('CARI BARANG (LIST BARANG)'),
                          onPressed: () =>
                              Navigator.pushNamed(context, '/list-barang'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // keranjang bersama (diisi dari List Barang)
                    Expanded(
                      child: cart.lines.isEmpty
                          ? EmptyState(
                              icon: Icons.shopping_cart_outlined,
                              title: cart.hasOutlet
                                  ? 'Keranjang kosong'
                                  : 'Pilih outlet tujuan belanja dulu',
                              description: cart.hasOutlet
                                  ? 'Tambahkan barang dari menu List Barang.'
                                  : null,
                              compact: context.isShort,
                            )
                          : ListView(
                              padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                              children: cart.lines
                                  .map((line) => Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          dense: true,
                                          title: Text(line.stock.stock_name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          subtitle: Text(
                                              TextFormatter.formatRupiah(
                                                  line.total)),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                icon: const Icon(Icons
                                                    .remove_circle_outline),
                                                onPressed: () =>
                                                    cart.decrease(line),
                                              ),
                                              Text('${line.qty}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                icon: const Icon(
                                                    Icons.add_circle_outline),
                                                onPressed: () {
                                                  if (!cart
                                                      .addItem(line.stock)) {
                                                    Toast.error(context,
                                                        'Stok tidak cukup');
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                    ),

                    // total + tombol beli
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: pad, vertical: 10),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border:
                            Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Total', style: textTheme.bodySmall),
                                Text(
                                  TextFormatter.formatRupiah(cart.total),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleMedium
                                      ?.copyWith(color: AppColors.blue),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(
                                    Icons.shopping_cart_checkout_rounded,
                                    size: 20),
                            label: const Text('BELI'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successDark,
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: _isSaving ? null : () => _checkout(cart),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
