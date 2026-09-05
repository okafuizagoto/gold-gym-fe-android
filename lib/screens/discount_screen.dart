import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';
import '../widgets/segmented_tabs.dart';
import '../services/discount_api.dart';
import '../models/discount_model.dart';
import '../providers/language_provider.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/constants.dart';
import '../utils/toast.dart';
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

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
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
    if (isError) {
      Toast.error(context, message);
    } else {
      Toast.success(context, message);
    }
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
          title: Text(
            'Edit Diskon — ${d.discountItemName}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Tipe'),
                  items: const [
                    DropdownMenuItem(
                        value: 'PERCENT', child: Text('Persen (%)')),
                    DropdownMenuItem(
                        value: 'NOMINAL', child: Text('Nominal (Rp)')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v ?? 'PERCENT'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Nilai'),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif'),
                  value: status == 'ACTIVE',
                  onChanged: (v) =>
                      setDialogState(() => status = v ? 'ACTIVE' : 'NONACTIVE'),
                ),
              ],
            ),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
                bottom: TabBar(
                  isScrollable: context.isCompact,
                  tabAlignment: context.isCompact
                      ? TabAlignment.start
                      : TabAlignment.fill,
                  tabs: [
                    Tab(
                        text:
                            langProvider.get('Add Discount', 'Tambah Diskon')),
                    Tab(
                        text:
                            langProvider.get('Discount List', 'Daftar Diskon')),
                    Tab(text: langProvider.get('Voucher', 'Voucher')),
                  ],
                ),
              ),
              drawer: const AppDrawer(),
              body: TabBarView(
                children: [
                  _buildInsertTab(langProvider),
                  _buildListTab(langProvider),
                  VoucherTab(outcode: _outcode),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInsertTab(LanguageProvider langProvider) {
    final textTheme = Theme.of(context).textTheme;
    return PageBody(
      maxWidth: 720,
      child: SectionCard(
        title: langProvider.get('Add Discount', 'Tambah Diskon'),
        description: langProvider.get('Discount per product or per total sale',
            'Diskon per produk atau per total penjualan'),
        icon: Icons.percent_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(langProvider.get('Discount Scope', 'Jenis Diskon'),
                style: textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedTabs<String>(
              value: _discountScope,
              onChanged: (s) => setState(() {
                _discountScope = s;
                if (_discountScope == 'TOTAL') _discountType = 'PERCENT';
              }),
              tabs: [
                SegmentedTab(
                    value: 'ITEM',
                    icon: Icons.inventory_2_outlined,
                    label: langProvider.get('Per Product', 'Per Produk')),
                SegmentedTab(
                    value: 'TOTAL',
                    icon: Icons.receipt_long_outlined,
                    label: langProvider.get(
                        'Per Total Sale', 'Per Total Penjualan')),
              ],
            ),
            const SizedBox(height: 16),
            if (_discountScope == 'ITEM') ...[
              Text(langProvider.get('Item', 'Item'),
                  style: textTheme.titleSmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<ItemForOutlet>(
                key: ValueKey('item-${_selectedItem?.itemId ?? 'none'}'),
                initialValue: _selectedItem,
                isExpanded: true,
                items: _items
                    .map((it) => DropdownMenuItem(
                          value: it,
                          child: Text(
                            '${it.itemName} (Rp${it.itemPrice})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedItem = v),
                decoration: const InputDecoration(
                  hintText: 'Pilih item',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
              ),
              const SizedBox(height: 16),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    langProvider.get(
                        'Applies automatically to the total of every sale in this outlet.',
                        'Otomatis berlaku ke total setiap penjualan di outlet ini.'),
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.infoDark),
                  ),
                ),
              ),
            Text(langProvider.get('Discount Type', 'Tipe Diskon'),
                style: textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('type-$_discountScope-$_discountType'),
              initialValue: _discountType,
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
            ),
            const SizedBox(height: 16),
            Text(langProvider.get('Value', 'Nilai'),
                style: textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText:
                    _discountType == 'PERCENT' ? 'contoh: 10' : 'contoh: 5000',
                suffixText: _discountType == 'PERCENT' ? '%' : 'Rp',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _insertDiscount,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(langProvider.get('Save', 'Simpan')),
              ),
            ),
          ],
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
      return SingleChildScrollView(
        child: EmptyState(
          icon: Icons.percent_rounded,
          title: langProvider.get('No discounts yet', 'Belum ada diskon'),
          description: langProvider.get(
              'Create one from the "Add Discount" tab.',
              'Buat lewat tab "Tambah Diskon".'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadDiscounts,
      child: ListView.builder(
        padding: context.pageInsets,
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final d = rows[index];
          final valueLabel = d.discountType == 'PERCENT'
              ? '${d.discountValue.toStringAsFixed(0)}%'
              : 'Rp${NumberFormat('#,###', 'id_ID').format(d.discountValue)}';
          return ContentWidth(
            maxWidth: 900,
            child: _DiscountTile(
              title: d.isTotalScope ? 'Total Penjualan' : d.discountItemName,
              valueLabel: valueLabel,
              status: d.discountStatus,
              scopeLabel: d.isTotalScope ? 'Per Total' : 'Per Produk',
              onHistory: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DiscountHistoryScreen(discountId: d.discountId),
                ),
              ),
              onEdit: () => _editDiscount(d),
              onDelete: () => _deleteDiscount(d),
            ),
          );
        },
      ),
    );
  }
}

class _DiscountTile extends StatelessWidget {
  final String title;
  final String valueLabel;
  final String status;
  final String scopeLabel;
  final VoidCallback onHistory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DiscountTile({
    required this.title,
    required this.valueLabel,
    required this.status,
    required this.scopeLabel,
    required this.onHistory,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final active = status == 'ACTIVE';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.successLight : AppColors.chipBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.percent_rounded,
                  color: active ? AppColors.successDark : AppColors.muted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _MiniPill(
                        label: valueLabel,
                        background: AppColors.blueLight,
                        foreground: AppColors.blueDark,
                      ),
                      _MiniPill(
                        label: status,
                        background:
                            active ? AppColors.successLight : AppColors.chipBg,
                        foreground:
                            active ? AppColors.successDark : AppColors.muted,
                      ),
                      _MiniPill(label: scopeLabel),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.history_rounded),
              color: AppColors.info,
              tooltip: 'Riwayat',
              visualDensity: VisualDensity.compact,
              onPressed: onHistory,
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              color: AppColors.blue,
              tooltip: 'Edit',
              visualDensity: VisualDensity.compact,
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.error,
              tooltip: 'Hapus',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final Color? background;
  final Color? foreground;

  const _MiniPill({required this.label, this.background, this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? AppColors.chipBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground ?? AppColors.ink,
        ),
      ),
    );
  }
}
