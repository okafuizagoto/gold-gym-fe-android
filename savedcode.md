Widget \_buildStockListTab(LanguageProvider langProvider) {
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
child: TextField(
controller: \_searchController,
decoration: InputDecoration(
labelText: langProvider.get('Search', 'Cari'),
border: const OutlineInputBorder(),
),
),
),
const SizedBox(width: 15),
Expanded(
flex: 1,
// child: ElevatedButton.icon(
child: ElevatedButton(
onPressed: \_fetchAllStock,
// icon: const Icon(Icons.search, size: 35),
// label: Text(
// langProvider.get('', ''),
// ),
style: ElevatedButton.styleFrom(
backgroundColor: Colors.green,
foregroundColor: Colors.white,
padding: const EdgeInsets.symmetric(vertical: 8),
// padding: EdgeInsets.zero, // hilangkan padding default
),
child: const Icon(
Icons.search,
size: 35,
),
// child: Text(langProvider.get('SEARCH', 'CARI')),
),
),
],
),
// const SizedBox(height: 16),
// Row(
// children: [
// const SizedBox(width: 16),
// IconButton(
// onPressed: () {
// // TODO: Add new stock
// },
// icon: const Icon(Icons.add_circle, size: 40),
// color: Colors.green,
// ),
// ],
// ),
],
),
),

        // Table
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _stockList.isEmpty
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

<!-- -------------------------------------------------------------------------------------------------- -->

Expanded(
child: \_isLoading
? const Center(child: CircularProgressIndicator())
: \_stockList.isEmpty
? Center(
child: Text(
langProvider.get(
'No data available', 'Tidak ada data'),
),
)
: SingleChildScrollView(
scrollDirection: Axis.horizontal,
child: SingleChildScrollView(
child: DataTable(
columnSpacing: 20,
columns: [
DataColumn(
label: Text(
langProvider.get('NO', 'NO')),
),
DataColumn(
label: Text(langProvider.get(
'Item Name', 'Kode Stok')),
),
DataColumn(
label: Text(langProvider.get(
'Stock Name', 'Nama Stok')),
),
DataColumn(
label: Text(langProvider.get(
'Pack', 'Kemasan')),
),
DataColumn(
label: Text(langProvider.get(
'Qty', 'Jumlah')),
),
DataColumn(
label: Text(langProvider.get(
'Price', 'Harga')),
),
DataColumn(
label: Text(langProvider.get(
'Qty Update', 'Update Jumlah')),
),
DataColumn(
label: Text(langProvider.get(
'Last Update',
'Update Terakhir')),
),
DataColumn(
label: Text(langProvider.get(
'Updated By', 'Diupdate Oleh')),
),
DataColumn(
label: Text(langProvider.get(
'ACTION', 'AKSI')),
),
],
rows: \_stockList
.asMap()
.entries
.map(
(entry) => DataRow(
cells: [
DataCell(
Text('${entry.key + 1}')),
                                                DataCell(Text(
                                                    entry.value.stockCode)),
                                                DataCell(Text(
                                                    entry.value.stockName)),
                                                DataCell(Text(
                                                    entry.value.stockPack)),
                                                DataCell(Text(
                                                    '${entry.value.stockQty}')),
DataCell(
Text(TextFormatter
.formatRupiah(entry
.value.stockPrice)),
),
DataCell(
Text(
entry.value.stockQtyUpdate !=
null
? TextFormatter
.formatDateFull(entry
.value
.stockQtyUpdate!)
: '-',
),
),
DataCell(
Text(
entry.value.stockLastUpdate !=
null
? TextFormatter
.formatDateFull(entry
.value
.stockLastUpdate!)
: '-',
),
),
DataCell(Text(
entry.value.stockUpdateBy ??
'-')),
DataCell(
Row(
mainAxisSize:
MainAxisSize.min,
children: [
IconButton(
icon: const Icon(
Icons.download,
size: 20),
onPressed: () {
// TODO: Download action
},
),
IconButton(
icon: const Icon(
Icons.delete,
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

_isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : itemsArr.isEmpty
                          ? Center(
                              // child: Text(
                              //   langProvider.get(
                              //       'No data available', 'Tidak ada data'),
                              // ),
                              )
                          :