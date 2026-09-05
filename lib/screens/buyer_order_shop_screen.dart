import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/order_model.dart';
import '../providers/buyer_order_provider.dart';
import '../services/order_api.dart';
import '../services/sales_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/info_row.dart';
import '../widgets/private_route.dart';
import '../widgets/search_field.dart';

/// Mode pembeli — memesan barang dari outlet terpilih.
/// Pilih barang ke keranjang → BAYAR → pilih TUNAI / TRANSFER.
/// TUNAI langsung terkirim (belum lunas). TRANSFER wajib upload bukti.
/// Pesanan masuk daftar "Pesanan Saya" menunggu konfirmasi penjual.
class BuyerOrderShopScreen extends StatefulWidget {
  const BuyerOrderShopScreen({super.key});

  @override
  State<BuyerOrderShopScreen> createState() => _BuyerOrderShopScreenState();
}

class _BuyerOrderShopScreenState extends State<BuyerOrderShopScreen> {
  final _orderApi = OrderApi();
  final _salesApi = SalesApi();
  final _searchController = TextEditingController();
  List<CatalogItem> _items = [];
  bool _loading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCatalog(''));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog(String name) async {
    final cart = Provider.of<BuyerOrderProvider>(context, listen: false);
    if (!cart.hasOutlet) return;
    setState(() => _loading = true);
    try {
      final response =
          await _orderApi.getCatalog(cart.outletGoldId, cart.outcode, name);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        _items = ((body['data'] ?? []) as List)
            .map((e) => CatalogItem.fromJson(e))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<File?> _pickImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Bukti Transfer'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ImageSource.camera),
            child: const Row(children: [
              Icon(Icons.camera_alt_outlined),
              SizedBox(width: 8),
              Text('Ambil Foto'),
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
    if (await file.length() > 5 * 1024 * 1024) {
      if (mounted) Toast.error(context, 'Ukuran foto maksimal 5 MB');
      return null;
    }
    return file;
  }

  Future<void> _checkout() async {
    final cart = Provider.of<BuyerOrderProvider>(context, listen: false);
    if (cart.lines.isEmpty) {
      Toast.error(context, 'Keranjang masih kosong');
      return;
    }

    final payType = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Metode Pembayaran'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(dialogContext, AppConstants.paymentCash),
            child: const Row(children: [
              Icon(Icons.payments_outlined, color: AppColors.successDark),
              SizedBox(width: 12),
              Expanded(child: Text('TUNAI (bayar di tempat)')),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(dialogContext, AppConstants.paymentTransfer),
            child: const Row(children: [
              Icon(Icons.account_balance_outlined, color: AppColors.blue),
              SizedBox(width: 12),
              Expanded(child: Text('TRANSFER (upload bukti)')),
            ]),
          ),
        ],
      ),
    );
    if (payType == null) return;

    // TRANSFER: minta bukti dulu sebelum kirim pesanan — KECUALI admin
    // menyembunyikan fitur ini (Akses Admin > Visibilitas Bukti Pembayaran)
    File? proof;
    if (payType == AppConstants.paymentTransfer) {
      bool proofEnabled = true;
      try {
        final r = await _salesApi.getProofVisibility(cart.outcode);
        if (r.statusCode == 200) {
          proofEnabled = jsonDecode(r.body)['enabled'] != false;
        }
      } catch (_) {}
      if (proofEnabled) {
        proof = await _pickImage();
        if (proof == null) {
          if (mounted) Toast.error(context, 'Bukti transfer wajib diupload');
          return;
        }
      }
    }

    setState(() => _submitting = true);
    try {
      final payload = {
        "gold_id": cart.outletGoldId,
        "outcode": cart.outcode,
        "outlet_name": cart.outletName,
        "pay_type": payType,
        "lines": cart.toLinesPayload(),
      };
      final response = await _orderApi.insertOrder(payload);
      if (response.statusCode != 201 && response.statusCode != 200) {
        String msg = 'Gagal membuat pesanan';
        try {
          msg = jsonDecode(response.body)['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
        return;
      }
      final orderId = jsonDecode(response.body)['data']?['order_id'] ?? '';

      // upload bukti untuk TRANSFER (pakai endpoint proof yang sudah ada)
      if (proof != null && orderId.isNotEmpty) {
        final up = await _salesApi.uploadPaymentProof(orderId, proof);
        if (up.statusCode != 201 && up.statusCode != 200) {
          if (mounted) {
            Toast.error(context,
                'Pesanan dibuat, tapi bukti gagal terupload. Ulangi dari Pesanan Saya.');
          }
        }
      }

      cart.clear();
      if (!mounted) return;
      Toast.success(context, 'Pesanan terkirim, menunggu konfirmasi penjual');
      Navigator.pushReplacementNamed(context, '/pesanan-saya');
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal membuat pesanan: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _addItem(BuyerOrderProvider cart, CatalogItem item) {
    if (cart.addItem(item)) {
      Toast.success(context, '${item.stockName} masuk keranjang');
    } else {
      Toast.error(context, 'Stok tidak cukup');
    }
  }

  // Keranjang lengkap (ubah qty) sebagai bottom sheet -- dipakai di layar
  // pendek (HP landscape) supaya daftar barang tidak tertutup keranjang.
  void _openCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Consumer<BuyerOrderProvider>(
        builder: (context, cart, _) {
          final textTheme = Theme.of(context).textTheme;
          return ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Keranjang', style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Flexible(
                    child: cart.lines.isEmpty
                        ? const EmptyState(
                            title: 'Keranjang kosong', compact: true)
                        : ListView(
                            shrinkWrap: true,
                            children: [
                              for (final l in cart.lines)
                                _CartLineRow(line: l, cart: cart),
                            ],
                          ),
                  ),
                  const Divider(height: 16),
                  InfoRow(
                    label: 'Total',
                    value: TextFormatter.formatRupiah(cart.total),
                    highlight: true,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<BuyerOrderProvider>(context);
    final pad = context.pagePadding;

    if (!cart.hasOutlet) {
      return PrivateRoute(
        child: Scaffold(
          appBar: const AppBarCustom(title: 'Pesan Barang'),
          drawer: const AppDrawer(),
          body: PageBody(
            child: EmptyState(
              icon: Icons.storefront_outlined,
              title: 'Pilih outlet penjual dulu',
              description:
                  'Barang yang bisa dipesan mengikuti outlet penjual yang dipilih.',
              action: ElevatedButton.icon(
                icon: const Icon(Icons.store_mall_directory_outlined, size: 18),
                label: const Text('Pilih Outlet'),
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/pilih-outlet'),
              ),
            ),
          ),
        ),
      );
    }

    return PrivateRoute(
      child: Scaffold(
        appBar: AppBarCustom(
          title: cart.outletName.isEmpty ? 'Pesan Barang' : cart.outletName,
        ),
        drawer: const AppDrawer(),
        body: SafeArea(
          top: false,
          child: ContentWidth(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 12, pad, 8),
                  child: SearchField(
                    controller: _searchController,
                    hintText: 'Cari barang...',
                    onSubmitted: _loadCatalog,
                    onClear: () => _loadCatalog(''),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                          ? EmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'Barang tidak ditemukan',
                              description:
                                  'Coba kata kunci lain atau kosongkan pencarian.',
                              compact: context.isShort,
                            )
                          : GridView.builder(
                              padding: EdgeInsets.fromLTRB(pad, 4, pad, pad),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: context.columnsFor(
                                    minTileWidth: 160, max: 5),
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                mainAxisExtent: 168,
                              ),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                final inCart = cart.lines.where(
                                    (l) => l.item.stockId == item.stockId);
                                return _CatalogTile(
                                  item: item,
                                  qtyInCart:
                                      inCart.isNotEmpty ? inCart.first.qty : 0,
                                  onAdd: () => _addItem(cart, item),
                                );
                              },
                            ),
                ),
                if (cart.lines.isNotEmpty) _cartBar(cart),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cartBar(BuyerOrderProvider cart) {
    final textTheme = Theme.of(context).textTheme;
    final short = context.isShort;
    return Container(
      padding:
          EdgeInsets.fromLTRB(context.pagePadding, 10, context.pagePadding, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // di layar pendek daftar baris disembunyikan -- buka lewat tombol
          if (!short) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final l in cart.lines) _CartLineRow(line: l, cart: cart),
                ],
              ),
            ),
            const Divider(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _openCartSheet,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${cart.itemCount} barang',
                        style: textTheme.bodySmall,
                      ),
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
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.payment_rounded, size: 20),
                label: Text(_submitting ? 'Memproses...' : 'BAYAR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successDark,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: _submitting ? null : _checkout,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartLineRow extends StatelessWidget {
  final OrderCartLine line;
  final BuyerOrderProvider cart;

  const _CartLineRow({required this.line, required this.cart});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.item.stockName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${line.qty} x ${TextFormatter.formatRupiah(line.item.price.toDouble())}',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _QtyStepper(
            qty: line.qty,
            onMinus: () => cart.decrease(line),
            onPlus: () {
              if (!cart.addItem(line.item)) {
                Toast.error(context, 'Stok tidak cukup');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QtyStepper(
      {required this.qty, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded, size: 18),
            onPressed: onMinus,
          ),
          Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded, size: 18),
            onPressed: onPlus,
          ),
        ],
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  final CatalogItem item;
  final int qtyInCart;
  final VoidCallback onAdd;

  const _CatalogTile({
    required this.item,
    required this.qtyInCart,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onAdd,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.blueLight,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.inventory_2_outlined,
                        color: AppColors.blue, size: 22),
                  ),
                  const Spacer(),
                  if (qtyInCart > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.tealLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'x$qtyInCart',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealDark,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  item.stockName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
              ),
              Text(
                TextFormatter.formatRupiah(item.price.toDouble()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(color: AppColors.blue),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Stok: ${item.stockQty}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Tambah ke keranjang',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                      ),
                      icon:
                          const Icon(Icons.add_shopping_cart_rounded, size: 16),
                      onPressed: onAdd,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
