import 'package:flutter/material.dart';
import '../utils/toast.dart' as app_toast;
import 'package:gold_gym_fe_android/models/item_model.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../config/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/empty_state.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/private_route.dart';
import '../widgets/search_field.dart';
import '../widgets/section_card.dart';
import '../services/items_api.dart';
import '../services/outlet_api.dart';
import '../models/outlet_model.dart';
import '../utils/debouncer.dart';
import '../utils/responsive.dart';
import '../providers/language_provider.dart';
import '../utils/storage.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';

class AddItemsScreen extends StatefulWidget {
  const AddItemsScreen({super.key});

  @override
  State<AddItemsScreen> createState() => _AddItemsScreenState();
}

class _AddItemsScreenState extends State<AddItemsScreen> {
  final _searchDebouncer = Debouncer(milliseconds: 400);
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

  String _selectedCurrency = "IDR";

  // Scope outlet saat Add Items: satu outlet spesifik (milik penjual sendiri)
  // atau "Semua Outlet" (item yang sama dibuat di semua outlet miliknya).
  static const String allOutletsSentinel = '__ALL__';
  final _outletsApi = OutletsApi();
  List<OutletResponse> _myOutlets = [];
  String? _selectedOutcode;

  /// Foto item (opsional, maks 2MB) -- hanya didukung untuk 1 item ke 1 outlet
  /// spesifik (bukan "Semua Outlet", bukan lewat buffer "Add More"), karena
  /// hanya kasus itu yang punya satu item_id pasti untuk ditempeli foto
  /// sesudah item dibuat. Lihat _canPickItemPhoto.
  File? _pickedItemPhoto;
  static const int _maxItemPhotoBytes = 2 * 1024 * 1024;
  Map<String, String> _photoHeaders = {};

  ValueNotifier<bool> isActiveItems = ValueNotifier(
      true); // agar text field terganti ketika pilih active atau nonactive
  ValueNotifier<ItemPagination?> itemsPaginationNotifier = ValueNotifier(null);
  ValueNotifier<int> editingIndexNotifier = ValueNotifier(-1);

  final ValueNotifier<String> statusEditNotifier = ValueNotifier("ACTIVE");

  Future<void> saveItemsToBackend() async {
    List<Item> arrayOneItem = [];
    Map<String, dynamic> bodyData;

    if (itemsArrNotifier.value.isEmpty) {
      final email = await Storage.get('userEmail') ?? '';
      final outcode = await _resolveOutcodeForSubmit();
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
            .toList(),
        "apply_all_outlets": _applyAllOutlets,
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
            .toList(),
        "apply_all_outlets": _applyAllOutlets,
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
          final pickedPhoto = _pickedItemPhoto;
          arrayOneItem = [];
          itemsArrNotifier.value = [];
          _itemNameController.clear();
          _itemTypeController.clear();
          _itemPackController.clear();
          _itemPriceController.clear();
          _itemBrandController.clear();
          _itemDescriptionController.clear();
          _resetBrandDefault();
          setState(() => _pickedItemPhoto = null);
          app_toast.Toast.success(context, "Item successfully saved");
          // foto opsional: cuma bisa ditempel kalau backend balikin item_id
          // pasti (1 item, 1 outlet spesifik -- lihat _canPickItemPhoto)
          if (pickedPhoto != null) {
            await _uploadPickedPhoto(itemsApi, response.body, pickedPhoto);
          }
          await getAllItems("", pages, lengths);
        } else {
          itemsArrNotifier.value = [];
          app_toast.Toast.error(context, "Failed to save item");
        }
      } else {
        app_toast.Toast.error(context, "Please fill out all required fields");
      }
    } catch (e) {
      app_toast.Toast.error(context, "Failed to save item");
    }
  }

  Future<void> updateItemRow(ItemResponse item) async {
    final outcode = await Storage.get(AppConstants.outcode) ?? "";
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
        "item_description": _itemDescriptionController.text,
        "item_status": statusEditNotifier.value,
        "item_outcode": outcode,
        "item_id": item.item_id,
      }
    };

    try {
      final itemsApi = ItemsApi();
      final response = await itemsApi.updateItems(body);

      if (response.statusCode == 200) {
        app_toast.Toast.success(context, "Item updated successfully");
      } else {
        app_toast.Toast.error(context, "Failed to update item");
      }
    } catch (e) {
      app_toast.Toast.error(context, "Error updating item");
    }
  }

  Future<void> getAllItems(String name, int page, int length) async {
    try {
      final outcode = await Storage.get(AppConstants.outcode) ?? "";
      final itemsApi = ItemsApi();
      final response = await itemsApi.getAllItems(name, outcode, page, length);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        pages = page;
        lengths = length;

        final pagination = ItemPagination.fromJson(data);
        itemsPaginationNotifier.value = pagination;
      } else {
        app_toast.Toast.error(context, "Failed to fetch items");
      }
    } catch (e) {
      app_toast.Toast.error(context, "Error fetching itemss");
    }
  }

  Future<void> addItem() async {
    final email = await Storage.get('userEmail') ?? '';
    final outcode = await _resolveOutcodeForSubmit();

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
    _resetBrandDefault();
  }

  void deleteItem(int index) {
    final updatedList = List<Item>.from(itemsArrNotifier.value);
    updatedList.removeAt(index);

    itemsArrNotifier.value = updatedList;
  }

  void deleteItemList(int index, ItemResponse item) async {
    final pagination = itemsPaginationNotifier.value;
    final outcode = await Storage.get(AppConstants.outcode) ?? "";

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
        app_toast.Toast.success(context, "Item deleted successfully");
      } else {
        app_toast.Toast.error(context, "Failed to delete item");
      }
    } catch (e) {
      app_toast.Toast.error(context, "Error updating item");
    }
  }

  String formatCurrency(String value) {
    if (value.isEmpty) return "";

    final number = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    if (_selectedCurrency == "IDR") {
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: '',
        decimalDigits: 0,
      );
      return formatter.format(number);
    } else {
      final formatter = NumberFormat.currency(
        locale: 'en_US',
        symbol: '',
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
      backgroundColor: isError ? AppColors.error : AppColors.successDark,
      textColor: Colors.white,
      fontSize: 14,
    );
  }

  bool _isTherapyOutlet = false;

  @override
  void initState() {
    super.initState();

    loadItemsOnStart();
    _loadOutletType();
    _loadMyOutlets();
    ItemsApi().getAuthHeaders().then((headers) {
      if (mounted) setState(() => _photoHeaders = headers);
    });
  }

  /// Daftar outlet MILIK PENJUAL SENDIRI SAJA (endpoint getalloutlet sudah
  /// terfilter per gold_id pemanggil) -- untuk dropdown scope outlet Add Items.
  Future<void> _loadMyOutlets() async {
    try {
      final resp = await _outletsApi.getAllOutlet('', 'ACTIVE', 1, 100);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final pagination = OutletPagination.fromJson(data);
        final activeOutcode = await Storage.get(AppConstants.outcode) ?? '';
        if (!mounted) return;
        setState(() {
          _myOutlets = pagination.data;
          _selectedOutcode = activeOutcode.isNotEmpty
              ? activeOutcode
              : (_myOutlets.isNotEmpty ? _myOutlets.first.outlet_code : null);
        });
      }
    } catch (e) {
      // gagal muat daftar outlet -- dropdown tetap kosong, fallback ke outlet
      // aktif dari Storage tetap berjalan di saveItemsToBackend/addItem.
    }
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _itemNameController.dispose();
    _itemSearchListController.dispose();
    _itemTypeController.dispose();
    _itemPackController.dispose();
    _itemPriceController.dispose();
    _itemBrandController.dispose();
    _itemDescriptionController.dispose();
    super.dispose();
  }

  /// Outlet THERAPY: kolom merek otomatis terisi "THERAPY" (masih bisa diubah).
  /// Item brand THERAPY langsung terdaftar di menu sales tanpa Add Stock.
  Future<void> _loadOutletType() async {
    final outletType =
        await Storage.get(AppConstants.outletTypeKey) ?? 'RETAIL';
    if (!mounted) return;
    setState(() {
      _isTherapyOutlet = outletType == AppConstants.outletTherapy;
      if (_isTherapyOutlet && _itemBrandController.text.isEmpty) {
        _itemBrandController.text = 'THERAPY';
      }
    });
  }

  bool get _applyAllOutlets => _selectedOutcode == allOutletsSentinel;

  /// Outcode yang dikirim per item -- kalau "Semua Outlet" dipilih, nilainya
  /// cuma placeholder (backend meng-override per outlet secara otomatis).
  Future<String> _resolveOutcodeForSubmit() async {
    if (_applyAllOutlets) {
      return await Storage.get(AppConstants.outcode) ?? '';
    }
    return _selectedOutcode ?? (await Storage.get(AppConstants.outcode) ?? '');
  }

  void _resetBrandDefault() {
    if (_isTherapyOutlet && _itemBrandController.text.isEmpty) {
      _itemBrandController.text = 'THERAPY';
    }
  }

  /// Foto item cuma bisa ditempel kalau simpan menghasilkan SATU item_id
  /// pasti: bukan mode "Semua Outlet" (fan-out ke banyak outlet/item), dan
  /// bukan hasil buffer "Add More" (banyak item sekaligus).
  bool get _canPickItemPhoto =>
      !_applyAllOutlets && itemsArrNotifier.value.isEmpty;

  /// Pilih foto item (kamera/galeri), validasi maks 2MB -- pola sama dengan
  /// pemilihan foto bukti pembayaran di buyer_shop_screen.dart.
  Future<void> _pickItemPhoto() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Foto Item'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ImageSource.camera),
            child: const Row(children: [
              Icon(Icons.photo_camera_outlined),
              SizedBox(width: 12),
              Text('Ambil dari Kamera'),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ImageSource.gallery),
            child: const Row(children: [
              Icon(Icons.photo_library_outlined),
              SizedBox(width: 12),
              Text('Pilih dari Galeri'),
            ]),
          ),
        ],
      ),
    );
    if (source == null) return;

    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    final file = File(picked.path);
    final size = await file.length();
    if (size > _maxItemPhotoBytes) {
      showToast('Ukuran foto maksimal 2 MB', isError: true);
      return;
    }
    setState(() => _pickedItemPhoto = file);
  }

  /// Upload foto yang sudah dipilih ke item yang baru dibuat. Item TETAP
  /// tersimpan walau upload foto gagal -- ini bukan langkah blocking.
  Future<void> _uploadPickedPhoto(
      ItemsApi itemsApi, String insertResponseBody, File photo) async {
    try {
      final data = jsonDecode(insertResponseBody);
      final itemId = data['data']?['item_id'];
      if (itemId == null || itemId == 0) return;
      final photoResponse = await itemsApi.uploadItemPhoto(itemId, photo);
      if (photoResponse.statusCode == 200 || photoResponse.statusCode == 201) {
        showToast('Foto item tersimpan');
      } else {
        showToast('Item tersimpan, tapi upload foto gagal', isError: true);
      }
    } catch (e) {
      showToast('Item tersimpan, tapi upload foto gagal', isError: true);
    }
  }

  Future<void> loadItemsOnStart() async {
    if (itemsPaginationNotifier.value == null ||
        itemsPaginationNotifier.value!.data.isEmpty) {
      await getAllItems("", 1, 5);
    }
  }

  // ---- edit inline di daftar barang ----
  void _startEdit(int index, ItemResponse item) {
    editingIndexNotifier.value = index;

    _itemNameController.text = item.item_name;
    _itemTypeController.text = item.item_type;
    _itemPackController.text = item.item_pack;
    _itemPriceController.text = item.item_price.toString();
    _itemBrandController.text = item.item_brand;
    _itemDescriptionController.text = item.item_description;

    statusEditNotifier.value =
        item.item_status.isEmpty ? "ACTIVE" : item.item_status;
  }

  void _clearEditControllers() {
    _itemNameController.clear();
    _itemTypeController.clear();
    _itemPackController.clear();
    _itemPriceController.clear();
    _itemBrandController.clear();
    _itemDescriptionController.clear();
  }

  Future<void> _saveEdit(ItemResponse item) async {
    await updateItemRow(item);
    editingIndexNotifier.value = -1;
    await getAllItems(_itemSearchListController.text, pages, lengths);
    _clearEditControllers();
  }

  void _cancelEdit() {
    editingIndexNotifier.value = -1;
    _clearEditControllers();
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
                title: langProvider.get('Items Menu', 'Menu Barang'),
                bottom: TabBar(
                  tabs: [
                    Tab(text: langProvider.get('Add Items', 'Tambah Barang')),
                    Tab(text: langProvider.get('Items List', 'Daftar Barang')),
                  ],
                ),
              ),
              drawer: const AppDrawer(),
              body: TabBarView(
                children: [
                  _buildItemDataTab(langProvider),
                  _buildItemListTab(langProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemListTab(LanguageProvider langProvider) {
    return PageBody(
      maxWidth: 1100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /// SEARCH
          SearchField(
            controller: _itemSearchListController,
            hintText: langProvider.get('Search items...', 'Cari barang...'),
            onChanged: (value) {
              _searchDebouncer.run(() {
                getAllItems(value, 1, lengths == 0 ? 5 : lengths);
              });
            },
          ),

          const SizedBox(height: 16),

          /// LIST
          ValueListenableBuilder<ItemPagination?>(
            valueListenable: itemsPaginationNotifier,
            builder: (context, pagination, child) {
              if (pagination == null || pagination.data.isEmpty) {
                return EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title:
                      langProvider.get('No data available', 'Tidak ada data'),
                  description: langProvider.get(
                      'Items you add will appear here.',
                      'Barang yang Anda tambahkan akan tampil di sini.'),
                );
              }

              final items = pagination.data;

              // listen editing index tanpa refresh seluruh halaman
              return ValueListenableBuilder<int>(
                valueListenable: editingIndexNotifier,
                builder: (context, editingIndex, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ItemTile(
                            item: items[i],
                            isEditing: editingIndex == i,
                            photoHeaders: _photoHeaders,
                            priceLabel:
                                formatCurrency(items[i].item_price.toString()),
                            nameController: _itemNameController,
                            typeController: _itemTypeController,
                            packController: _itemPackController,
                            priceController: _itemPriceController,
                            brandController: _itemBrandController,
                            descriptionController: _itemDescriptionController,
                            statusNotifier: statusEditNotifier,
                            onEdit: () => _startEdit(i, items[i]),
                            onSave: () => _saveEdit(items[i]),
                            onCancel: _cancelEdit,
                            onDelete: () => deleteItemList(i, items[i]),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 6),

          // FOOTER
          ValueListenableBuilder<ItemPagination?>(
            valueListenable: itemsPaginationNotifier,
            builder: (context, pagination, child) {
              if (pagination == null) {
                return const SizedBox();
              }
              return PaginationBar(
                page: pagination.page,
                totalPage: pagination.totalPage,
                limit: pagination.limit,
                totalData: pagination.totalData,
                shownCount: pagination.data.length,
                onPageChanged: (p) => getAllItems(
                    _itemSearchListController.text, p, pagination.limit),
                onLimitChanged: (l) =>
                    getAllItems(_itemSearchListController.text, 1, l),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemDataTab(LanguageProvider langProvider) {
    final textTheme = Theme.of(context).textTheme;
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
                // Item Name
                _FieldRow(
                  label: langProvider.get('Item Name', 'Nama Item'),
                  child: TextField(
                    controller: _itemNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText:
                          langProvider.get('Enter name', 'Isi nama (item)'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Outlet (scope: satu outlet spesifik atau Semua Outlet)
                _FieldRow(
                  label: langProvider.get('Outlet', 'Outlet'),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('outlet-${_selectedOutcode ?? ''}'),
                    initialValue: _selectedOutcode,
                    isExpanded: true,
                    items: [
                      ..._myOutlets.map((o) => DropdownMenuItem(
                            value: o.outlet_code,
                            child: Text(
                              o.outlet_name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                      DropdownMenuItem(
                        value: allOutletsSentinel,
                        child: Text(
                            langProvider.get('All Outlets', 'Semua Outlet')),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedOutcode = v),
                  ),
                ),
                const SizedBox(height: 16),

                // Item Pack
                _FieldRow(
                  label: langProvider.get('Item Unit', 'Satuan Item'),
                  child: TextField(
                    controller: _itemPackController,
                    decoration: InputDecoration(
                      hintText: langProvider.get('Enter unit', 'Isi satuan'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Item Price
                _FieldRow(
                  label: langProvider.get('Item Price', 'Harga Item'),
                  child: TextField(
                    controller: _itemPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCurrency,
                            isDense: true,
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
                                    formatCurrency(_itemPriceController.text);
                              });
                            },
                          ),
                        ),
                      ),
                      hintText: langProvider.get('Enter price', 'Isi harga'),
                    ),
                    onChanged: (value) {
                      final formatted = formatCurrency(value);

                      _itemPriceController.value = TextEditingValue(
                        text: formatted,
                        selection:
                            TextSelection.collapsed(offset: formatted.length),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Item Brand
                _FieldRow(
                  label: langProvider.get('Item Brand', 'Merek Item'),
                  child: TextField(
                    controller: _itemBrandController,
                    decoration: InputDecoration(
                      hintText: langProvider.get('Enter brand', 'Isi merek'),
                      helperText: _isTherapyOutlet
                          ? langProvider.get(
                              'Brand THERAPY goes straight to the sales menu; other brands need Add Stock first',
                              'Merek THERAPY langsung masuk menu sales; merek lain wajib Add Stock dulu')
                          : null,
                      helperMaxLines: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ===== FOTO ITEM (opsional) =====
          SectionCard(
            title: langProvider.get(
                'Item Photo (optional)', 'Foto Item (opsional)'),
            icon: Icons.image_outlined,
            child: !_canPickItemPhoto
                ? Text(
                    langProvider.get(
                        'Photo can only be added when saving one item to one specific outlet (not "All Outlets" / not after "Add More").',
                        'Foto hanya bisa ditambahkan saat menyimpan satu item ke satu outlet tertentu (bukan mode "Semua Outlet" / setelah "Tambah").'),
                    style: textTheme.bodySmall,
                  )
                : Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InkWell(
                        onTap: _pickItemPhoto,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: _pickedItemPhoto != null
                              ? ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  child: Image.file(_pickedItemPhoto!,
                                      fit: BoxFit.cover),
                                )
                              : const Icon(Icons.add_a_photo_outlined,
                                  color: AppColors.muted),
                        ),
                      ),
                      if (_pickedItemPhoto != null)
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _pickedItemPhoto = null),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: Text(
                              langProvider.get('Remove photo', 'Hapus foto')),
                        )
                      else
                        Text(
                          langProvider.get(
                              'Tap the box to pick a photo. Max 2 MB',
                              'Ketuk kotak untuk pilih foto. Maks 2 MB'),
                          style: textTheme.bodySmall,
                        ),
                    ],
                  ),
          ),

          const SizedBox(height: 16),

          // ===== DESCRIPTION =====
          SectionCard(
            title: langProvider.get('Description', 'Deskripsi'),
            icon: Icons.description_outlined,
            child: TextField(
              maxLines: 5,
              minLines: 3,
              controller: _itemDescriptionController,
              decoration: InputDecoration(
                hintText: langProvider.get(
                    'Enter item description...', 'Masukkan deskripsi item...'),
                alignLabelWithHint: true,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ===== STATUS =====
          ValueListenableBuilder<bool>(
            valueListenable: isActiveItems,
            builder: (context, value, child) {
              return Card(
                child: SwitchListTile(
                  value: value,
                  onChanged: (v) => isActiveItems.value = v,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  secondary: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.blueLight,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.toggle_on_outlined,
                        size: 20, color: AppColors.blue),
                  ),
                  title: Text(langProvider.get('Status', 'Status'),
                      style: textTheme.titleMedium),
                  subtitle: Text(
                    langProvider.get(
                      !value ? 'Non Active' : 'Active',
                      !value ? 'Tidak Aktif' : 'Aktif',
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      color: value ? AppColors.successDark : AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),

          ValueListenableBuilder<List<Item>>(
            valueListenable: itemsArrNotifier,
            builder: (context, items, child) {
              if (items.isEmpty) {
                return const SizedBox(); // belum ada data
              }

              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SectionCard(
                  title: langProvider.get(
                      'Items to be saved', 'Barang yang akan disimpan'),
                  description: '${items.length} item',
                  icon: Icons.playlist_add_check_rounded,
                  dense: true,
                  child: HorizontalScrollTable(
                    child: DataTable(
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
                            DataCell(Text(item.item_price.toString())),
                            DataCell(Text(item.item_brand)),
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(
                                item.item_description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                            DataCell(Text(
                              item.item_status ? "ACTIVE" : "NON ACTIVE",
                            )),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: AppColors.error),
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
                onPressed: saveItemsToBackend,
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
/// berada di kiri (lebar tetap 140) -- tidak pernah meluap.
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
        SizedBox(width: 140, child: labelText),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }
}

/// Kartu satu barang di daftar: tampilan ringkas + mode edit inline
/// (menggantikan DataTable 9 kolom yang tidak muat di HP).
class _ItemTile extends StatelessWidget {
  final ItemResponse item;
  final bool isEditing;
  final Map<String, String> photoHeaders;
  final String priceLabel;
  final TextEditingController nameController;
  final TextEditingController typeController;
  final TextEditingController packController;
  final TextEditingController priceController;
  final TextEditingController brandController;
  final TextEditingController descriptionController;
  final ValueNotifier<String> statusNotifier;
  final VoidCallback onEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _ItemTile({
    required this.item,
    required this.isEditing,
    required this.photoHeaders,
    required this.priceLabel,
    required this.nameController,
    required this.typeController,
    required this.packController,
    required this.priceController,
    required this.brandController,
    required this.descriptionController,
    required this.statusNotifier,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final active = item.item_status == 'ACTIVE';
    final status = item.item_status.isEmpty ? '-' : item.item_status;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isEditing ? AppColors.blue : AppColors.border,
          width: isEditing ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(item: item, headers: photoHeaders),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.item_name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rp $priceLabel',
                      style:
                          textTheme.titleSmall?.copyWith(color: AppColors.blue),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isEditing)
                _Pill(
                  label: status,
                  background:
                      active ? AppColors.successLight : AppColors.chipBg,
                  foreground: active ? AppColors.successDark : AppColors.muted,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (isEditing) ...[
            _TwoColumn(children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama'),
              ),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(labelText: 'Tipe'),
              ),
              TextField(
                controller: packController,
                decoration: const InputDecoration(labelText: 'Satuan'),
              ),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga'),
              ),
              TextField(
                controller: brandController,
                decoration: const InputDecoration(labelText: 'Merek'),
              ),
              ValueListenableBuilder<String>(
                valueListenable: statusNotifier,
                builder: (context, value, _) {
                  final current = value == 'ACTIVE' || value == 'NONACTIVE'
                      ? value
                      : 'ACTIVE';
                  return DropdownButtonFormField<String>(
                    key: ValueKey(current),
                    initialValue: current,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: "ACTIVE", child: Text("ACTIVE")),
                      DropdownMenuItem(
                          value: "NONACTIVE", child: Text("NONACTIVE")),
                    ],
                    onChanged: (val) {
                      if (val != null) statusNotifier.value = val;
                    },
                  );
                },
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Deskripsi',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successDark),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Simpan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Batal'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (item.item_type.isNotEmpty)
                  _Pill(icon: Icons.category_outlined, label: item.item_type),
                if (item.item_pack.isNotEmpty)
                  _Pill(icon: Icons.straighten_rounded, label: item.item_pack),
                if (item.item_brand.isNotEmpty)
                  _Pill(icon: Icons.sell_outlined, label: item.item_brand),
              ],
            ),
            if (item.item_description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.item_description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.5)),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Hapus'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final ItemResponse item;
  final Map<String, String> headers;

  const _Thumb({required this.item, required this.headers});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Icon(Icons.image_not_supported_outlined,
          size: 22, color: AppColors.muted),
    );
    if (item.item_photo.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Image.network(
        ItemsApi().itemPhotoUrl(item.item_id),
        headers: headers,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;

  const _Pill({
    required this.label,
    this.icon,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? AppColors.ink;
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? AppColors.chipBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.muted),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 1 kolom di HP, 2 kolom di layar lebar.
class _TwoColumn extends StatelessWidget {
  final List<Widget> children;

  const _TwoColumn({required this.children});

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: children[i]),
          const SizedBox(width: 10),
          Expanded(
            child: i + 1 < children.length
                ? children[i + 1]
                : const SizedBox.shrink(),
          ),
        ],
      ));
      if (i + 2 < children.length) rows.add(const SizedBox(height: 10));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}
