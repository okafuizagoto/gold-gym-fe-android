import 'package:flutter/material.dart';
import 'package:gold_gym_fe_android/services/outlet_api.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/outlet_api.dart';
import '../models/outlet_model.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../utils/constants.dart';
import '../providers/user_provider.dart';
import '../config/theme.dart';

class ListOutletScreen extends StatefulWidget {
  const ListOutletScreen({super.key});

  @override
  State<ListOutletScreen> createState() => _OutletScreenState();
}

class _OutletScreenState extends State<ListOutletScreen> {
  final _formKey = GlobalKey<FormState>();
  final outletsApi = OutletsApi();
  final outletsArrNotifier = ValueNotifier<List<Outlet>>([]);
  final _outletAddressController = TextEditingController();
  final _outletNameController = TextEditingController();
  final _outletSearchListController = TextEditingController();

  final ValueNotifier<String> statusEditNotifier = ValueNotifier("ACTIVE");

  bool _isLoading = false;
  int lengths = 0;
  int pages = 0;
  int editingIndex = -1;

  ValueNotifier<OutletPagination?> outletsPaginationNotifier =
      ValueNotifier(null);
  ValueNotifier<int> editingIndexNotifier = ValueNotifier(-1);
  ValueNotifier<bool> isActiveOutlet = ValueNotifier(true);

  @override
  void initState() {
    super.initState();

    loadItemsOnStart();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> loadItemsOnStart() async {
    print("outletsPaginationNotifier: $outletsPaginationNotifier");
    if (outletsPaginationNotifier.value == null ||
        outletsPaginationNotifier.value!.data.isEmpty) {
      await getAllOutlet("", 1, 5);
    }
  }

  Future<void> getAllOutlet(String name, int page, int length) async {
    try {
      // final email = await Storage.get('userEmail') ?? "";

      final outletsApi = OutletsApi();
      print("testMASOK: $name, $page, $length}");
      final response = await outletsApi.getAllOutlet(name, "", page, length);
      print("testMASOK2: ${response.body.toString()}");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // final List items = data["data"];
        print("testMASOK3");

        pages = page;
        lengths = length;
        print("testMASOK4");

        final pagination = OutletPagination.fromJson(data);
        print("testsssss : ${pagination.totalData}");
        print("testssssss : ${pagination.totalPage}");
        print("testsssssss : ${pagination.page}");
        print("testssssssss : ${pagination.limit}");
        print("testsssssssss : ${pagination}");
        // print("itemsGet: $items");
        // print("data: $data");
        outletsPaginationNotifier.value = pagination;
        // print("test");
        print("testMASOK5");
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

  Future<void> updateOutletRow(OutletResponse item) async {
    final body = {
      "data": {
        "outlet_code": item.outlet_code,
        "outlet_address": _outletAddressController.text.isEmpty
            ? ""
            : _outletAddressController.text,
        "outlet_status": statusEditNotifier.value,
      }
    };

    try {
      final outletsApi = OutletsApi();
      print("body: $body");
      final response = await outletsApi.updateOutlets(body);

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

  Future<void> addItem() async {
    if (outletsArrNotifier.value.isNotEmpty ||
        (_outletNameController.text != "" &&
            _outletAddressController.text != "")) {
      final outlet = Outlet(
        outlet_name: _outletNameController.text,
        outlet_address: _outletAddressController.text,
        outlet_status: isActiveOutlet.value,
      );

      outletsArrNotifier.value = [
        ...outletsArrNotifier.value,
        outlet,
      ];

      _outletNameController.clear();
      _outletAddressController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill out all required fields"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void deleteItem(int index) {
    final updatedList = List<Outlet>.from(outletsArrNotifier.value);
    updatedList.removeAt(index);

    outletsArrNotifier.value = updatedList;
  }

  Future<void> _handleOutlet() async {
    List<Outlet> arrayOneOutlet = [];
    Map<String, dynamic> bodyData;

    if (outletsArrNotifier.value.isEmpty) {
      final outlet = Outlet(
        outlet_name: _outletNameController.text,
        outlet_address: _outletAddressController.text,
        outlet_status: isActiveOutlet.value,
      );
      arrayOneOutlet = [
        ...arrayOneOutlet,
        outlet,
      ];
      bodyData = {
        "data": arrayOneOutlet
            .map((item) => {
                  "outlet_name": item.outlet_name,
                  "outlet_address": item.outlet_address,
                  "outlet_status": item.outlet_status,
                })
            .toList()
      };
    } else {
      bodyData = {
        "data": outletsArrNotifier.value
            .map((item) => {
                  "outlet_name": item.outlet_name,
                  "outlet_address": item.outlet_address,
                  "outlet_status": item.outlet_status,
                })
            .toList()
      };
    }

    try {
      if (outletsArrNotifier.value.isNotEmpty ||
          (_outletNameController.text != "" &&
              _outletAddressController.text != "")) {
        final outletsApi = OutletsApi();
        final response = await outletsApi.insertOutlet(bodyData);
        print("response: ${response.body}");
        if (response.statusCode == 200) {
          arrayOneOutlet = [];
          outletsArrNotifier.value = [];
          _outletNameController.clear();
          _outletAddressController.clear();
          // showToast("Item successfully saved");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Item successfully saved"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacementNamed(context, '/outlet');

          // getAllItems("", 1, 5);
          // await getAllOutlet("", pages, lengths);
          // Future.microtask(() => getAllItems("", 1, 5));
        } else {
          outletsArrNotifier.value = [];
          // showToast("Failed to save item", isError: true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to save outlet"),
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

  Future<void> _handleNewOutlet() async {
    Navigator.pushReplacementNamed(context, '/new-outlet');
  }

  void deleteOutlet(int index) {
    final updatedList = List<Outlet>.from(outletsArrNotifier.value);
    updatedList.removeAt(index);

    outletsArrNotifier.value = updatedList;
  }

  Future<void> _confirmDeleteOutlet(OutletResponse item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Outlet'),
        content: Text('Yakin ingin menghapus outlet "${item.outlet_name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await outletsApi.deleteOutlet(item.outlet_code);
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Outlet berhasil dihapus"),
            backgroundColor: Colors.green,
          ),
        );
        await getAllOutlet(_outletSearchListController.text, pages, lengths);
      } else {
        String message = "Gagal menghapus outlet";
        try {
          final body = jsonDecode(response.body);
          if (body['error'] != null) message = body['error'];
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error menghapus outlet"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(40),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // // Logo
                    // Image.asset(
                    //   'assets/images/logo.png',
                    //   width: 100,
                    //   height: 100,
                    //   errorBuilder: (context, error, stackTrace) {
                    //     return const Icon(
                    //       Icons.fitness_center,
                    //       size: 100,
                    //       color: AppTheme.primaryBlue,
                    //     );
                    //   },
                    // ),
                    // const SizedBox(height: 32),

                    // Title
                    const Text(
                      'List Outlet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

                    TextField(
                      controller: _outletSearchListController,
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
                    // // User field
                    // TextField(
                    //   controller: _outletNameController,
                    //   decoration: const InputDecoration(
                    //     labelText: 'Outlet Name',
                    //     border: OutlineInputBorder(),
                    //   ),
                    //   textInputAction: TextInputAction.next,
                    //   onChanged: (_) => setState(() {}),
                    // ),
                    // DropdownButtonFormField<String>(
                    //   value: _selectedType,
                    //   decoration: const InputDecoration(
                    //     labelText: 'Type',
                    //     border: OutlineInputBorder(),
                    //   ),
                    //   items: _types.map((type) {
                    //     return DropdownMenuItem<String>(
                    //       value: type,
                    //       child: Text(type.toUpperCase()),
                    //     );
                    //   }).toList(),
                    //   onChanged: (value) {
                    //     setState(() {
                    //       _selectedType = value;
                    //     });
                    //   },
                    // ),
                    const SizedBox(height: 16),

                    // // Password field
                    // TextField(
                    //   controller: _passwordController,
                    //   decoration: const InputDecoration(
                    //     labelText: 'Password',
                    //     border: OutlineInputBorder(),
                    //   ),
                    //   obscureText: true,
                    //   textInputAction: TextInputAction.done,
                    //   onChanged: (_) => setState(() {}),
                    //   onSubmitted: (_) => _handleLogin(),
                    // ),

                    // TextField(
                    //   maxLines: 5,
                    //   controller: _outletAddressController,
                    //   decoration: InputDecoration(
                    //     hintText: 'Enter outlet address...',
                    //     filled: true,
                    //     fillColor: Colors.white,
                    //     border: OutlineInputBorder(
                    //       borderRadius: BorderRadius.circular(8),
                    //     ),
                    //     contentPadding: const EdgeInsets.all(16),
                    //   ),
                    // ),

                    ValueListenableBuilder<OutletPagination?>(
                      valueListenable: outletsPaginationNotifier,
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
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
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
                                    DataColumn(label: Text("No.")),
                                    DataColumn(label: Text("Name")),
                                    DataColumn(label: Text("Address")),
                                    DataColumn(label: Text("Status")),
                                    DataColumn(label: Text("Action")),
                                  ],
                                  rows: items.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final item = entry.value;

                                    final isEditing = editingIndex == index;

                                    return DataRow(
                                      cells: [
                                        DataCell(Text("${entry.key + 1}")),

                                        /// NAME
                                        DataCell(
                                          Text(item.outlet_name),
                                        ),

                                        /// TYPE
                                        DataCell(
                                          isEditing
                                              ? SizedBox(
                                                  width: 125,
                                                  child: TextField(
                                                    controller:
                                                        _outletAddressController,
                                                  ),
                                                )
                                              : Text(item.outlet_address),
                                        ),

                                        /// STATUS
                                        DataCell(
                                          isEditing
                                              ? ValueListenableBuilder<String>(
                                                  valueListenable:
                                                      statusEditNotifier,
                                                  builder: (context, value, _) {
                                                    return DropdownButton<
                                                        String>(
                                                      value: value,
                                                      items: const [
                                                        DropdownMenuItem(
                                                          value: "ACTIVE",
                                                          child: Text("ACTIVE"),
                                                        ),
                                                        DropdownMenuItem(
                                                          value: "INACTIVE",
                                                          child:
                                                              Text("NONACTIVE"),
                                                        ),
                                                      ],
                                                      onChanged: (val) {
                                                        statusEditNotifier
                                                            .value = val!;
                                                      },
                                                    );
                                                  },
                                                )
                                              : Text(item.outlet_status.isEmpty
                                                  ? "-"
                                                  : item.outlet_status == "INACTIVE" ? "NONACTIVE" : item.outlet_status),
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
                                                label: Text(isEditing
                                                    ? "Save"
                                                    : "Edit"),
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

                                                    _outletNameController.text =
                                                        item.outlet_name;
                                                    _outletAddressController
                                                            .text =
                                                        item.outlet_address;

                                                    statusEditNotifier
                                                        .value = item
                                                            .outlet_status
                                                            .isEmpty
                                                        ? "ACTIVE"
                                                        : item.outlet_status;
                                                  } else {
                                                    /// SAVE
                                                    await updateOutletRow(item);

                                                    /// 🔧 FIX: keluar dari mode edit
                                                    editingIndexNotifier.value =
                                                        -1;

                                                    await getAllOutlet(
                                                        "", pages, lengths);

                                                    _outletNameController
                                                        .clear();
                                                    _outletAddressController
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
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                  ),
                                                  onPressed: () =>
                                                      _confirmDeleteOutlet(
                                                          item),
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

                    // FOOTER
                    ValueListenableBuilder<OutletPagination?>(
                      valueListenable: outletsPaginationNotifier,
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
                                    getAllOutlet(
                                        _outletSearchListController.text,
                                        1,
                                        value!);
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
                                          getAllOutlet(
                                            _outletSearchListController.text,
                                            pagination.page - 1,
                                            pagination.limit,
                                          );
                                        }
                                      : null,
                                ),
                                Text(
                                  "${pagination.page} / ${pagination.totalPage}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: pagination.page <
                                          pagination.totalPage
                                      ? () {
                                          getAllOutlet(
                                            _outletSearchListController.text,
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

                    const SizedBox(height: 5),
                    const Divider(),
                    const SizedBox(height: 20),

                    // // Login button
                    // SizedBox(
                    //   width: double.infinity,
                    //   height: 48,
                    //   child: ElevatedButton(
                    //     // onPressed:
                    //     //     _isLoading || !_canSubmit ? null : _handleLogin,
                    //     onPressed: _handleOutlet,
                    //     style: ElevatedButton.styleFrom(
                    //       backgroundColor: Colors
                    //           .green.shade600, // button background, #43A047
                    //       foregroundColor: Colors.white, // text & icon color
                    //       disabledBackgroundColor:
                    //           Colors.grey.shade300, // when onPressed is null
                    //       disabledForegroundColor: Colors.grey.shade500,
                    //     ),
                    //     child: _isLoading
                    //         ? const SizedBox(
                    //             width: 20,
                    //             height: 20,
                    //             child: CircularProgressIndicator(
                    //               strokeWidth: 2,
                    //               color: Colors.white,
                    //             ),
                    //           )
                    //         : const Text('SAVE'),
                    //   ),
                    // ),
                    // const SizedBox(height: 16),

                    // Back button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/outlet');
                        },
                        child: const Text('BACK'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
