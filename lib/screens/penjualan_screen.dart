import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/private_route.dart';
import '../widgets/modal_wrapper.dart';
import '../widgets/currency_input.dart';
import '../services/stock_api.dart';
import '../models/stock_model.dart';
import '../models/sales_item_model.dart';
import '../models/api_response_model.dart';
import '../providers/cart_provider.dart';
import '../providers/language_provider.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../utils/debouncer.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../extensions/string_extension.dart';

class PenjualanScreen extends StatefulWidget {
  const PenjualanScreen({super.key});

  @override
  State<PenjualanScreen> createState() => _PenjualanScreenState();
}

class _PenjualanScreenState extends State<PenjualanScreen> {
  final _stockApi = StockApi();
  final _debouncer = Debouncer(milliseconds: 400);

  // Form controllers
  final _receiptController = TextEditingController();
  final _transactionDateController = TextEditingController();
  final _salesPersonController = TextEditingController();
  final _typeController = TextEditingController();

  // Add product modal controllers
  final _itemCodeController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _qtyController = TextEditingController();
  // Payment modal controllers
  final _cashAmountController = TextEditingController();
  final _salesNameController = TextEditingController();
  final _salesStockIDController = TextEditingController();

  final stockArrNotifier = ValueNotifier<List<StockModel>>([]);

  StockModel? _currentStock;

  int? _editingIndex;
  int lengths = 5;
  int pages = 1;

  bool _isLoadingSuggestions = false;

  ValueNotifier<StockPagination?> stockPaginationNotifier = ValueNotifier(null);

  List<StockResponse> _stockSuggestions = [];
  List<StockModel> _stockListSuggestions = [];
  List<StockResponse> _stockList = [];

  TextEditingController? _autoCompleteController;
  FocusNode _autoCompleteFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _transactionDateController.text = DateTime.now().toString();
    _loadUserName();
    _typeController.text = 'Cash';
  }

  Future<void> _loadUserName() async {
    final name = await Storage.get('userNIP');
    if (!mounted) return;

    setState(() {
      _salesPersonController.text = name?.toTitleCase() ?? 'Guest';
    });
  }

  @override
  void dispose() {
    _receiptController.dispose();
    _transactionDateController.dispose();
    _salesPersonController.dispose();
    _typeController.dispose();
    _itemCodeController.dispose();
    _itemNameController.dispose();
    _qtyController.dispose();
    _cashAmountController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _searchProduct(String code) async {
    try {
      final response = await _stockApi.getOneStock('', code);
      if (response.statusCode == 200) {
        final apiResponse = ApiResponse<StockModel>.fromJson(
          jsonDecode(response.body),
          (json) => StockModel.fromJson(json),
        );

        if (mounted && apiResponse.isSuccess) {
          setState(() {
            _currentStock = apiResponse.data;
            _itemNameController.text = apiResponse.data?.stockName ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error searching product: $e');
    }
  }

  Future<void> getAllStock(String name, int page, int length) async {
    try {
      final outcode = await Storage.get('outcode') ?? '';
      final stockApi = StockApi();

      final response = await stockApi.getAllStock(name, outcode, page, length);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // final pagination = ItemPagination.fromJson(data);
        final pagination = StockPagination.fromJson(data);

        stockPaginationNotifier.value = pagination;

        pages = page;
        lengths = length;

        // itemsPaginationNotifier.value = pagination;
        _stockList = pagination.data;
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

  void addNewSales(value) {
    _salesNameController.text = value;
    // _debouncerSuggestion.run(() => getAllItems(value));
  }

  void addSelectedSales(value) {
    _salesNameController.text = value.stock_name;
    _salesStockIDController.text = value.stock_id;
    _autoCompleteController?.text = value.stock_name;
    _autoCompleteFocusNode.unfocus();
  }

  void _showAddProductModal(
      BuildContext context, LanguageProvider langProvider) {
    _itemCodeController.clear();
    _itemNameController.clear();
    _qtyController.clear();
    _currentStock = null;

    showModalDialog(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            langProvider.get('Add Product', 'Tambah Produk'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Item Code + Search button
          Row(
            children: [
              // Expanded(
              //   child: TextField(
              //     controller: _itemCodeController,
              //     decoration: InputDecoration(
              //       labelText: langProvider.get('Item Name', 'Nama Barang'),
              //       border: const OutlineInputBorder(),
              //     ),
              //   ),
              // ),
              // const SizedBox(width: 8),
              // IconButton(
              //   icon: const Icon(Icons.search),
              //   onPressed: () {
              //     _debouncer
              //         .run(() => _searchProduct(_itemCodeController.text));
              //   },
              // ),
              Expanded(
                child: ValueListenableBuilder<StockPagination?>(
                  valueListenable: stockPaginationNotifier,
                  builder: (context, pagination, _) {
                    // final items = pagination?.data ?? [];

                    return Autocomplete<StockResponse>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        final items = stockPaginationNotifier.value?.data ?? [];

                        final query = textEditingValue.text.toLowerCase();
                        if (textEditingValue.text.isEmpty) {
                          return items;
                        }
                        return items.where((item) =>
                            item.stock_name.toLowerCase().startsWith(query));
                      },
                      displayStringForOption: (option) =>
                          option.stock_name + " " + option.stock_qty.toString(),
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            child: Container(
                              width: 500,
                              constraints: const BoxConstraints(maxHeight: 200),
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
                                              leading:
                                                  const Icon(Icons.inventory_2),
                                              title:
                                                  Text(suggestion.stock_name),
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
                        addSelectedSales(selection);
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                        _autoCompleteController = controller;
                        _autoCompleteFocusNode = focusNode;
                        return TextField(
                          controller: controller,
                          focusNode: _autoCompleteFocusNode,
                          decoration: InputDecoration(
                            hintText:
                                langProvider.get('Enter name', 'Masukkan nama'),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (value) {
                            addNewSales(value);
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

          // Quantity
          TextField(
            controller: _qtyController,
            enabled: _currentStock != null,
            keyboardType: TextInputType.number,
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
                  onPressed: null,
                  child: Row(
                    children: [
                      // Text(langProvider.get('ADD MORE', 'ADD MORE')),
                      const Icon(Icons.add, size: 18, color: Colors.blue),
                    ],
                  )),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed:
                    _currentStock != null && _qtyController.text.isNotEmpty
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
      ),
    );
  }

  void _addToCart(BuildContext context) {
    if (_currentStock == null) return;

    final qty = int.tryParse(_qtyController.text) ?? 0;
    if (qty <= 0) return;

    final item = SalesItemModel.create(
      // stockCode: _currentStock!.stockCode,
      stockCode: "",
      stockName: _currentStock!.stockName,
      qty: qty,
      // stockPack: _currentStock!.stockPack,
      // price: _currentStock!.stockPrice,
      stockPack: "",
      price: 0,
    );

    Provider.of<CartProvider>(context, listen: false).addItem(item);
  }

  void _showPaymentModal(
      BuildContext context, LanguageProvider langProvider, CartProvider cart) {
    _cashAmountController.clear();

    showModalDialog(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            langProvider.get('Payment', 'Pembayaran'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Payment Type
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
                child: Text(langProvider.get('Bank Transfer', 'Transfer Bank')),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                cart.setPaymentType(value);
              }
            },
          ),
          const SizedBox(height: 16),

          // Cash Amount (only for TUNAI)
          if (cart.paymentType == AppConstants.paymentCash)
            CurrencyInput(
              controller: _cashAmountController,
              labelText: langProvider.get('Amount', 'Jumlah'),
              onChanged: (value) {
                cart.setCashAmount(value);
              },
            ),

          const SizedBox(height: 24),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  cart.setPaymentType('');
                  cart.setCashAmount(0);
                  Navigator.pop(context);
                },
                child: Text(langProvider.get('CANCEL', 'BATAL')),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: cart.canSave ? () => Navigator.pop(context) : null,
                child: Text(langProvider.get('OK', 'OK')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      child: Consumer2<CartProvider, LanguageProvider>(
        builder: (context, cart, langProvider, child) {
          return Scaffold(
            appBar: AppBarCustom(
              title: langProvider.get('Point of Sale', 'Penjualan'),
            ),
            drawer: const AppDrawer(),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Form
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _transactionDateController,
                                  enabled: false,
                                  decoration: InputDecoration(
                                    labelText:
                                        langProvider.get('Now', 'Sekarang'),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _receiptController,
                                  decoration: InputDecoration(
                                    labelText: langProvider.get(
                                        'Receipt Number', 'No. Nota'),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  enabled: false,
                                  controller: _salesPersonController,
                                  decoration: InputDecoration(
                                    labelText: langProvider.get(
                                        'Sales Person', 'Kasir'),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _typeController,
                                  enabled: false,
                                  decoration: InputDecoration(
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
                  ),
                  const SizedBox(height: 16),

                  // Add Product Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        langProvider.get('Sales Items', 'Item Penjualan'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _showAddProductModal(context, langProvider),
                        icon: const Icon(Icons.add),
                        label: Text(
                            langProvider.get('Add Product', 'Tambah Produk')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Cart Table
                  _buildCartTable(cart, langProvider),
                  const SizedBox(height: 16),

                  // Payment Summary
                  _buildPaymentSummary(cart, langProvider),
                  const SizedBox(height: 24),

                  // Bottom Buttons
                  _buildBottomButtons(context, cart, langProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCartTable(CartProvider cart, LanguageProvider langProvider) {
    if (cart.items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Text(
              langProvider.get(
                  'No items in cart', 'Tidak ada item di keranjang'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        columns: [
          DataColumn(label: Text(langProvider.get('No', 'No'))),
          DataColumn(label: Text(langProvider.get('Code', 'Kode'))),
          DataColumn(label: Text(langProvider.get('Name', 'Nama'))),
          DataColumn(label: Text(langProvider.get('Qty', 'Jumlah'))),
          DataColumn(label: Text(langProvider.get('Unit', 'Satuan'))),
          DataColumn(label: Text(langProvider.get('Price', 'Harga'))),
          DataColumn(label: Text(langProvider.get('Sub Total', 'Sub Total'))),
          DataColumn(label: Text(langProvider.get('Action', 'Aksi'))),
        ],
        rows: cart.items
            .asMap()
            .entries
            .map(
              (entry) => DataRow(
                cells: [
                  DataCell(Text('${entry.key + 1}')),
                  DataCell(Text(entry.value.stockCode)),
                  DataCell(Text(entry.value.stockName)),
                  DataCell(
                    _editingIndex == entry.key
                        ? SizedBox(
                            width: 60,
                            child: TextField(
                              controller: TextEditingController(
                                  text: '${entry.value.stockQty}'),
                              keyboardType: TextInputType.number,
                              onSubmitted: (value) {
                                final newQty =
                                    int.tryParse(value) ?? entry.value.stockQty;
                                cart.updateItemQty(entry.key, newQty);
                                setState(() => _editingIndex = null);
                              },
                            ),
                          )
                        : Text('${entry.value.stockQty}'),
                  ),
                  DataCell(Text(entry.value.stockPack)),
                  DataCell(
                      Text(TextFormatter.formatRupiah(entry.value.stockPrice))),
                  DataCell(Text(
                      TextFormatter.formatRupiah(entry.value.stockTotalSales))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                              _editingIndex == entry.key
                                  ? Icons.save
                                  : Icons.edit,
                              size: 20),
                          onPressed: () {
                            setState(() {
                              _editingIndex =
                                  _editingIndex == entry.key ? null : entry.key;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          color: Colors.red,
                          onPressed: () => cart.removeItem(entry.key),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPaymentSummary(
      CartProvider cart, LanguageProvider langProvider) {
    return Card(
      color: Colors.blue[50],
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
              langProvider.get('Total:', 'Total:'),
              TextFormatter.formatRupiah(cart.total),
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
                ? () {
                    cart.clear();
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
            onPressed: cart.canSave
                ? () {
                    // TODO: Implement save transaction
                    Toast.success(
                      context,
                      langProvider.get(
                          'Transaction saved!', 'Transaksi disimpan!'),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2cae6b),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(langProvider.get('SAVE', 'SIMPAN')),
          ),
        ),
      ],
    );
  }
}
