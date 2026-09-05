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
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

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
              Icon(Icons.camera_alt),
              SizedBox(width: 8),
              Text('Ambil Foto'),
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
              Icon(Icons.payments, color: Colors.green),
              SizedBox(width: 12),
              Text('TUNAI (bayar di tempat)'),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(dialogContext, AppConstants.paymentTransfer),
            child: const Row(children: [
              Icon(Icons.account_balance, color: Colors.blue),
              SizedBox(width: 12),
              Text('TRANSFER (upload bukti)'),
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

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<BuyerOrderProvider>(context);

    if (!cart.hasOutlet) {
      return PrivateRoute(
        child: Scaffold(
          appBar: AppBar(title: const Text('Pesan Barang')),
          drawer: const AppDrawer(),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Pilih outlet penjual dulu',
                    style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.store),
                  label: const Text('Pilih Outlet'),
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/pilih-outlet'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PrivateRoute(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(cart.outletName.isEmpty ? 'Pesan Barang' : cart.outletName),
        ),
        drawer: const AppDrawer(),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Cari barang',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _loadCatalog('');
                    },
                  ),
                ),
                onSubmitted: _loadCatalog,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? Center(
                          child: Text('Barang tidak ditemukan',
                              style: TextStyle(color: Colors.grey[600])))
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final inCart = cart.lines
                                .where((l) => l.item.stockId == item.stockId);
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: ListTile(
                                dense: true,
                                title: Text(item.stockName),
                                subtitle: Text(
                                    '${TextFormatter.formatRupiah(item.price.toDouble())} • Stok: ${item.stockQty}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (inCart.isNotEmpty)
                                      Text('x${inCart.first.qty}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal)),
                                    IconButton(
                                      icon: const Icon(Icons.add_shopping_cart,
                                          color: Colors.teal),
                                      onPressed: () {
                                        if (cart.addItem(item)) {
                                          Toast.success(context,
                                              '${item.stockName} masuk keranjang');
                                        } else {
                                          Toast.error(
                                              context, 'Stok tidak cukup');
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            if (cart.lines.isNotEmpty) _cartBar(cart),
          ],
        ),
      ),
    );
  }

  Widget _cartBar(BuyerOrderProvider cart) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...cart.lines.map((l) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.item.stockName,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                      '${l.qty} x ${TextFormatter.formatRupiah(l.item.price.toDouble())}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: () => cart.decrease(l),
                      ),
                      Text('${l.qty}'),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: () {
                          if (!cart.addItem(l.item)) {
                            Toast.error(context, 'Stok tidak cukup');
                          }
                        },
                      ),
                    ],
                  ),
                )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(TextFormatter.formatRupiah(cart.total),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.payment),
                label: Text(_submitting ? 'Memproses...' : 'BAYAR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
                onPressed: _submitting ? null : _checkout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
