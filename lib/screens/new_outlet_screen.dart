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

class NewOutletScreen extends StatefulWidget {
  const NewOutletScreen({super.key});

  @override
  State<NewOutletScreen> createState() => _OutletScreenState();
}

class _OutletScreenState extends State<NewOutletScreen> {
  final _formKey = GlobalKey<FormState>();
  final outletsApi = OutletsApi();
  final _outletAddressController = TextEditingController();
  final _outletNameController = TextEditingController();
  final outletsArrNotifier = ValueNotifier<List<Outlet>>([]);

  bool _isLoading = false;

  ValueNotifier<bool> isActiveOutlet = ValueNotifier(true);

  @override
  void dispose() {
    super.dispose();
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
                  "outlet_status": item.outlet_status ? "ACTIVE" : "NON ACTIVE",
                })
            .toList()
      };
    } else {
      bodyData = {
        "data": outletsArrNotifier.value
            .map((item) => {
                  "outlet_name": item.outlet_name,
                  "outlet_address": item.outlet_address,
                  "outlet_status": item.outlet_status ? "ACTIVE" : "NON ACTIVE",
                })
            .toList()
      };
    }

    try {
      if (outletsArrNotifier.value.isNotEmpty ||
          (_outletNameController.text != "" &&
              _outletAddressController.text != "")) {
        final outletsApi = OutletsApi();
        print("bodyInsert: $bodyData");
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
                    // Title
                    const Text(
                      'Register Outlet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // User field
                    TextField(
                      controller: _outletNameController,
                      decoration: const InputDecoration(
                        labelText: 'Outlet Name',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
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
                    TextField(
                      maxLines: 5,
                      controller: _outletAddressController,
                      decoration: InputDecoration(
                        hintText: 'Enter outlet address...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Row(children: [
                      const Icon(Icons.settings_outlined, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        'Status',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // const Spacer(),
                      const SizedBox(width: 18),
                      ValueListenableBuilder<bool>(
                        valueListenable: isActiveOutlet,
                        builder: (context, value, child) {
                          return Row(
                            children: [
                              Text(
                                "${!value ? 'Non Active' : 'Active'} :",
                                style: const TextStyle(fontSize: 16),
                              ),
                              SizedBox(width: !value ? 5 : 39),
                            ],
                          );
                        },
                      ),
                      StatusSwitch(
                        initialValue: isActiveOutlet.value,
                        onChanged: (bool value) {
                          isActiveOutlet.value =
                              value; // simpan ke variable utama
                          print("Status sekarang: ${isActiveOutlet.value}");
                        },
                      ),
                    ]),
                    const SizedBox(height: 32),

                    ValueListenableBuilder<List<Outlet>>(
                      valueListenable: outletsArrNotifier,
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
                                  constraints:
                                      const BoxConstraints(minWidth: 700),
                                  child: DataTable(
                                    columnSpacing: 20,
                                    columns: const [
                                      DataColumn(label: Text("No.")),
                                      DataColumn(label: Text("Outlet Name")),
                                      DataColumn(label: Text("Outlet Address")),
                                      DataColumn(label: Text("Outlet Status")),
                                      DataColumn(label: Text("Action")),
                                    ],
                                    rows: items.asMap().entries.map((entry) {
                                      final item = entry.value;

                                      return DataRow(
                                        cells: [
                                          DataCell(Text("${entry.key + 1}")),
                                          DataCell(Text(item.outlet_name)),
                                          DataCell(Text(item.outlet_address)),
                                          DataCell(Text(
                                            item.outlet_status
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

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        // onPressed:
                        //     _isLoading || !_canSubmit ? null : _handleLogin,
                        onPressed: _handleOutlet,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('SAVE'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        // onPressed:
                        //     _isLoading || !_canSubmit ? null : _handleLogin,
                        onPressed: addItem,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('ADD MORE'),
                      ),
                    ),
                    const SizedBox(height: 16),

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
