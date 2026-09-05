import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/private_route.dart';
import '../services/discount_api.dart';
import '../models/discount_model.dart';
import '../providers/language_provider.dart';
import '../utils/storage.dart';
import '../utils/constants.dart';
import 'discount_history_screen.dart';
import 'discount_voucher_tab.dart';

class DiscountScreen extends StatefulWidget {
  const DiscountScreen({super.key});

  @override
  State<DiscountScreen> createState() => _DiscountScreenState();
}

class _DiscountScreenState extends State<DiscountScreen> {
  final _discountApi = DiscountApi();
  String _outcode = '';

  List<ItemForOutlet> _items = [];
  ItemForOutlet? _selectedItem;
  String _discountScope = 'ITEM'; // ITEM | TOTAL
  String _discountType = 'PERCENT';
  final _valueController = TextEditingController();

  DiscountPagination? _pagination;
  int _page = 1;
  final int _length = 10;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _outcode = await Storage.get(AppConstants.outcode) ?? '';
    await _loadItems();
    await _loadDiscounts();
  }

  Future<void> _loadItems() async {
    try {
      final resp = await _discountApi.getItemsForOutlet(_outcode, '');
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data['data'] as List? ?? [])
            .map((e) => ItemForOutlet.fromJson(e))
            .toList();
        if (!mounted) return;
        setState(() => _items = list);
      }
    } catch (_) {}
  }

  Future<void> _loadDiscounts() async {
    setState(() => _loading = true);
    try {
      final resp =
          await _discountApi.getDiscounts(_outcode, '', _page, _length);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (!mounted) return;
        setState(() => _pagination = DiscountPagination.fromJson(data));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  Future<void> _insertDiscount() async {
    final isTotal = _discountScope == 'TOTAL';
    if (!isTotal && _selectedItem == null) {
      _showMessage('Pilih item terlebih dahulu', isError: true);
      return;
    }
    final value = double.tryParse(_valueController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      _showMessage('Nilai diskon tidak valid', isError: true);
      return;
    }
    final effectiveType = isTotal ? 'PERCENT' : _discountType;
    if (effectiveType == 'PERCENT' && value > 100) {
      _showMessage('Diskon persen maksimal 100', isError: true);
      return;
    }
    final body = {
      "data": [
        {
          "discount_outcode": _outcode,
          "discount_scope": _discountScope,
          "discount_item_id": isTotal ? 0 : _selectedItem!.itemId,
          "discount_item_name": isTotal ? '' : _selectedItem!.itemName,
          "discount_type": effectiveType,
          "discount_value": value,
          "discount_status": "ACTIVE",
        }
      ]
    };
    try {
      final resp = await _discountApi.insertDiscounts(body);
      if (resp.statusCode == 200) {
        _showMessage('Diskon berhasil disimpan');
        _valueController.clear();
        setState(() => _selectedItem = null);
        await _loadDiscounts();
      } else {
        _showMessage('Gagal menyimpan diskon', isError: true);
      }
    } catch (_) {
      _showMessage('Gagal menyimpan diskon', isError: true);
    }
  }

  Future<void> _editDiscount(DiscountResponse d) async {
    String type = d.discountType;
    final valueCtrl =
        TextEditingController(text: d.discountValue.toStringAsFixed(0));
    String status = d.discountStatus;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Edit Diskon — ${d.discountItemName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'PERCENT', child: Text('Persen (%)')),
                  DropdownMenuItem(
                      value: 'NOMINAL', child: Text('Nominal (Rp)')),
                ],
                onChanged: (v) => setDialogState(() => type = v ?? 'PERCENT'),
              ),
              TextField(
                controller: valueCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nilai'),
              ),
              SwitchListTile(
                title: const Text('Aktif'),
                value: status == 'ACTIVE',
                onChanged: (v) =>
                    setDialogState(() => status = v ? 'ACTIVE' : 'NONACTIVE'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('BATAL')),
            ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('SIMPAN')),
          ],
        ),
      ),
    );

    if (result != true) return;
    final value = double.tryParse(valueCtrl.text.replaceAll(',', '.')) ?? 0;
    try {
      final resp = await _discountApi.updateDiscount({
        "data": {
          "discount_id": d.discountId,
          "discount_type": type,
          "discount_value": value,
          "discount_status": status,
        }
      });
      if (resp.statusCode == 200) {
        _showMessage('Diskon berhasil diperbarui');
        await _loadDiscounts();
      } else {
        _showMessage('Gagal memperbarui diskon', isError: true);
      }
    } catch (_) {
      _showMessage('Gagal memperbarui diskon', isError: true);
    }
  }

  Future<void> _deleteDiscount(DiscountResponse d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Diskon'),
        content: Text('Hapus diskon untuk "${d.discountItemName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('BATAL')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('HAPUS')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final resp = await _discountApi.deleteDiscount(d.discountId, _outcode);
      if (resp.statusCode == 200) {
        _showMessage('Diskon berhasil dihapus');
        await _loadDiscounts();
      } else {
        _showMessage('Gagal menghapus diskon', isError: true);
      }
    } catch (_) {
      _showMessage('Gagal menghapus diskon', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Consumer<LanguageProvider>(
        builder: (context, langProvider, child) {
          return DefaultTabController(
            length: 3,
            child: Scaffold(
              appBar: AppBarCustom(
                title: langProvider.get('Discount', 'Diskon'),
              ),
              drawer: const AppDrawer(),
              body: Column(
                children: [
                  TabBar(
                    labelColor: Theme.of(context).primaryColor,
                    isScrollable: true,
                    tabs: [
                      Tab(text: langProvider.get('Add Discount', 'Tambah Diskon')),
                      Tab(text: langProvider.get('Discount List', 'Daftar Diskon')),
                      Tab(text: langProvider.get('Voucher', 'Voucher')),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildInsertTab(langProvider),
                        _buildListTab(langProvider),
                        VoucherTab(outcode: _outcode),
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

  Widget _buildInsertTab(LanguageProvider langProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(langProvider.get('Discount Scope', 'Jenis Diskon'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                      value: 'ITEM',
                      label: Text(langProvider.get('Per Product', 'Per Produk'))),
                  ButtonSegment(
                      value: 'TOTAL',
                      label:
                          Text(langProvider.get('Per Total Sale', 'Per Total Penjualan'))),
                ],
                selected: {_discountScope},
                onSelectionChanged: (s) => setState(() {
                  _discountScope = s.first;
                  if (_discountScope == 'TOTAL') _discountType = 'PERCENT';
                }),
              ),
              const SizedBox(height: 16),
              if (_discountScope == 'ITEM') ...[
                Text(langProvider.get('Item', 'Item'),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<ItemForOutlet>(
                  value: _selectedItem,
                  isExpanded: true,
                  items: _items
                      .map((it) => DropdownMenuItem(
                            value: it,
                            child: Text('${it.itemName} (Rp${it.itemPrice})'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedItem = v),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Pilih item',
                  ),
                ),
                const SizedBox(height: 16),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    langProvider.get(
                        'Applies automatically to the total of every sale in this outlet.',
                        'Otomatis berlaku ke total setiap penjualan di outlet ini.'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
              Text(langProvider.get('Discount Type', 'Tipe Diskon'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _discountType,
                items: [
                  const DropdownMenuItem(
                      value: 'PERCENT', child: Text('Persen (%)')),
                  if (_discountScope == 'ITEM')
                    const DropdownMenuItem(
                        value: 'NOMINAL', child: Text('Nominal (Rp)')),
                ],
                onChanged: _discountScope == 'TOTAL'
                    ? null
                    : (v) => setState(() => _discountType = v ?? 'PERCENT'),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Text(langProvider.get('Value', 'Nilai'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _valueController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  suffixText: _discountType == 'PERCENT' ? '%' : 'Rp',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _insertDiscount,
                  child: Text(langProvider.get('Save', 'Simpan')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTab(LanguageProvider langProvider) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final rows = _pagination?.data ?? [];
    if (rows.isEmpty) {
      return Center(
          child: Text(langProvider.get('No discounts yet', 'Belum ada diskon')));
    }
    return RefreshIndicator(
      onRefresh: _loadDiscounts,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final d = rows[index];
          final valueLabel = d.discountType == 'PERCENT'
              ? '${d.discountValue.toStringAsFixed(0)}%'
              : 'Rp${NumberFormat('#,###', 'id_ID').format(d.discountValue)}';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    d.discountStatus == 'ACTIVE' ? Colors.green : Colors.grey,
                child: const Icon(Icons.percent, color: Colors.white),
              ),
              title: Text(
                  d.isTotalScope ? 'Total Penjualan' : d.discountItemName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '$valueLabel • ${d.discountStatus} • ${d.isTotalScope ? 'Per Total' : 'Per Produk'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.history),
                    color: Colors.indigo,
                    tooltip: 'Riwayat',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DiscountHistoryScreen(discountId: d.discountId),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    color: Colors.blue,
                    tooltip: 'Edit',
                    onPressed: () => _editDiscount(d),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    color: Colors.red,
                    tooltip: 'Hapus',
                    onPressed: () => _deleteDiscount(d),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
