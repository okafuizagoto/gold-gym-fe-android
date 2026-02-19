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

class StockBarangScreen extends StatefulWidget {
  const StockBarangScreen({super.key});

  @override
  State<StockBarangScreen> createState() => _StockBarangScreenState();
}

class _StockBarangScreenState extends State<StockBarangScreen> {
  final _stockApi = StockApi();
  final _debouncer = Debouncer(milliseconds: 400);
  final _searchController = TextEditingController();

  List<StockModel> _stockList = [];
  String _selectedInputType = 'Keyboard';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _debouncer.run(_fetchAllStock);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _fetchAllStock() async {
    setState(() => _isLoading = true);

    try {
      final response = await _stockApi.getAllStockHeader();
      if (response.statusCode == 200) {
        final apiResponse = ApiResponse<List<StockModel>>.fromJson(
          jsonDecode(response.body),
          (json) => (json as List).map((item) => StockModel.fromJson(item)).toList(),
        );

        if (mounted) {
          setState(() {
            _stockList = apiResponse.data ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching stock: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                title: langProvider.get('Stock Inventory', 'Stok Barang'),
              ),
              drawer: const AppDrawer(),
              body: Column(
                children: [
                  TabBar(
                    labelColor: Theme.of(context).primaryColor,
                    tabs: [
                      Tab(text: langProvider.get('Stock List', 'Daftar Stok')),
                      Tab(text: langProvider.get('Stock Data', 'Data Stok')),
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

  Widget _buildStockListTab(LanguageProvider langProvider) {
    return Column(
      children: [
        // Search form
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: _selectedInputType,
                      decoration: InputDecoration(
                        labelText: langProvider.get('Input Type', 'Tipe Input'),
                        border: const OutlineInputBorder(),
                      ),
                      items: ['Keyboard', 'Barcode'].map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedInputType = value ?? 'Keyboard');
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: langProvider.get('Search', 'Cari'),
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
                    child: ElevatedButton(
                      onPressed: _fetchAllStock,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(langProvider.get('SEARCH', 'CARI')),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {
                      // TODO: Add new stock
                    },
                    icon: const Icon(Icons.add_circle, size: 40),
                    color: Colors.green,
                  ),
                ],
              ),
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
                              label: Text(langProvider.get('Stock Code', 'Kode Stok')),
                            ),
                            DataColumn(
                              label: Text(langProvider.get('Stock Name', 'Nama Stok')),
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
                              label: Text(langProvider.get('Qty Update', 'Update Jumlah')),
                            ),
                            DataColumn(
                              label: Text(langProvider.get('Last Update', 'Update Terakhir')),
                            ),
                            DataColumn(
                              label: Text(langProvider.get('Updated By', 'Diupdate Oleh')),
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
                                      Text(TextFormatter.formatRupiah(entry.value.stockPrice)),
                                    ),
                                    DataCell(
                                      Text(
                                        entry.value.stockQtyUpdate != null
                                            ? TextFormatter.formatDateFull(entry.value.stockQtyUpdate!)
                                            : '-',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        entry.value.stockLastUpdate != null
                                            ? TextFormatter.formatDateFull(entry.value.stockLastUpdate!)
                                            : '-',
                                      ),
                                    ),
                                    DataCell(Text(entry.value.stockUpdateBy ?? '-')),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.download, size: 20),
                                            onPressed: () {
                                              // TODO: Download action
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 20),
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

  Widget _buildStockDataTab(LanguageProvider langProvider) {
    return Center(
      child: Text(
        langProvider.get('Stock data view - Coming soon', 'Tampilan data stok - Segera hadir'),
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }
}
