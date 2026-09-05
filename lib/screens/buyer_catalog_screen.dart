import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/stock_model.dart';
import '../providers/buyer_cart_provider.dart';
import '../services/stock_api.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/app_drawer.dart';
import '../widgets/buyer_outlet_picker.dart';
import '../widgets/private_route.dart';

/// Menu List Barang (mode pembeli): pilih outlet tujuan, cari barang,
/// lalu tambahkan ke keranjang. Keranjang dipakai bersama dengan menu
/// Point of Sale pembeli (BuyerCartProvider) — barang yang ditambahkan
/// di sini langsung muncul di keranjang POS untuk di-checkout.
class BuyerCatalogScreen extends StatefulWidget {
  const BuyerCatalogScreen({super.key});

  @override
  State<BuyerCatalogScreen> createState() => _BuyerCatalogScreenState();
}

class _BuyerCatalogScreenState extends State<BuyerCatalogScreen> {
  final _stockApi = StockApi();
  final _searchController = TextEditingController();

  List<StockResponse> _stocks = [];
  Timer? _debounce;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart =
          Provider.of<BuyerCartProvider>(context, listen: false);
      if (cart.hasOutlet) _loadStocks('');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStocks(String name) async {
    final cart = Provider.of<BuyerCartProvider>(context, listen: false);
    if (!cart.hasOutlet) return;
    setState(() => _loading = true);
    try {
      final response =
          await _stockApi.getAllStock(name, cart.outcode, 1, 200);
      if (response.statusCode == 200) {
        final pagination =
            StockPagination.fromJson(jsonDecode(response.body));
        setState(() => _stocks = pagination.data);
      } else {
        if (mounted) Toast.error(context, 'Gagal memuat barang');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memuat barang');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addToCart(StockResponse stock) {
    final cart = Provider.of<BuyerCartProvider>(context, listen: false);
    if (cart.addItem(stock)) {
      Toast.success(context, '${stock.stock_name} masuk keranjang');
    } else {
      Toast.error(context, 'Stok tidak cukup');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<BuyerCartProvider>(context);
    return PrivateRoute(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('List Barang'),
          actions: [
            // keranjang bersama — buka POS pembeli untuk checkout
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  tooltip: 'Buka Point of Sale',
                  onPressed: () =>
                      Navigator.pushNamed(context, '/belanja'),
                ),
                if (cart.itemCount > 0)
                  Positioned(
                    top: 8,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        drawer: const AppDrawer(),
        body: Column(
          children: [
            BuyerOutletBar(onRestored: () {
              _searchController.clear();
              _loadStocks('');
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Cari barang',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400),
                      () => _loadStocks(value));
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: !cart.hasOutlet
                  ? Center(
                      child: Text(
                        'Pilih outlet tujuan belanja dulu',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _stocks.isEmpty
                          ? Center(
                              child: Text(
                                'Barang tidak ditemukan',
                                style:
                                    TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _stocks.length,
                              itemBuilder: (context, index) {
                                final stock = _stocks[index];
                                final inCart = cart.lines.where((l) =>
                                    l.stock.stock_id == stock.stock_id);
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  child: ListTile(
                                    title: Text(stock.stock_name),
                                    subtitle: Text(stock.isTherapy
                                        ? '${TextFormatter.formatRupiah(stock.stock_price.toDouble())} • Jasa'
                                        : '${TextFormatter.formatRupiah(stock.stock_price.toDouble())} • Stok: ${stock.stock_qty}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (inCart.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(
                                                    right: 4),
                                            child: Text(
                                              'x${inCart.first.qty}',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  color: Colors.teal),
                                            ),
                                          ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.add_shopping_cart,
                                              color: Colors.teal),
                                          onPressed: () =>
                                              _addToCart(stock),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
