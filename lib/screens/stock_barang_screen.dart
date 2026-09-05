import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/private_route.dart';
import '../services/stock_api.dart';
import '../models/stock_model.dart';
import '../models/api_response_model.dart';
import '../utils/text_formatter.dart';
import '../utils/debouncer.dart';
import '../providers/language_provider.dart';
import '../extensions/string_extension.dart';

import '../services/items_api.dart';
import '../utils/storage.dart';
import '../utils/constants.dart';

import 'package:gold_gym_fe_android/models/item_model.dart';

import 'package:flutter/services.dart';

class StockBarangScreen extends StatefulWidget {
  const StockBarangScreen({super.key});

  @override
  State<StockBarangScreen> createState() => _StockBarangScreenState();
}

class _StockBarangScreenState extends State<StockBarangScreen> {
  final _stockApi = StockApi();
  final _debouncer = Debouncer(milliseconds: 400);
  final _searchController = TextEditingController();
  final _stockItemIDController = TextEditingController();
  final _stockNameController = TextEditingController();
  final _stockPackController = TextEditingController();
  final _stockQtyController = TextEditingController();
  final stockArrNotifier = ValueNotifier<List<StockModel>>([]);
  TextEditingController? _autoCompleteController;
  // final FocusNode _autoCompleteFocusNode = FocusNode();
  FocusNode _autoCompleteFocusNode = FocusNode();

  final _debouncerSuggestion = Debouncer(milliseconds: 400);

  ValueNotifier<ItemPagination?> itemsPaginationNotifier = ValueNotifier(null);
  ValueNotifier<StockPagination?> stockPaginationNotifier = ValueNotifier(null);

  List<StockResponse> _stockSuggestions = [];
  List<StockModel> _stockListSuggestions = [];
  List<StockResponse> _stockList = [];

  String _selectedInputType = 'Keyboard';
  String userName = 'Guest';

  bool _isLoadingSuggestions = false;
  bool _isLoading = false;

  int lengths = 5;
  int pages = 1;

  ValueNotifier<StockPagination?> StockPaginationNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    // _debouncer.run(_fetchAllStock);

    _loadUserName();
    // _debouncer.run(getAllItems(""));
    // _debouncer.run(() => getAllItems(""));

    // _fetchStockSuggestions("");
  }

  @override
  void dispose() {
    _stockNameController.dispose();
    _stockPackController.dispose();
    _stockItemIDController.dispose();
    _autoCompleteFocusNode.dispose();
    _debouncerSuggestion.dispose();

    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final name = await Storage.get('userNIP');
    if (!mounted) return;

    setState(() {
      userName = name?.toTitleCase() ?? 'Guest';
      getAllItems("");
      getAllStock("", pages, lengths);
    });
  }

  Future<void> getAllItems(String name) async {
    try {
      final outcode = await Storage.get(AppConstants.outcode) ?? '';
      final itemsApi = ItemsApi();

      final response = await itemsApi.getAllItems(name, outcode, 0, 0);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final pagination = ItemPagination.fromJson(data);

        itemsPaginationNotifier.value = pagination;
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

  // Future<void> _fetchAllStock() async {
  //   setState(() => _isLoading = true);

  //   try {
  //     final response = await _stockApi.getAllStockHeader();
  //     if (response.statusCode == 200) {
  //       final apiResponse = ApiResponse<List<StockModel>>.fromJson(
  //         jsonDecode(response.body),
  //         (json) =>
  //             (json as List).map((item) => StockModel.fromJson(item)).toList(),
  //       );

  //       if (mounted) {
  //         setState(() {
  //           _stockList = apiResponse.data ?? [];
  //         });
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint('Error fetching stock: $e');
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isLoading = false);
  //     }
  //   }
  // }

  // 🔥 TAMBAHAN: Method fetch suggestions untuk autocomplete
  Future<void> _fetchStockSuggestions(String query) async {
    print("name: $query");
    // if (query.isEmpty) {
    //   setState(() => _stockSuggestions = []);
    //   return;
    // }

    setState(() => _isLoadingSuggestions = true);

    try {
      // Asumsi StockApi punya method getStockByName(query)
      print("name2: $query");
      final response = await _stockApi.getStockByName(query);
      print("response: ${response}");
      if (response.statusCode == 200) {
        final apiResponse = ApiResponse<List<StockModel>>.fromJson(
          jsonDecode(response.body),
          (json) =>
              (json as List).map((item) => StockModel.fromJson(item)).toList(),
        );
        print("RAW RESPONSE: ${response.body}");
        if (mounted) {
          setState(() => _stockListSuggestions = apiResponse.data ?? []);
        }
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingSuggestions = false);
      }
    }
  }
  // 🔥 END TAMBAHAN method suggestions

  Future<void> saveStockToBackend() async {
    Map<String, dynamic> bodyData;
    // entri form hanya divalidasi jika nama diisi — setelah tombol TAMBAH,
    // form dikosongkan dan item sudah masuk daftar, jadi form kosong + daftar
    // terisi adalah kondisi normal (dulu tetap divalidasi ke suggestion
    // sehingga muncul error "Pilih item dari daftar suggestion")
    final hasFormEntry = _stockNameController.text.trim().isNotEmpty;

    if (!hasFormEntry && stockArrNotifier.value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tolong masukkan nama stock"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final toSave = List<StockModel>.from(stockArrNotifier.value);

    if (hasFormEntry) {
      final inputName = _stockNameController.text.trim().toLowerCase();
      final allItems = itemsPaginationNotifier.value?.data ?? [];
      final isValid = allItems.any(
        (item) => item.item_name.toLowerCase() == inputName,
      );
      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pilih item dari daftar suggestion"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_stockQtyController.text == "") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tolong masukkan jumlah qty"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final outcode = await Storage.get(AppConstants.outcode) ?? '';
      final raw = _stockQtyController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final qtyFinal = int.tryParse(raw) ?? 0;
      final rawItemID =
          _stockItemIDController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final itemIDFinal = int.tryParse(rawItemID) ?? 0;

      // entri yang masih di form ikut disimpan bersama daftar
      toSave.add(StockModel(
        stockItemId: itemIDFinal,
        stockOutcode: outcode,
        stockName: _stockNameController.text,
        stockPack: _stockPackController.text,
        stockQty: qtyFinal,
        stockUpdateBy: userName,
      ));
    }

    bodyData = {
      "data": toSave
          .map((item) => {
                "stock_item_id": item.stockItemId,
                "stock_outcode": item.stockOutcode,
                "stock_name": item.stockName,
                "stock_pack": item.stockPack,
                "stock_qty": item.stockQty,
                "stock_update_by": item.stockUpdateBy,
              })
          .toList()
    };

    try {
      if (toSave.isNotEmpty) {
        final StocksApi = StockApi();
        final response = await StocksApi.insertStock(bodyData);

        if (response.statusCode == 200) {
          stockArrNotifier.value = [];
          _stockNameController.clear();
          _stockPackController.clear();
          _stockItemIDController.clear();
          _stockQtyController.clear();

          _autoCompleteController?.clear();
          _autoCompleteFocusNode.unfocus();

          // showToast("Item successfully saved");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Item successfully saved"),
              backgroundColor: Colors.green,
            ),
          );
          // await getAllStocks("", pages, lengths);
        } else {
          stockArrNotifier.value = [];
          // showToast("Failed to save item", isError: true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to save item"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please fill out all required fields"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // showToast("Failed to save item", isError: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to save item"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> addItem() async {
    final email = await Storage.get('userEmail') ?? '';
    final outcode = await Storage.get(AppConstants.outcode) ?? '';
    final inputName = _stockNameController.text.trim().toLowerCase();
    final allItems = itemsPaginationNotifier.value?.data ?? [];

    if (_stockNameController.text == "") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tolong masukkan nama stock"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isValid = allItems.any(
      (item) => item.item_name.toLowerCase() == inputName,
    );

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pilih item dari daftar suggestion"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_stockQtyController.text == "") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tolong masukkan jumlah qty"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final raw = _stockQtyController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final qtyFinal = int.tryParse(raw) ?? 0;
    final rawItemID =
        _stockItemIDController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final itemIDFinal = int.tryParse(rawItemID) ?? 0;

    final item = StockModel(
      stockItemId: itemIDFinal,
      stockOutcode: outcode,
      stockName: _stockNameController.text,
      stockPack: _stockPackController.text,
      stockQty: qtyFinal,
      stockUpdateBy: userName,
    );

    stockArrNotifier.value = [
      ...stockArrNotifier.value,
      item,
    ];

    _stockNameController.clear();
    _stockPackController.clear();
    _stockItemIDController.clear();
    _stockQtyController.clear();

    _autoCompleteController?.clear();
    // itemsPaginationNotifier.value = null;
    // optional: hilangkan fokus biar dropdown ketutup
    _autoCompleteFocusNode.unfocus();
  }

  void deleteItem(int index) {
    final updatedList = List<StockModel>.from(stockArrNotifier.value);
    updatedList.removeAt(index);

    stockArrNotifier.value = updatedList;
  }

  void addNewItem(value) {
    _stockNameController.text = value;
    // _debouncerSuggestion.run(() => getAllItems(value));
  }

  void addSelectedItem(value) {
    _stockNameController.text = value.item_name;
    _stockItemIDController.text = value.item_id.toString();
    _autoCompleteController?.text = value.item_name;
    _autoCompleteFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Consumer<LanguageProvider>(
        builder: (context, langProvider, child) {
          return DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBarCustom(
                title: langProvider.get('Stock Inventory', 'Stok Barang'),
              ),
              drawer: const AppDrawer(),
              body: Column(
                children: [
                  TabBar(
                    labelColor: Theme.of(context).primaryColor,
                    tabs: [
                      Tab(text: langProvider.get('Stock List', 'Daftar Stok')),
                      Tab(text: langProvider.get('Add Stock', 'Tambah Stok')),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildStockListTab(langProvider),
                        _buildStockDataTab(langProvider),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Widget _buildStockListTab(LanguageProvider langProvider) {
  Widget _buildStockListTab(LanguageProvider langProvider) {
    return Container(
      color: const Color(0xFFEDEFF2),
      child: Column(
        children: [
          // ===== SEARCH CARD =====
          Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      langProvider.get('Stock Management', 'Manajemen Stok'),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: langProvider.get('Search', 'Cari'),
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 50,
                          width: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2E6BC5), Color(0xFF1E4FA3)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: () => getAllStock(
                                _searchController.text, pages, lengths),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),

          // ===== FILTER BUTTONS =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _filterButton(langProvider.get('All', 'Semua'), true),
                  _filterButton(
                      langProvider.get('Low Stock', 'Stok Rendah'), false),
                  _filterButton(
                      langProvider.get('Out of Stock', 'Stok Habis'), false),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ===== STOCK LIST =====
          // Expanded(
          //   child: _isLoading
          //       ? const Center(child: CircularProgressIndicator())
          //       : _stockList.isEmpty
          //           ? Center(
          //               child: Text(
          //                 langProvider.get(
          //                     'No data available', 'Tidak ada data'),
          //               ),
          //             )
          //           : ListView.builder(
          //               padding: const EdgeInsets.symmetric(horizontal: 20),
          //               itemCount: _stockList.length,
          //               itemBuilder: (context, index) {
          //                 final item = _stockList[index];

          //                 return _stockCard(
          //                   name: item.stock_name,
          //                   qty: item.stock_qty,
          //                 );
          //               },
          //             ),
          // ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ValueListenableBuilder<StockPagination?>(
                    valueListenable: stockPaginationNotifier,
                    builder: (context, pagination, _) {
                      final items = pagination?.data ?? [];

                      if (items.isEmpty) {
                        return Center(
                          child: Text(
                            langProvider.get(
                                'No data available', 'Tidak ada data'),
                          ),
                        );
                      }

                      return Column(
                        // ✅ BARU: wrap ListView dalam Column supaya bisa tambah pagination footer
                        children: [
                          Expanded(
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return _stockCard(
                                  name: item.stock_name,
                                  qty: item.stock_qty,
                                  isTherapy: item.isTherapy,
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // ✅ BARU: showing X to Y of Z entries
                                    Text(
                                      "Showing ${((pagination!.page - 1) * pagination.limit) + 1} "
                                      "to ${((pagination.page - 1) * pagination.limit) + items.length} "
                                      "of ${pagination.totalData} entries",
                                      style:
                                          const TextStyle(color: Colors.grey),
                                    ),

                                    // ✅ BARU: dropdown limit per page
                                    DropdownButton<int>(
                                      value: pagination.limit,
                                      items: const [5, 10, 20, 50]
                                          .map((e) => DropdownMenuItem(
                                                value: e,
                                                child: Text("$e"),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        getAllStock(
                                            _searchController.text, 1, value!);
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // ✅ BARU: tombol prev/next page
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left),
                                      onPressed: pagination.page > 1
                                          ? () => getAllStock(
                                              _searchController.text,
                                              pagination.page - 1,
                                              pagination.limit)
                                          : null,
                                    ),
                                    Text(
                                      "${pagination.page} / ${pagination.totalPage}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed:
                                          pagination.page < pagination.totalPage
                                              ? () => getAllStock(
                                                    _searchController.text,
                                                    pagination.page + 1,
                                                    pagination.limit,
                                                  )
                                              : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockDataTab(LanguageProvider langProvider) {
    return Container(
      color: const Color(0xFFEDEFF2),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: SizedBox(
            width: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== BASIC INFORMATION =====
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6F8),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 22),
                          const SizedBox(width: 12),
                          Text(
                            langProvider.get(
                                'Basic Information', 'Informasi Dasar'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // // Stock Code
                      // Row(
                      //   children: [
                      //     SizedBox(
                      //       width: 150,
                      //       child: Text(
                      //         langProvider.get('Stock Code', 'Kode Stock') + ":",
                      //         style: const TextStyle(fontSize: 16),
                      //       ),
                      //     ),
                      //     Expanded(
                      //       child: TextField(
                      //         readOnly: true,
                      //         controller: TextEditingController(
                      //             text: "ITM-0001   Auto Generated"),
                      //         decoration: InputDecoration(
                      //           filled: true,
                      //           fillColor: Colors.white,
                      //           border: OutlineInputBorder(
                      //             borderRadius: BorderRadius.circular(8),
                      //           ),
                      //           contentPadding: const EdgeInsets.symmetric(
                      //               horizontal: 16, vertical: 14),
                      //         ),
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      // const SizedBox(height: 20),

                      // Stock Name
                      Row(
                        children: [
                          // SizedBox(
                          //   width: 150,
                          //   child: Text(
                          //     langProvider.get('Stock Name', 'Nama Stock') + ":",
                          //     style: const TextStyle(fontSize: 16),
                          //   ),
                          // ),
                          // Expanded(
                          //   child: TextField(
                          //     decoration: InputDecoration(
                          //       hintText: langProvider.get(
                          //           'Enter name', 'Masukkan nama'),
                          //       filled: true,
                          //       fillColor: Colors.white,
                          //       border: OutlineInputBorder(
                          //         borderRadius: BorderRadius.circular(8),
                          //       ),
                          //       contentPadding: const EdgeInsets.symmetric(
                          //           horizontal: 16, vertical: 14),
                          //     ),
                          //   ),
                          // ),
                          SizedBox(
                            width: 150,
                            child: Text(
                              langProvider.get('Stock Name', 'Nama Stock') +
                                  ":",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Expanded(
                            child: ValueListenableBuilder<ItemPagination?>(
                              valueListenable: itemsPaginationNotifier,
                              builder: (context, pagination, _) {
                                // final items = pagination?.data ?? [];

                                return Autocomplete<ItemResponse>(
                                  optionsBuilder:
                                      (TextEditingValue textEditingValue) {
                                    final items =
                                        itemsPaginationNotifier.value?.data ??
                                            [];

                                    final query =
                                        textEditingValue.text.toLowerCase();
                                    if (textEditingValue.text.isEmpty) {
                                      return items;
                                    }
                                    return items.where((item) => item.item_name
                                        .toLowerCase()
                                        .startsWith(query));
                                  },
                                  displayStringForOption: (option) =>
                                      option.item_name,
                                  optionsViewBuilder:
                                      (context, onSelected, options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 4.0,
                                        child: Container(
                                          width: 500,
                                          constraints: const BoxConstraints(
                                              maxHeight: 200),
                                          child: _isLoadingSuggestions
                                              ? const Center(
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.all(16.0),
                                                    child: SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2),
                                                    ),
                                                  ),
                                                )
                                              : options.isEmpty
                                                  ? const ListTile(
                                                      leading: Icon(
                                                          Icons.search_off),
                                                      title: Text(
                                                          'Tidak ada hasil'),
                                                    )
                                                  : ListView.separated(
                                                      padding: EdgeInsets.zero,
                                                      itemCount: options.length,
                                                      separatorBuilder:
                                                          (_, __) =>
                                                              const Divider(
                                                                  height: 1),
                                                      itemBuilder:
                                                          (context, index) {
                                                        final suggestion =
                                                            options.elementAt(
                                                                index);
                                                        return ListTile(
                                                          dense: true,
                                                          leading: const Icon(
                                                              Icons
                                                                  .inventory_2),
                                                          title: Text(suggestion
                                                              .item_name),
                                                          onTap: () =>
                                                              onSelected(
                                                                  suggestion),
                                                        );
                                                      },
                                                    ),
                                        ),
                                      ),
                                    );
                                  },
                                  onSelected: (ItemResponse selection) {
                                    addSelectedItem(selection);
                                  },
                                  fieldViewBuilder: (context, controller,
                                      focusNode, onFieldSubmitted) {
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
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        addNewItem(value);
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Stock Type
                      Row(
                        children: [
                          SizedBox(
                            width: 150,
                            child: Text(
                              langProvider.get('Stock Qty', 'Jumlah Stock') +
                                  ":",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Expanded(
                            // child: DropdownButtonFormField<String>(
                            child: TextField(
                              controller: _stockQtyController, // ✅ WAJIB ini
                              keyboardType:
                                  TextInputType.number, // ✅ keyboard angka
                              inputFormatters: [
                                FilteringTextInputFormatter
                                    .digitsOnly, // ✅ hanya angka
                              ],
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                hintText: langProvider.get(
                                    'Enter Qty', 'Masukkan jumlah item'),
                              ),
                              // hint: Text(langProvider.get(
                              //     'Select Type', 'Pilih Tipe')),
                              // items: const [],
                              onChanged: (value) {
                                _stockQtyController.text;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // // Stock Brand
                      // Row(
                      //   children: [
                      //     SizedBox(
                      //       width: 150,
                      //       child: Text(
                      //         langProvider.get('Stock Type', 'Tipe Stock') +
                      //             ":",
                      //         style: const TextStyle(fontSize: 16),
                      //       ),
                      //     ),
                      //     Expanded(
                      //       child: TextField(
                      //         decoration: InputDecoration(
                      //           filled: true,
                      //           fillColor: Colors.white,
                      //           border: OutlineInputBorder(
                      //             borderRadius: BorderRadius.circular(8),
                      //           ),
                      //           contentPadding: const EdgeInsets.symmetric(
                      //               horizontal: 16, vertical: 14),
                      //           hintText: langProvider.get(
                      //               'Enter Type', 'Masukkan tipe'),
                      //         ),
                      //         // hint: Text(langProvider.get(
                      //         //     'Select Brand', 'Pilih Merek')),
                      //         // items: const [],
                      //         // onChanged: (_) {},
                      //       ),
                      //     ),
                      //   ],
                      // ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // // ===== DESCRIPTION =====
                // Container(
                //   padding: const EdgeInsets.all(24),
                //   decoration: BoxDecoration(
                //     color: const Color(0xFFF5F6F8),
                //     borderRadius: BorderRadius.circular(12),
                //     boxShadow: [
                //       BoxShadow(
                //         color: Colors.black.withOpacity(0.05),
                //         blurRadius: 10,
                //         offset: const Offset(0, 4),
                //       )
                //     ],
                //   ),
                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Row(
                //         children: [
                //           const Icon(Icons.description_outlined, size: 22),
                //           const SizedBox(width: 12),
                //           Text(
                //             langProvider.get('Description', 'Deskripsi'),
                //             style: const TextStyle(
                //               fontSize: 20,
                //               fontWeight: FontWeight.w600,
                //             ),
                //           ),
                //         ],
                //       ),
                //       const SizedBox(height: 24),
                //       TextField(
                //         maxLines: 5,
                //         decoration: InputDecoration(
                //           hintText: langProvider.get(
                //               'Enter item description...',
                //               'Masukkan deskripsi item...'),
                //           filled: true,
                //           fillColor: Colors.white,
                //           border: OutlineInputBorder(
                //             borderRadius: BorderRadius.circular(8),
                //           ),
                //           contentPadding: const EdgeInsets.all(16),
                //         ),
                //       ),
                //     ],
                //   ),
                // ),

                // const SizedBox(height: 20),

                // // ===== STATUS =====
                // Container(
                //   padding: const EdgeInsets.all(24),
                //   decoration: BoxDecoration(
                //     color: const Color(0xFFF5F6F8),
                //     borderRadius: BorderRadius.circular(12),
                //     boxShadow: [
                //       BoxShadow(
                //         color: Colors.black.withOpacity(0.05),
                //         blurRadius: 10,
                //         offset: const Offset(0, 4),
                //       )
                //     ],
                //   ),
                //   child: Row(
                //     children: [
                //       const Icon(Icons.settings_outlined, size: 22),
                //       const SizedBox(width: 12),
                //       Text(
                //         langProvider.get('Status', 'Status'),
                //         style: const TextStyle(
                //           fontSize: 20,
                //           fontWeight: FontWeight.w600,
                //         ),
                //       ),
                //       const Spacer(),
                //       Text(
                //         langProvider.get('Active', 'Aktif') + ":",
                //         style: const TextStyle(fontSize: 16),
                //       ),
                //       const SizedBox(width: 20),
                //       Switch(
                //         value: true,
                //         activeColor: Colors.green,
                //         onChanged: (_) {},
                //       ),
                //     ],
                //   ),
                // ),

                ValueListenableBuilder<List<StockModel>>(
                  valueListenable: stockArrNotifier,
                  builder: (context, items, child) {
                    if (items.isEmpty) {
                      return const SizedBox(); // belum ada data
                    }

                    return Column(
                      children: [
                        const SizedBox(height: 30),
                        const Divider(),
                        SizedBox(
                          height: 200,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 700),
                              child: DataTable(
                                columnSpacing: 20,
                                columns: const [
                                  DataColumn(label: Text("No.")),
                                  DataColumn(label: Text("Stock Name")),
                                  DataColumn(label: Text("Stock Unit")),
                                  DataColumn(label: Text("Stock Qty")),
                                  // DataColumn(label: Text("Status")),
                                  DataColumn(label: Text("Action")),
                                ],
                                rows: items.asMap().entries.map((entry) {
                                  final item = entry.value;

                                  return DataRow(
                                    cells: [
                                      DataCell(Text("${entry.key + 1}")),
                                      DataCell(Text(item.stockName)),
                                      DataCell(Text(item.stockQty.toString())),
                                      DataCell(Text(item.stockPack)),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () {
                                            deleteItem(entry.key);
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 20),

                // ===== BUTTONS =====
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                        backgroundColor: Colors.grey[200],
                        side: BorderSide.none,
                      ),
                      onPressed: () {},
                      child: Text(
                        langProvider.get('Cancel', 'Batal'),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue,
                              width: 1.5,
                            ),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                            ),
                            onPressed: addItem,
                            child: Row(
                              children: [
                                const Icon(Icons.add,
                                    size: 18, color: Colors.blue),
                                Text(
                                  langProvider.get('Add More', 'Tambah'),
                                  style: const TextStyle(
                                      fontSize: 16, color: Colors.blue),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2E6BC5), Color(0xFF1E4FA3)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              //     horizontal: 50, vertical: 18),
                            ),
                            onPressed: saveStockToBackend,
                            child: Text(
                              langProvider.get('Save Item', 'Simpan Item'),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== STOCK CARD =====
Widget _stockCard({
  required String name,
  required int qty,
  bool isTherapy = false,
}) {
  Color badgeColor;

  if (isTherapy) {
    // jasa terapi: stok tidak dibatasi
    badgeColor = Colors.teal;
  } else if (qty == 0) {
    badgeColor = Colors.red;
  } else if (qty <= 20) {
    badgeColor = Colors.orange;
  } else {
    badgeColor = Colors.green;
  }

  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.only(bottom: 20),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  isTherapy ? "Jasa (tanpa batas)" : "$qty pcs",
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              isTherapy ? "JASA" : "$qty pcs",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          )
        ],
      ),
    ),
  );
}
// }

// ===== FILTER BUTTON =====
Widget _filterButton(String title, bool selected) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                colors: [Color(0xFF2E6BC5), Color(0xFF1E4FA3)])
            : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}
