import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/stock_model.dart';
import '../providers/buyer_cart_provider.dart';
import '../services/stock_api.dart';
import '../utils/responsive.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/buyer_outlet_picker.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import '../widgets/search_field.dart';

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
      final cart = Provider.of<BuyerCartProvider>(context, listen: false);
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
      final response = await _stockApi.getAllStock(name, cart.outcode, 1, 200);
      if (response.statusCode == 200) {
        final pagination = StockPagination.fromJson(jsonDecode(response.body));
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
    final pad = context.pagePadding;
    return PrivateRoute(
      child: Scaffold(
        appBar: AppBarCustom(
          title: 'List Barang',
          actions: [
            // keranjang bersama — buka POS pembeli untuk checkout
            _CartButton(
              count: cart.itemCount,
              onTap: () => Navigator.pushNamed(context, '/belanja'),
            ),
          ],
        ),
        drawer: const AppDrawer(),
        body: SafeArea(
          top: false,
          child: ContentWidth(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
                  child: BuyerOutletBar(onRestored: () {
                    _searchController.clear();
                    _loadStocks('');
                  }),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 10, pad, 8),
                  child: SearchField(
                    controller: _searchController,
                    hintText: 'Cari barang...',
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 400),
                          () => _loadStocks(value));
                    },
                  ),
                ),
                Expanded(
                  child: !cart.hasOutlet
                      ? SingleChildScrollView(
                          child: EmptyState(
                            icon: Icons.storefront_outlined,
                            title: 'Pilih outlet tujuan belanja dulu',
                            description:
                                'Barang yang bisa dipesan mengikuti outlet yang dipilih.',
                            compact: context.isShort,
                            action: OutlinedButton.icon(
                              icon: const Icon(
                                  Icons.store_mall_directory_outlined,
                                  size: 18),
                              label: const Text('Pilih Outlet'),
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/pilih-outlet'),
                            ),
                          ),
                        )
                      : _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _stocks.isEmpty
                              ? SingleChildScrollView(
                                  child: EmptyState(
                                    icon: Icons.search_off_rounded,
                                    title: 'Barang tidak ditemukan',
                                    description:
                                        'Coba kata kunci lain atau kosongkan pencarian.',
                                    compact: context.isShort,
                                  ),
                                )
                              : GridView.builder(
                                  padding:
                                      EdgeInsets.fromLTRB(pad, 4, pad, pad),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: context.columnsFor(
                                        minTileWidth: 160, max: 5),
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    mainAxisExtent: 168,
                                  ),
                                  itemCount: _stocks.length,
                                  itemBuilder: (context, index) {
                                    final stock = _stocks[index];
                                    final inCart = cart.lines.where((l) =>
                                        l.stock.stock_id == stock.stock_id);
                                    return _StockTile(
                                      stock: stock,
                                      qtyInCart: inCart.isNotEmpty
                                          ? inCart.first.qty
                                          : 0,
                                      onAdd: () => _addToCart(stock),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _CartButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined),
          tooltip: 'Buka Point of Sale',
          onPressed: onTap,
        ),
        if (count > 0)
          Positioned(
            top: 6,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _StockTile extends StatelessWidget {
  final StockResponse stock;
  final int qtyInCart;
  final VoidCallback onAdd;

  const _StockTile({
    required this.stock,
    required this.qtyInCart,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = stock.isTherapy ? AppColors.tealDark : AppColors.blue;
    final accentBg =
        stock.isTherapy ? AppColors.tealLight : AppColors.blueLight;
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
                      color: accentBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      stock.isTherapy
                          ? Icons.spa_outlined
                          : Icons.inventory_2_outlined,
                      color: accent,
                      size: 22,
                    ),
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
                  stock.stock_name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
              ),
              Text(
                TextFormatter.formatRupiah(stock.stock_price.toDouble()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(color: AppColors.blue),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stock.isTherapy ? 'Jasa' : 'Stok: ${stock.stock_qty}',
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
