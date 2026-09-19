import 'package:flutter/material.dart';
import 'package:gold_gym_fe_android/models/item_model.dart';
import 'package:provider/provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/private_route.dart';
import '../services/items_api.dart';
import '../models/stock_model.dart';
import '../models/api_response_model.dart';
import '../utils/text_formatter.dart';
import '../utils/debouncer.dart';
import '../providers/language_provider.dart';
import '../utils/storage.dart';

class AddItemsScreen extends StatefulWidget {
const AddItemsScreen({super.key});

@override
State<AddItemsScreen> createState() => \_AddItemsScreenState();
}

class \_AddItemsScreenState extends State<AddItemsScreen> {
// final \_stockApi = StockApi();
final \_debouncer = Debouncer(milliseconds: 400);
final \_searchController = TextEditingController();
final \_itemNameController = TextEditingController();
final \_itemTypeController = TextEditingController();
final \_itemBrandController = TextEditingController();
final \_itemDescriptionController = TextEditingController();
final itemsArrNotifier = ValueNotifier<List<Item>>([]);

String \_selectedInputType = 'Keyboard';
List<StockModel> \_stockList = [];
bool \_isLoading = false;
ValueNotifier<bool> isActiveItems = ValueNotifier(
true); // agar text field terganti ketika pilih active atau nonactive
// bool isActive = false;

List<String> items = [
'Protein Shake',
'Isotonic Drink',
'Creatine Powder',
'Gold Gym Shirt',
];

// List<Item> itemsArr = [];

// @override
// void initState() {
// super.initState();
// \_debouncer.run(\_fetchAllStock);
// }

// @override
// void dispose() {
// \_searchController.dispose();
// \_debouncer.dispose();
// super.dispose();
// }

// Future<void> \_fetchAllStock() async {
// setState(() => \_isLoading = true);

// try {
// final response = await \_stockApi.getAllStockHeader();
// if (response.statusCode == 200) {
// final apiResponse = ApiResponse<List<StockModel>>.fromJson(
// jsonDecode(response.body),
// (json) =>
// (json as List).map((item) => StockModel.fromJson(item)).toList(),
// );

// if (mounted) {
// setState(() {
// \_stockList = apiResponse.data ?? [];
// });
// }
// }
// } catch (e) {
// debugPrint('Error fetching stock: $e');
// } finally {
// if (mounted) {
// setState(() => \_isLoading = false);
// }
// }
// }

Future<void> saveItemsToBackend() async {
final url =
Uri.parse('http://localhost:8085/items/v2/items?type=insertitems');

    // mapping itemsArrNotifier ke bentuk yang backend mau
    final bodyData = {
      "data": itemsArrNotifier.value
          .map((item) => {
                "item_name": item.item_name,
                "item_type": item.item_type,
                "item_brand": item.item_brand,
                "item_description": item.item_description,
                "item_status": item.item_status ? "ACTIVE" : "NON ACTIVE",
                "item_email": item.item_email,
              })
          .toList()
    };

    try {
      final itemsApi = ItemsApi();
      final response = await itemsApi.insertItems(bodyData);
      // final response = await http.post(
      //   url,
      //   headers: {
      //     "Content-Type": "application/json",
      //   },
      //   body: jsonEncode(bodyData),
      // );

      if (response.statusCode == 200) {
        print("Berhasil kirim data ke backend");
        print(response.body);
      } else {
        print("Gagal kirim data: ${response.statusCode}");
        print(response.body);
      }
    } catch (e) {
      print("Error saat kirim data ke backend: $e");
    }

}

Future<void> addItem() async {
final email = await Storage.get('userEmail') ?? '';

    final item = Item(
      item_name: _itemNameController.text,
      item_type: _itemTypeController.text,
      item_brand: _itemBrandController.text,
      item_description: _itemDescriptionController.text,
      item_status: isActiveItems.value,
      item_email: email,
    );

    // setState(() {
    //   itemsArrNotifier.add(item);
    // });
    itemsArrNotifier.value = [
      ...itemsArrNotifier.value,
      item,
    ];

    _itemNameController.clear();
    _itemTypeController.clear();
    _itemBrandController.clear();
    _itemDescriptionController.clear();
    isActiveItems.value = false;

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

Widget \_buildItemListTab(LanguageProvider langProvider) {
return Column(
children: [
// Search form
Container(
padding: const EdgeInsets.all(16),
child: Column(
children: [
Row(
children: [
// Expanded(
// flex: 1,
// child: DropdownButtonFormField<String>(
// value: \_selectedInputType,
// decoration: InputDecoration(
// labelText: langProvider.get('Input Type', 'Tipe Input'),
// border: const OutlineInputBorder(),
// ),
// items: ['Keyboard', 'Barcode'].map((type) {
// return DropdownMenuItem(
// value: type,
// child: Text(type),
// );
// }).toList(),
// onChanged: (value) {
// setState(() => \_selectedInputType = value ?? 'Keyboard');
// },
// ),
// ),
Expanded(
flex: 5,
child: TypeAheadField<String>(
suggestionsCallback: (search) {
return items
.where((item) => item
.toLowerCase()
.contains(search.toLowerCase()))
.toList();
},
builder: (context, controller, focusNode) {
return TextField(
controller: controller,
focusNode: focusNode,
decoration: const InputDecoration(
labelText: 'Search Item',
border: OutlineInputBorder(),
),
);
},
itemBuilder: (context, suggestion) {
return ListTile(
title: Text(suggestion),
);
},
onSelected: (suggestion) {
print("Selected: $suggestion");
},
),
),
const SizedBox(width: 15),
// Expanded(

                  // ),
                ],
              ),
              // const SizedBox(height: 16),
              // Row(
              //   children: [
              //     const SizedBox(width: 16),
              //     IconButton(
              //       onPressed: () {
              //         // TODO: Add new stock
              //       },
              //       icon: const Icon(Icons.add_circle, size: 40),
              //       color: Colors.green,
              //     ),
              //   ],
              // ),
            ],
          ),
        ),

        // Table
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : itemsArrNotifier.value.isEmpty
                  ? Center(
                      child: Text(
                        langProvider.get('No data available', 'Tidak ada data'),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 20,
                          columns: [
                            DataColumn(
                              label: Text(langProvider.get('NO', 'NO')),
                            ),
                            DataColumn(
                              label: Text(
                                  langProvider.get('Stock Code', 'Kode Stok')),
                            ),
                            DataColumn(
                              label: Text(
                                  langProvider.get('Stock Name', 'Nama Stok')),
                            ),
                            DataColumn(
                              label: Text(langProvider.get('Pack', 'Kemasan')),
                            ),
                            DataColumn(
                              label: Text(langProvider.get('Qty', 'Jumlah')),
                            ),
                            DataColumn(
                              label: Text(langProvider.get('Price', 'Harga')),
                            ),
                            DataColumn(
                              label: Text(langProvider.get(
                                  'Qty Update', 'Update Jumlah')),
                            ),
                            DataColumn(
                              label: Text(langProvider.get(
                                  'Last Update', 'Update Terakhir')),
                            ),
                            DataColumn(
                              label: Text(langProvider.get(
                                  'Updated By', 'Diupdate Oleh')),
                            ),
                            DataColumn(
                              label: Text(langProvider.get('ACTION', 'AKSI')),
                            ),
                          ],
                          rows: _stockList
                              .asMap()
                              .entries
                              .map(
                                (entry) => DataRow(
                                  cells: [
                                    DataCell(Text('${entry.key + 1}')),
                                    DataCell(Text(entry.value.stockCode)),
                                    DataCell(Text(entry.value.stockName)),
                                    DataCell(Text(entry.value.stockPack)),
                                    DataCell(Text('${entry.value.stockQty}')),
                                    DataCell(
                                      Text(TextFormatter.formatRupiah(
                                          entry.value.stockPrice)),
                                    ),
                                    DataCell(
                                      Text(
                                        entry.value.stockQtyUpdate != null
                                            ? TextFormatter.formatDateFull(
                                                entry.value.stockQtyUpdate!)
                                            : '-',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        entry.value.stockLastUpdate != null
                                            ? TextFormatter.formatDateFull(
                                                entry.value.stockLastUpdate!)
                                            : '-',
                                      ),
                                    ),
                                    DataCell(
                                        Text(entry.value.stockUpdateBy ?? '-')),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.download,
                                                size: 20),
                                            onPressed: () {
                                              // TODO: Download action
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                size: 20),
                                            color: Colors.red,
                                            onPressed: () {
                                              // TODO: Delete action
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
        ),
      ],
    );

}

Widget \_buildItemDataTab(LanguageProvider langProvider) {
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

                      // // Item Code
                      // Row(
                      //   children: [
                      //     SizedBox(
                      //       width: 150,
                      //       child: Text(
                      //         langProvider.get('Item Code', 'Kode Item') + ":",
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

                      // Item Name
                      Row(
                        children: [
                          SizedBox(
                            width: 150,
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
                                    'Enter name', 'Masukkan nama'),
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

                      // Item Type
                      Row(
                        children: [
                          SizedBox(
                            width: 150,
                            child: Text(
                              langProvider.get('Item Type', 'Tipe Item') + ":",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Expanded(
                            // child: DropdownButtonFormField<String>(
                            child: TextField(
                              controller: _itemTypeController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                hintText: langProvider.get(
                                    'Enter type', 'Masukkan tipe'),
                              ),
                              // hint: Text(langProvider.get(
                              //     'Select Type', 'Pilih Tipe')),
                              // items: const [],
                              // onChanged: (_) {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Item Brand
                      Row(
                        children: [
                          SizedBox(
                            width: 150,
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
                                    'Enter brand', 'Masukkan merek'),
                              ),
                              // hint: Text(langProvider.get(
                              //     'Select Brand', 'Pilih Merek')),
                              // items: const [],
                              // onChanged: (_) {},
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
                      // Switch(
                      //   value: true,
                      //   activeColor: Colors.green,
                      //   onChanged: (_) {},
                      // ),
                      StatusSwitch(
                        initialValue: isActiveItems.value,
                        onChanged: (bool value) {
                          // setState(() {
                          isActiveItems.value =
                              value; // simpan ke variable utama
                          // });
                          print("Status sekarang: ${isActiveItems.value}");
                        },
                      ),
                    ],
                  ),
                ),

                // if (_stockList.isNotEmpty) ...[
                itemsArrNotifier.value.isEmpty
                    ? const SizedBox(height: 20)
                    : const SizedBox(height: 30),
                itemsArrNotifier.value.isEmpty
                    ? SizedBox.shrink()
                    : const Divider(),
                // Row(
                //   children: [
                //     Expanded(
                //       // SizedBox(
                //       //   height: 400,
                //       child: SingleChildScrollView(
                //         scrollDirection: Axis.horizontal,
                //         child: SingleChildScrollView(
                //           child: DataTable(
                //             columnSpacing: 20,
                //             columns: [
                //               DataColumn(
                //                 label: Text(langProvider.get('No.', 'No.')),
                //               ),
                //               DataColumn(
                //                 label: Text(langProvider.get(
                //                     'Item Name', 'Nama Barang')),
                //               ),
                //               DataColumn(
                //                 label: Text(langProvider.get(
                //                     'Item Type', 'Tipe Barang')),
                //               ),
                //               DataColumn(
                //                 label: Text(langProvider.get(
                //                     'Item Brand', 'Merek Barang')),
                //               ),
                //               DataColumn(
                //                 label: Text(langProvider.get(
                //                     'Description', 'Deskripsi')),
                //               ),
                //               DataColumn(
                //                 label:
                //                     Text(langProvider.get('Status', 'Status')),
                //               ),
                //             ],
                //             rows: itemsArrNotifier
                //                 .asMap()
                //                 .entries
                //                 .map(
                //                   (entry) => DataRow(
                //                     cells: [
                //                       DataCell(Text('${entry.key + 1}')),
                //                       DataCell(Text(entry.value.item_name)),
                //                       DataCell(Text(entry.value.item_type)),
                //                       DataCell(Text(entry.value.item_brand)),
                //                       DataCell(
                //                           Text(entry.value.item_description)),
                //                       DataCell(Text(
                //                           entry.value.item_status == true
                //                               ? "ACTIVE"
                //                               : "NON ACTIVE")),
                //                     ],
                //                   ),
                //                 )
                //                 .toList(),
                //           ),
                //         ),
                //       ),
                //     ),
                //   ],
                // ),
                // Scroll horizontal & vertical untuk DataTable
                SizedBox(
                  height: itemsArrNotifier.value.isEmpty
                      ? 0
                      : 200, // tinggi maksimal untuk tabel, bisa disesuaikan
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ValueListenableBuilder<List<Item>>(
                          valueListenable: itemsArrNotifier,
                          builder: (context, itemsArrNotifier, child) {
                            if (itemsArrNotifier.isEmpty) {
                              return Center(
                                  // child: Text(
                                  //   langProvider.get('No data available',
                                  //       'Tidak ada data'),
                                  // ),
                                  );
                            }
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal, // scroll kolom
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    minWidth: 700), // lebar minimum tabel
                                child: DataTable(
                                  columnSpacing: 20,
                                  columns: [
                                    DataColumn(
                                        label: Text(
                                            langProvider.get('No.', 'No.'))),
                                    DataColumn(
                                        label: Text(langProvider.get(
                                            'Item Name', 'Nama Barang'))),
                                    DataColumn(
                                        label: Text(langProvider.get(
                                            'Item Type', 'Tipe Barang'))),
                                    DataColumn(
                                        label: Text(langProvider.get(
                                            'Item Brand', 'Merek Barang'))),
                                    DataColumn(
                                        label: Text(langProvider.get(
                                            'Description', 'Deskripsi'))),
                                    DataColumn(
                                        label: Text(langProvider.get(
                                            'Status', 'Status'))),
                                  ],
                                  rows: itemsArrNotifier
                                      .asMap()
                                      .entries
                                      .map(
                                        (entry) => DataRow(
                                          cells: [
                                            DataCell(Text('${entry.key + 1}')),
                                            DataCell(
                                                Text(entry.value.item_name)),
                                            DataCell(
                                                Text(entry.value.item_type)),
                                            DataCell(
                                                Text(entry.value.item_brand)),
                                            DataCell(Text(
                                                entry.value.item_description)),
                                            DataCell(Text(
                                                entry.value.item_status
                                                    ? "ACTIVE"
                                                    : "NON ACTIVE")),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            );
                          },
                        ),
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
                        //     horizontal: 40, vertical: 18),
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
                            // gradient: const LinearGradient(
                            //   colors: [Color(0xFF2E6BC5), Color(0xFF1E4FA3)],
                            // ),
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
                              //     horizontal: 50, vertical: 18),
                            ),
                            onPressed: addItem,
                            // onPressed: () {},
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
                            onPressed: () {},
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
State<StatusSwitch> createState() => \_StatusSwitchState();
}

class \_StatusSwitchState extends State<StatusSwitch> {
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
