import 'package:flutter/material.dart';
import 'package:gold_gym_fe_android/models/item_model.dart';
import 'package:provider/provider.dart';
// import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:fluttertoast/fluttertoast.dart';
// import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/private_route.dart';
import '../services/items_api.dart';
// import '../models/stock_model.dart';
// import '../models/api_response_model.dart';
// import '../utils/text_formatter.dart';
// import '../utils/debouncer.dart';
import '../providers/language_provider.dart';
import '../utils/storage.dart';
import 'package:intl/intl.dart';

class AddItemsScreen extends StatefulWidget {
  const AddItemsScreen({super.key});

  @override
  State<AddItemsScreen> createState() => _AddItemsScreenState();
}

class _AddItemsScreenState extends State<AddItemsScreen> {
  // final _stockApi = StockApi();
  // final _debouncer = Debouncer(milliseconds: 400);
  // final _searchController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _itemSearchListController = TextEditingController();
  final _itemTypeController = TextEditingController(text: 'STOCK');
  final _itemPackController = TextEditingController();
  final _itemPriceController = TextEditingController();
  final _itemBrandController = TextEditingController();
  final _itemDescriptionController = TextEditingController();
  final itemsArrNotifier = ValueNotifier<List<Item>>([]);
  int lengths = 0;
  int pages = 0;
  int editingIndex = -1;

  String? _selectedItemType = "STOCK";
  String _selectedCurrency = "IDR";

  // String _selectedInputType = 'Keyboard';
  // List<StockModel> _stockList = [];
  // bool _isLoading = false;
  ValueNotifier<bool> isActiveItems = ValueNotifier(
      true); // agar text field terganti ketika pilih active atau nonactive
  // bool isActive = false;
  ValueNotifier<ItemPagination?> itemsPaginationNotifier = ValueNotifier(null);
  ValueNotifier<int> editingIndexNotifier = ValueNotifier(-1);

  final ValueNotifier<String> statusEditNotifier = ValueNotifier("ACTIVE");

  List<String> items = [
    'Protein Shake',
    'Isotonic Drink',
    'Creatine Powder',
    'Gold Gym Shirt',
  ];

  Future<void> saveItemsToBackend() async {
    List<Item> arrayOneItem = [];
    Map<String, dynamic> bodyData;

    if (itemsArrNotifier.value.isEmpty) {
      final email = await Storage.get('userEmail') ?? '';
      final outcode = await Storage.get("outcode") ?? "";
      final raw = _itemPriceController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final priceFinal = int.tryParse(raw) ?? 0;
      if (_itemTypeController.text == "") {
        _itemTypeController.text = "STOCK";
      }
      final item = Item(
        item_name: _itemNameController.text,
        item_outcode: outcode,
        item_type: _itemTypeController.text,
        item_pack: _itemPackController.text,
        item_price: priceFinal,
        item_brand: _itemBrandController.text,
        item_description: _itemDescriptionController.text,
        item_status: isActiveItems.value,
        item_email: email,
      );
      arrayOneItem = [
        ...arrayOneItem,
        item,
      ];
      bodyData = {
        "data": arrayOneItem
            .map((item) => {
                  "item_name": item.item_name,
                  "item_outcode": item.item_outcode,
                  "item_type": item.item_type,
                  "item_pack": item.item_pack,
                  "item_price": item.item_price,
                  "item_brand": item.item_brand,
                  "item_description": item.item_description,
                  "item_status": item.item_status ? "ACTIVE" : "NON ACTIVE",
                  "item_email": item.item_email,
                })
            .toList()
      };
    } else {
      bodyData = {
        "data": itemsArrNotifier.value
            .map((item) => {
                  "item_name": item.item_name,
                  "item_outcode": item.item_outcode,
                  "item_type": item.item_type,
                  "item_pack": item.item_pack,
                  "item_price": item.item_price,
                  "item_brand": item.item_brand,
                  "item_description": item.item_description,
                  "item_status": item.item_status ? "ACTIVE" : "NON ACTIVE",
                  "item_email": item.item_email,
                })
            .toList()
      };
    }

    try {
      if (itemsArrNotifier.value.isNotEmpty ||
          (_itemNameController.text != "" &&
              _itemTypeController.text != "" &&
              _itemPackController.text != "" &&
              formatCurrency(_itemPriceController.text) != "" &&
              _itemBrandController.text != "")) {
        final itemsApi = ItemsApi();
        final response = await itemsApi.insertItems(bodyData);

        if (response.statusCode == 200) {
          arrayOneItem = [];
          itemsArrNotifier.value = [];
          _itemNameController.clear();
          _itemTypeController.clear();
          _itemPackController.clear();
          _itemPriceController.clear();
          _itemBrandController.clear();
          _itemDescriptionController.clear();
          // showToast("Item successfully saved");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Item successfully saved"),
              backgroundColor: Colors.green,
            ),
          );
          // getAllItems("", 1, 5);
          await getAllItems("", pages, lengths);
          // Future.microtask(() => getAllItems("", 1, 5));
        } else {
          itemsArrNotifier.value = [];
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

  Future<void> updateItemRow(ItemResponse item) async {
    final outcode = await Storage.get("outcode") ?? "";
    final raw = _itemPriceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final priceFinal = double.tryParse(raw) ?? 0.0;
    final body = {
      "data": {
        "item_name": _itemNameController.text,
        "item_type":
            _itemTypeController.text.isEmpty ? "" : _itemTypeController.text,
        "item_pack":
            _itemPackController.text.isEmpty ? "" : _itemPackController.text,
        "item_price": _itemPriceController.text.isEmpty ? 0 : priceFinal,
        "item_brand":
            _itemBrandController.text.isEmpty ? "" : _itemBrandController.text,
        "item_description": "",
        "item_status": statusEditNotifier.value,
        "item_outcode": outcode,
        "item_id": item.item_id,
      }
    };

    try {
      final itemsApi = ItemsApi();
      print("body: $body");
      final response = await itemsApi.updateItems(body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Item updated successfully"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update item"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error updating item"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> getAllItems(String name, int page, int length) async {
    try {
      // final email = await Storage.get('userEmail') ?? "";
      final outcode = await Storage.get("outcode") ?? "";
      final itemsApi = ItemsApi();
      final response = await itemsApi.getAllItems(name, outcode, page, length);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // final List items = data["data"];

        pages = page;
        lengths = length;

        final pagination = ItemPagination.fromJson(data);
        // print("itemsGet: $items");
        // print("data: $data");
        itemsPaginationNotifier.value = pagination;
        // print("test");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to fetch items"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error fetching itemss"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> addItem() async {
    final email = await Storage.get('userEmail') ?? '';
    final outcode = await Storage.get("outcode") ?? "";

    final raw = _itemPriceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final priceFinal = int.tryParse(raw) ?? 0;
    if (_itemTypeController.text == "") {
      _itemTypeController.text = "STOCK";
    }

    final item = Item(
      item_name: _itemNameController.text,
      item_outcode: outcode,
      item_type: _itemTypeController.text,
      item_pack: _itemPackController.text,
      item_price: priceFinal,
      item_brand: _itemBrandController.text,
      item_description: _itemDescriptionController.text,
      item_status: isActiveItems.value,
      item_email: email,
    );

    itemsArrNotifier.value = [
      ...itemsArrNotifier.value,
      item,
    ];

    _itemNameController.clear();
    _itemTypeController.clear();
    _itemPackController.clear();
    _itemPriceController.clear();
    _itemBrandController.clear();
    _itemDescriptionController.clear();
  }

  void deleteItem(int index) {
    final updatedList = List<Item>.from(itemsArrNotifier.value);
    updatedList.removeAt(index);

    itemsArrNotifier.value = updatedList;
  }

  void deleteItemList(int index, ItemResponse item) async {
    final pagination = itemsPaginationNotifier.value;
    final outcode = await Storage.get("outcode") ?? "";

    try {
      final itemsApi = ItemsApi();
      final response = await itemsApi.deleteItems(item.item_id, outcode);

      if (response.statusCode == 200) {
        if (pagination == null) return;

        final updatedList = List<ItemResponse>.from(pagination.data);
        updatedList.removeAt(index);

        itemsPaginationNotifier.value = ItemPagination(
          data: updatedList,
          page: pagination.page,
          limit: pagination.limit,
          totalData: pagination.totalData,
          totalPage: pagination.totalPage,
        );
        await getAllItems("", pages, lengths);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Item deleted successfully"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to delete item"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error updating item"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String formatCurrency(String value) {
    if (value.isEmpty) return "";

    final number = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    if (_selectedCurrency == "IDR") {
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: '',
        // symbol: 'Rp ',
        decimalDigits: 0,
      );
      return formatter.format(number);
    } else {
      final formatter = NumberFormat.currency(
        locale: 'en_US',
        symbol: '',
        // symbol: '\$',
        decimalDigits: 0,
      );
      return formatter.format(number);
    }
  }

  void showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.red : Colors.green,
      textColor: Colors.white,
      fontSize: 14,
    );
  }

  @override
  void initState() {
    super.initState();

    loadItemsOnStart();
  }

  Future<void> loadItemsOnStart() async {
    if (itemsPaginationNotifier.value == null ||
        itemsPaginationNotifier.value!.data.isEmpty) {
      await getAllItems("", 1, 5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      child: Consumer<LanguageProvider>(
        builder: (context, langProvider, child) {
          return DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBarCustom(
                title: langProvider.get('Items Menu', 'Menu Barang'),
              ),
              drawer: const AppDrawer(),
              body: Column(
                children: [
                  TabBar(
                    labelColor: Theme.of(context).primaryColor,
                    tabs: [
                      Tab(text: langProvider.get('Add Items', 'Tambah Barang')),
                      Tab(
                          text:
                              langProvider.get('Items List', 'Daftar Barang')),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildItemDataTab(langProvider),
                        _buildItemListTab(langProvider),
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

  Widget _buildItemListTab(LanguageProvider langProvider) {
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
                /// SEARCH
                TextField(
                  controller: _itemSearchListController,
                  decoration: InputDecoration(
                    hintText: "Search...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// TABLE
                ValueListenableBuilder<ItemPagination?>(
                  valueListenable: itemsPaginationNotifier,
                  builder: (context, pagination, child) {
                    if (pagination == null || pagination.data.isEmpty) {
                      return Container(
                        height: 150,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "No data available",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }

                    final items = pagination.data;

                    /// 🔧 FIX: listen editing index tanpa refresh seluruh halaman
                    return ValueListenableBuilder<int>(
                      valueListenable: editingIndexNotifier,
                      builder: (context, editingIndex, _) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 20,
                              headingRowColor: MaterialStateProperty.all(
                                  Colors.grey.shade200),
                              columns: const [
                                DataColumn(label: Text("Name")),
                                DataColumn(label: Text("Type")),
                                DataColumn(label: Text("Unit")),
                                DataColumn(label: Text("Price")),
                                DataColumn(label: Text("Brand")),
                                DataColumn(label: Text("Description")),
                                DataColumn(label: Text("Status")),
                                DataColumn(label: Text("Action")),
                              ],
                              rows: items.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;

                                final isEditing = editingIndex == index;

                                return DataRow(
                                  cells: [
                                    /// NAME
                                    DataCell(
                                      isEditing
                                          ? SizedBox(
                                              width: 125,
                                              child: TextField(
                                                controller: _itemNameController,
                                              ),
                                            )
                                          : Text(item.item_name),
                                    ),

                                    /// TYPE
                                    DataCell(
                                      isEditing
                                          ? SizedBox(
                                              width: 125,
                                              child: TextField(
                                                controller: _itemTypeController,
                                              ),
                                            )
                                          : Text(item.item_type),
                                    ),

                                    /// UNIT
                                    DataCell(
                                      isEditing
                                          ? SizedBox(
                                              width: 125,
                                              child: TextField(
                                                controller: _itemPackController,
                                              ),
                                            )
                                          : Text(item.item_pack),
                                    ),

                                    /// PRICE
                                    DataCell(
                                      isEditing
                                          ? SizedBox(
                                              width: 125,
                                              child: TextField(
                                                controller:
                                                    _itemPriceController,
                                              ),
                                            )
                                          : Text(formatCurrency(
                                              item.item_price.toString())),
                                    ),

                                    /// BRAND
                                    DataCell(
                                      isEditing
                                          ? SizedBox(
                                              width: 125,
                                              child: TextField(
                                                controller:
                                                    _itemBrandController,
                                              ),
                                            )
                                          : Text(item.item_brand),
                                    ),

                                    /// Description
                                    DataCell(
                                      isEditing
                                          ? SizedBox(
                                              width: 125,
                                              child: TextField(
                                                controller:
                                                    _itemDescriptionController,
                                              ),
                                            )
                                          : Text(item.item_description),
                                    ),

                                    /// STATUS
                                    DataCell(
                                      isEditing
                                          ? ValueListenableBuilder<String>(
                                              valueListenable:
                                                  statusEditNotifier,
                                              builder: (context, value, _) {
                                                return DropdownButton<String>(
                                                  value: value,
                                                  items: const [
                                                    DropdownMenuItem(
                                                      value: "ACTIVE",
                                                      child: Text("ACTIVE"),
                                                    ),
                                                    DropdownMenuItem(
                                                      value: "NONACTIVE",
                                                      child: Text("NONACTIVE"),
                                                    ),
                                                  ],
                                                  onChanged: (val) {
                                                    statusEditNotifier.value =
                                                        val!;
                                                  },
                                                );
                                              },
                                            )
                                          : Text(item.item_status.isEmpty
                                              ? "-"
                                              : item.item_status),
                                    ),

                                    /// ACTION
                                    DataCell(
                                      Row(
                                        children: [
                                          ElevatedButton.icon(
                                            icon: Icon(
                                              isEditing
                                                  ? Icons.save
                                                  : Icons.edit,
                                              size: 16,
                                            ),
                                            label: Text(
                                                isEditing ? "Save" : "Edit"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isEditing
                                                  ? Colors.green
                                                  : Colors.blue,
                                            ),
                                            onPressed: () async {
                                              if (!isEditing) {
                                                /// 🔧 FIX: hanya update notifier
                                                editingIndexNotifier.value =
                                                    index;

                                                _itemNameController.text =
                                                    item.item_name;
                                                _itemTypeController.text =
                                                    item.item_type;
                                                _itemPackController.text =
                                                    item.item_pack;
                                                _itemPriceController.text =
                                                    item.item_price.toString();
                                                _itemBrandController.text =
                                                    item.item_brand;
                                                _itemDescriptionController
                                                        .text =
                                                    item.item_description;

                                                statusEditNotifier.value =
                                                    item.item_status.isEmpty
                                                        ? "ACTIVE"
                                                        : item.item_status;
                                              } else {
                                                /// SAVE
                                                await updateItemRow(item);

                                                /// 🔧 FIX: keluar dari mode edit
                                                editingIndexNotifier.value = -1;

                                                await getAllItems(
                                                    "", pages, lengths);

                                                _itemNameController.clear();
                                                _itemTypeController.clear();
                                                _itemPackController.clear();
                                                _itemPriceController.clear();
                                                _itemBrandController.clear();
                                                _itemDescriptionController
                                                    .clear();
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          if (!isEditing)
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.delete,
                                                  size: 16),
                                              label: const Text("Delete"),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                              ),
                                              onPressed: () {
                                                deleteItemList(index, item);
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 10),

                // FOOTER
                ValueListenableBuilder<ItemPagination?>(
                  valueListenable: itemsPaginationNotifier,
                  builder: (context, pagination, child) {
                    if (pagination == null) {
                      return const SizedBox();
                    }

                    final start =
                        ((pagination.page - 1) * pagination.limit) + 1;
                    final end = start + pagination.data.length - 1;

                    return Column(
                      children: [
                        /// SHOWING
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Showing $start to $end of ${pagination.totalData} entries",
                              style: const TextStyle(color: Colors.grey),
                            ),

                            /// LIMIT DROPDOWN
                            DropdownButton<int>(
                              value: pagination.limit,
                              items: const [5, 10, 20, 50]
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text("$e"),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                getAllItems(
                                    _itemSearchListController.text, 1, value!);
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        /// PAGINATION
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: pagination.page > 1
                                  ? () {
                                      getAllItems(
                                        _itemSearchListController.text,
                                        pagination.page - 1,
                                        pagination.limit,
                                      );
                                    }
                                  : null,
                            ),
                            Text(
                              "${pagination.page} / ${pagination.totalPage}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: pagination.page < pagination.totalPage
                                  ? () {
                                      getAllItems(
                                        _itemSearchListController.text,
                                        pagination.page + 1,
                                        pagination.limit,
                                      );
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemDataTab(LanguageProvider langProvider) {
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
                      // Item Name
                      Row(
                        children: [
                          SizedBox(
                            width: 125,
                            child: Text(
                              langProvider.get('Item Name', 'Nama Item') + ":",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _itemNameController,
                              decoration: InputDecoration(
                                hintText: langProvider.get(
                                    'Enter name', 'Isi nama (item)'),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // // Item Type
                      // Row(
                      //   children: [
                      //     SizedBox(
                      //       width: 125,
                      //       child: Text(
                      //         langProvider.get('Item Type', 'Tipe Item') + ":",
                      //         style: const TextStyle(fontSize: 16),
                      //       ),
                      //     ),
                      //     Expanded(
                      //       child: DropdownButtonFormField<String>(
                      //         value: _selectedItemType,
                      //         items: const [
                      //           DropdownMenuItem(
                      //             value: "STOCK",
                      //             child: Text("STOCK"),
                      //           ),
                      //           DropdownMenuItem(
                      //             value: "THERAPY",
                      //             child: Text("THERAPY"),
                      //           ),
                      //         ],
                      //         onChanged: (value) {
                      //           setState(() {
                      //             _selectedItemType = value;
                      //             _itemTypeController.text = value ?? "STOCK";
                      //           });
                      //         },
                      //         decoration: InputDecoration(
                      //           filled: true,
                      //           fillColor: Colors.white,
                      //           border: OutlineInputBorder(
                      //             borderRadius: BorderRadius.circular(8),
                      //           ),
                      //           contentPadding: const EdgeInsets.symmetric(
                      //               horizontal: 16, vertical: 14),
                      //         ),
                      //         style: const TextStyle(
                      //             fontSize: 14, color: Colors.black),
                      //         hint: Text(
                      //           langProvider.get('Select type', 'Pilih tipe'),
                      //         ),
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      // const SizedBox(height: 20),

                      // Item Pack
                      Row(
                        children: [
                          SizedBox(
                            width: 125,
                            child: Text(
                              langProvider.get('Item Unit', 'Satuan Item') +
                                  ":",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _itemPackController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                hintText: langProvider.get(
                                    'Enter unit', 'Isi satuan'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Item Price
                      Row(
                        children: [
                          SizedBox(
                            width: 125,
                            child: Text(
                              langProvider.get('Item Price', 'Harga Item') +
                                  ":",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _itemPriceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,

                                /// 🔥 Gabung di sini
                                prefixIcon: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedCurrency,
                                      items: const [
                                        DropdownMenuItem(
                                          value: "IDR",
                                          child: Text("Rp"),
                                        ),
                                        DropdownMenuItem(
                                          value: "USD",
                                          child: Text("\$"),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedCurrency = value!;
                                          _itemPriceController.text =
                                              formatCurrency(
                                                  _itemPriceController.text);
                                        });
                                      },
                                    ),
                                  ),
                                ),

                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                hintText: langProvider.get(
                                    'Enter price', 'Isi harga'),
                              ),

                              /// 🔥 format tetap jalan
                              onChanged: (value) {
                                final formatted = formatCurrency(value);

                                _itemPriceController.value = TextEditingValue(
                                  text: formatted,
                                  selection: TextSelection.collapsed(
                                      offset: formatted.length),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Item Brand
                      Row(
                        children: [
                          SizedBox(
                            width: 125,
                            child: Text(
                              langProvider.get('Item Brand', 'Merek Item') +
                                  ":",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _itemBrandController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                hintText: langProvider.get(
                                    'Enter brand', 'Isi merek'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ===== DESCRIPTION =====
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
                          const Icon(Icons.description_outlined, size: 22),
                          const SizedBox(width: 12),
                          Text(
                            langProvider.get('Description', 'Deskripsi'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        maxLines: 5,
                        controller: _itemDescriptionController,
                        decoration: InputDecoration(
                          hintText: langProvider.get(
                              'Enter item description...',
                              'Masukkan deskripsi item...'),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ===== STATUS =====
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
                  child: Row(
                    children: [
                      const Icon(Icons.settings_outlined, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        langProvider.get('Status', 'Status'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      ValueListenableBuilder<bool>(
                        valueListenable: isActiveItems,
                        builder: (context, value, child) {
                          return Text(
                            "${langProvider.get(
                              !value ? 'Non Active' : 'Active',
                              !value ? 'Tidak Aktif' : 'Aktif',
                            )} :",
                            style: const TextStyle(fontSize: 16),
                          );
                        },
                      ),
                      const SizedBox(width: 20),
                      StatusSwitch(
                        initialValue: isActiveItems.value,
                        onChanged: (bool value) {
                          isActiveItems.value =
                              value; // simpan ke variable utama
                          print("Status sekarang: ${isActiveItems.value}");
                        },
                      ),
                    ],
                  ),
                ),

                ValueListenableBuilder<List<Item>>(
                  valueListenable: itemsArrNotifier,
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
                                  DataColumn(label: Text("Item Name")),
                                  DataColumn(label: Text("Item Type")),
                                  DataColumn(label: Text("Item Unit")),
                                  DataColumn(label: Text("Item Price")),
                                  DataColumn(label: Text("Item Brand")),
                                  DataColumn(label: Text("Description")),
                                  DataColumn(label: Text("Status")),
                                  DataColumn(label: Text("Action")),
                                ],
                                rows: items.asMap().entries.map((entry) {
                                  final item = entry.value;

                                  return DataRow(
                                    cells: [
                                      DataCell(Text("${entry.key + 1}")),
                                      DataCell(Text(item.item_name)),
                                      DataCell(Text(item.item_type)),
                                      DataCell(Text(item.item_pack)),
                                      DataCell(
                                          Text(item.item_price.toString())),
                                      DataCell(Text(item.item_brand)),
                                      DataCell(Text(item.item_description)),
                                      DataCell(Text(
                                        item.item_status
                                            ? "ACTIVE"
                                            : "NON ACTIVE",
                                      )),
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
                // ],
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
                            onPressed: saveItemsToBackend,
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

// ----------------------- button -----------------------
class StatusSwitch extends StatefulWidget {
  final bool initialValue;
  final Function(bool) onChanged;

  const StatusSwitch({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<StatusSwitch> createState() => _StatusSwitchState();
}

class _StatusSwitchState extends State<StatusSwitch> {
  late bool isActive;

  @override
  void initState() {
    super.initState();
    isActive = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: isActive,
      activeColor: Colors.green,
      inactiveThumbColor: Colors.grey, // ✅ ADDED
      inactiveTrackColor: Colors.grey.shade300, // ✅ ADDED
      onChanged: (bool value) {
        setState(() {
          isActive = value;
        });

        widget.onChanged(value); // kirim nilai ke parent
      },
    );
  }
}

// ----------------------- button -----------------------
