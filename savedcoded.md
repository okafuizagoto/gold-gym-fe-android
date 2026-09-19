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
style: TextStyle(
fontSize: 16,
color: Colors.grey,
),
),
);
}

                    final items = pagination.data;

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
                            Colors.grey.shade200,
                          ),
                          columns: const [
                            DataColumn(label: Text("Name")),
                            DataColumn(label: Text("Type")),
                            DataColumn(label: Text("Brand")),
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
                                          width: 150,
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
                                          width: 150,
                                          child: TextField(
                                            controller: _itemTypeController,
                                          ),
                                        )
                                      : Text(item.item_type),
                                ),

                                /// BRAND
                                DataCell(
                                  isEditing
                                      ? SizedBox(
                                          width: 150,
                                          child: TextField(
                                            controller: _itemBrandController,
                                          ),
                                        )
                                      : Text(item.item_brand),
                                ),

                                /// STATUS
                                DataCell(
                                  isEditing
                                      ? ValueListenableBuilder<String>(
                                          valueListenable: statusEditNotifier,
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
                                                statusEditNotifier.value = val!;
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
                                            isEditing ? Icons.save : Icons.edit,
                                            size: 16),
                                        label:
                                            Text(isEditing ? "Save" : "Edit"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isEditing
                                              ? Colors.green
                                              : Colors.blue,
                                        ),
                                        onPressed: () async {
                                          if (!isEditing) {
                                            /// START EDIT
                                            editingIndex = index;

                                            _itemNameController.text =
                                                item.item_name;
                                            _itemTypeController.text =
                                                item.item_type;
                                            _itemBrandController.text =
                                                item.item_brand;

                                            statusEditNotifier.value =
                                                item.item_status.isEmpty
                                                    ? "ACTIVE"
                                                    : item.item_status;

                                            // itemsPaginationNotifier
                                            //     .notifyListeners();
                                          } else {
                                            /// SAVE
                                            // await update(); // hardcode
                                            // await get(); // hardcode

                                            editingIndex = -1;

                                            _itemNameController.clear();
                                            _itemTypeController.clear();
                                            _itemBrandController.clear();

                                            itemsPaginationNotifier
                                                .notifyListeners();
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
                                            deleteItem(index);
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
                ),
