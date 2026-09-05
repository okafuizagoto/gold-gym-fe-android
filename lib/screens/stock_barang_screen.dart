import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../utils/toast.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../config/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/empty_state.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/private_route.dart';
import '../widgets/search_field.dart';
import '../widgets/section_card.dart';
import '../widgets/segmented_tabs.dart';
import '../services/stock_api.dart';
import '../models/stock_model.dart';
import '../models/api_response_model.dart';
import '../utils/debouncer.dart';
import '../utils/responsive.dart';
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
  FocusNode _autoCompleteFocusNode = FocusNode();

  final _debouncerSuggestion = Debouncer(milliseconds: 400);

  ValueNotifier<ItemPagination?> itemsPaginationNotifier = ValueNotifier(null);
  ValueNotifier<StockPagination?> stockPaginationNotifier = ValueNotifier(null);

  List<StockModel> _stockListSuggestions = [];
  List<StockResponse> _stockList = [];

  String userName = 'Guest';

  bool _isLoadingSuggestions = false;
  final bool _isLoading = false;

  int lengths = 5;
  int pages = 1;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  @override
  void dispose() {
    _stockNameController.dispose();
    _stockPackController.dispose();
    _stockItemIDController.dispose();
    _stockQtyController.dispose();
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
        Toast.error(context, "Failed to fetch items");
      }
    } catch (e) {
      debugPrint("ERROR: $e");
      Toast.error(context, "Error fetching items");
    }
  }

  Future<void> getAllStock(String name, int page, int length) async {
    try {
      final outcode = await Storage.get(AppConstants.outcode) ?? '';
      final stockApi = StockApi();

      final response = await stockApi.getAllStock(name, outcode, page, length);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final pagination = StockPagination.fromJson(data);

        stockPaginationNotifier.value = pagination;

        pages = page;
        lengths = length;

        _stockList = pagination.data;
      } else {
        Toast.error(context, "Failed to fetch items");
      }
    } catch (e) {
      debugPrint("ERROR: $e");
      Toast.error(context, "Error fetching items");
    }
  }

  // Method fetch suggestions untuk autocomplete
  // ignore: unused_element
  Future<void> _fetchStockSuggestions(String query) async {
    setState(() => _isLoadingSuggestions = true);

    try {
      final response = await _stockApi.getStockByName(query);
      if (response.statusCode == 200) {
        final apiResponse = ApiResponse<List<StockModel>>.fromJson(
          jsonDecode(response.body),
          (json) =>
              (json as List).map((item) => StockModel.fromJson(item)).toList(),
        );
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

  Future<void> saveStockToBackend() async {
    Map<String, dynamic> bodyData;
    // entri form hanya divalidasi jika nama diisi — setelah tombol TAMBAH,
    // form dikosongkan dan item sudah masuk daftar, jadi form kosong + daftar
    // terisi adalah kondisi normal (dulu tetap divalidasi ke suggestion
    // sehingga muncul error "Pilih item dari daftar suggestion")
    final hasFormEntry = _stockNameController.text.trim().isNotEmpty;

    if (!hasFormEntry && stockArrNotifier.value.isEmpty) {
      Toast.error(context, "Tolong masukkan nama stock");
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
        Toast.error(context, "Pilih item dari daftar suggestion");
        return;
      }
      if (_stockQtyController.text == "") {
        Toast.error(context, "Tolong masukkan jumlah qty");
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
        final stocksApi = StockApi();
        final response = await stocksApi.insertStock(bodyData);

        if (response.statusCode == 200) {
          stockArrNotifier.value = [];
          _stockNameController.clear();
          _stockPackController.clear();
          _stockItemIDController.clear();
          _stockQtyController.clear();

          _autoCompleteController?.clear();
          _autoCompleteFocusNode.unfocus();

          Toast.success(context, "Item successfully saved");
        } else {
          stockArrNotifier.value = [];
          Toast.error(context, "Failed to save item");
        }
      } else {
        Toast.error(context, "Please fill out all required fields");
      }
    } catch (e) {
      Toast.error(context, "Failed to save item");
    }
  }

  Future<void> addItem() async {
    final outcode = await Storage.get(AppConstants.outcode) ?? '';
    final inputName = _stockNameController.text.trim().toLowerCase();
    final allItems = itemsPaginationNotifier.value?.data ?? [];

    if (_stockNameController.text == "") {
      Toast.error(context, "Tolong masukkan nama stock");
      return;
    }

    final isValid = allItems.any(
      (item) => item.item_name.toLowerCase() == inputName,
    );

    if (!isValid) {
      Toast.error(context, "Pilih item dari daftar suggestion");
      return;
    }

    if (_stockQtyController.text == "") {
      Toast.error(context, "Tolong masukkan jumlah qty");
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
                bottom: TabBar(
                  tabs: [
                    Tab(text: langProvider.get('Stock List', 'Daftar Stok')),
                    Tab(text: langProvider.get('Add Stock', 'Tambah Stok')),
                  ],
                ),
              ),
              drawer: const AppDrawer(),
              body: TabBarView(
                children: [
                  _buildStockListTab(langProvider),
                  _buildStockDataTab(langProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStockListTab(LanguageProvider langProvider) {
    final textTheme = Theme.of(context).textTheme;
    final pad = context.pagePadding;
    return SafeArea(
      top: false,
      child: ContentWidth(
        child: Column(
          children: [
            // ===== SEARCH + FILTER =====
            Padding(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    langProvider.get('Stock Management', 'Manajemen Stok'),
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SearchField(
                          controller: _searchController,
                          hintText: langProvider.get('Search', 'Cari'),
                          onSubmitted: (v) => getAllStock(v, pages, lengths),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => getAllStock(
                              _searchController.text, pages, lengths),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: const Icon(Icons.search_rounded, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // filter tampilan (belum ada logika filter di versi ini)
                  SegmentedTabs<String>(
                    value: 'ALL',
                    onChanged: (_) {},
                    tabs: [
                      SegmentedTab(
                          value: 'ALL',
                          label: langProvider.get('All', 'Semua')),
                      SegmentedTab(
                          value: 'LOW',
                          label: langProvider.get('Low Stock', 'Stok Rendah')),
                      SegmentedTab(
                          value: 'OUT',
                          label:
                              langProvider.get('Out of Stock', 'Stok Habis')),
                    ],
                  ),
                ],
              ),
            ),

            // ===== STOCK LIST =====
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ValueListenableBuilder<StockPagination?>(
                      valueListenable: stockPaginationNotifier,
                      builder: (context, pagination, _) {
                        final items = pagination?.data ?? [];

                        if (items.isEmpty) {
                          return SingleChildScrollView(
                            child: EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: langProvider.get(
                                  'No data available', 'Tidak ada data'),
                              description: langProvider.get(
                                  'Add stock from the "Add Stock" tab.',
                                  'Tambahkan stok lewat tab "Tambah Stok".'),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: pad),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return _StockCard(
                                    name: item.stock_name,
                                    qty: item.stock_qty,
                                    isTherapy: item.isTherapy,
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(pad, 8, pad, 12),
                              child: PaginationBar(
                                page: pagination!.page,
                                totalPage: pagination.totalPage,
                                limit: pagination.limit,
                                totalData: pagination.totalData,
                                shownCount: items.length,
                                onPageChanged: (p) => getAllStock(
                                    _searchController.text,
                                    p,
                                    pagination.limit),
                                onLimitChanged: (l) =>
                                    getAllStock(_searchController.text, 1, l),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockDataTab(LanguageProvider langProvider) {
    return PageBody(
      maxWidth: 900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== BASIC INFORMATION =====
          SectionCard(
            title: langProvider.get('Basic Information', 'Informasi Dasar'),
            icon: Icons.inventory_2_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Stock Name
                _FieldRow(
                  label: langProvider.get('Stock Name', 'Nama Stock'),
                  child: ValueListenableBuilder<ItemPagination?>(
                    valueListenable: itemsPaginationNotifier,
                    builder: (context, pagination, _) {
                      return Autocomplete<ItemResponse>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final items =
                              itemsPaginationNotifier.value?.data ?? [];

                          final query = textEditingValue.text.toLowerCase();
                          if (textEditingValue.text.isEmpty) {
                            return items;
                          }
                          return items.where((item) =>
                              item.item_name.toLowerCase().startsWith(query));
                        },
                        displayStringForOption: (option) => option.item_name,
                        optionsViewBuilder: (context, onSelected, options) {
                          // lebar daftar saran tidak boleh melebihi layar
                          final maxWidth =
                              math.min(500.0, context.screenWidth - 48);
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              clipBehavior: Clip.antiAlias,
                              child: Container(
                                width: maxWidth,
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
                                                  suggestion.item_name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                        onSelected: (ItemResponse selection) {
                          addSelectedItem(selection);
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                          _autoCompleteController = controller;
                          _autoCompleteFocusNode = focusNode;
                          return TextField(
                            controller: controller,
                            focusNode: _autoCompleteFocusNode,
                            decoration: InputDecoration(
                              hintText: langProvider.get(
                                  'Enter name', 'Masukkan nama'),
                              prefixIcon:
                                  const Icon(Icons.inventory_2_outlined),
                            ),
                            onChanged: (value) {
                              addNewItem(value);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Stock Qty
                _FieldRow(
                  label: langProvider.get('Stock Qty', 'Jumlah Stock'),
                  child: TextField(
                    controller: _stockQtyController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.numbers_rounded),
                      hintText:
                          langProvider.get('Enter Qty', 'Masukkan jumlah item'),
                    ),
                    onChanged: (value) {
                      _stockQtyController.text;
                    },
                  ),
                ),
              ],
            ),
          ),

          ValueListenableBuilder<List<StockModel>>(
            valueListenable: stockArrNotifier,
            builder: (context, items, child) {
              if (items.isEmpty) {
                return const SizedBox(); // belum ada data
              }

              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SectionCard(
                  title: langProvider.get(
                      'Stock to be saved', 'Stok yang akan disimpan'),
                  description: '${items.length} item',
                  icon: Icons.playlist_add_check_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                              bottom: i == items.length - 1 ? 0 : 8),
                          child: _PendingStockTile(
                            index: i + 1,
                            item: items[i],
                            onDelete: () => deleteItem(i),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // ===== BUTTONS =====
          ResponsiveActions(
            alignment: WrapAlignment.end,
            fullWidthOnCompact: true,
            children: [
              TextButton(
                onPressed: () {},
                child: Text(langProvider.get('Cancel', 'Batal')),
              ),
              OutlinedButton.icon(
                onPressed: addItem,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(langProvider.get('Add More', 'Tambah')),
              ),
              ElevatedButton.icon(
                onPressed: saveStockToBackend,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(langProvider.get('Save Item', 'Simpan Item')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Baris label + field: di HP label di atas field, di layar lebar label
/// berada di kiri (lebar tetap 150) -- tidak pernah meluap.
class _FieldRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelText = Text(
      label,
      style: textTheme.titleSmall,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    if (context.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          labelText,
          const SizedBox(height: 6),
          child,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 150, child: labelText),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }
}

class _PendingStockTile extends StatelessWidget {
  final int index;
  final StockModel item;
  final VoidCallback onDelete;

  const _PendingStockTile({
    required this.index,
    required this.item,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.blueLight,
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.blue,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.stockName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
                Text(
                  'Qty ${item.stockQty}'
                  '${item.stockPack.isNotEmpty ? ' ${item.stockPack}' : ''}',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hapus',
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ===== STOCK CARD =====
class _StockCard extends StatelessWidget {
  final String name;
  final int qty;
  final bool isTherapy;

  const _StockCard({
    required this.name,
    required this.qty,
    this.isTherapy = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Color badgeBg;
    Color badgeFg;

    if (isTherapy) {
      // jasa terapi: stok tidak dibatasi
      badgeBg = AppColors.tealLight;
      badgeFg = AppColors.tealDark;
    } else if (qty == 0) {
      badgeBg = AppColors.errorLight;
      badgeFg = AppColors.errorDark;
    } else if (qty <= 20) {
      badgeBg = AppColors.warningLight;
      badgeFg = AppColors.warningDark;
    } else {
      badgeBg = AppColors.successLight;
      badgeFg = AppColors.successDark;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  color: AppColors.blue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isTherapy ? "Jasa (tanpa batas)" : "$qty pcs",
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                isTherapy ? "JASA" : "$qty pcs",
                style: TextStyle(
                  color: badgeFg,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
