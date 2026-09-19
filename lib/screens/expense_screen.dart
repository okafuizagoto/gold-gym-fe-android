import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/expense_model.dart';
import '../services/expense_api.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

/// Pencatatan Pengeluaran: ledger biaya operasional (sewa/listrik/gaji/dst)
/// milik SATU outlet, berdampingan dengan ledger penjualan -- form input +
/// ringkasan per kategori + riwayat. Kategori & outcode SELALU divalidasi
/// ulang server-side, form ini cuma UX. Padanan pages/expense (Next.js).
class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _expenseApi = ExpenseApi();
  final _formKey = GlobalKey<FormState>();
  final _vendorController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  String _category = ExpenseCategory.sewa;
  DateTime _date = DateTime.now();
  bool _isRecurring = false;
  String _recurringPeriod = RecurringPeriod.bulanan;
  bool _saving = false;

  bool _loading = true;
  bool _isStaff = false;
  String _outcode = '';
  List<Expense> _rows = [];
  ExpenseSummary? _summary;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final outcode = await Storage.get(AppConstants.outcode) ?? '';
    final role = await Storage.get(AppConstants.userRoleKey) ?? '';
    if (mounted) {
      setState(() {
        _outcode = outcode;
        _isStaff = role == AppConstants.roleStaff;
      });
    }
    await _load();
  }

  // KOREKSI 2026-09-18 (QA audit #1.3): dulu tanpa try/catch, beda dari
  // `_submit()` di file yang sama yang sudah benar -- exception (timeout,
  // dll) bikin seluruh body (form + riwayat) macet permanen di spinner.
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _expenseApi.list(outcode: _outcode);
      final summary = await _expenseApi.summary(outcode: _outcode);
      if (mounted) {
        setState(() {
          _rows = rows ?? [];
          _summary = summary;
        });
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Gagal memuat data pengeluaran: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.tryParse(
        _amountController.text.replaceAll('.', '').replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      Toast.error(context, 'Nominal harus lebih dari 0');
      return;
    }
    setState(() => _saving = true);
    try {
      final resp = await _expenseApi.create(
        category: _category,
        vendor: _vendorController.text.trim(),
        amount: amount,
        date: DateFormat('yyyy-MM-dd').format(_date),
        description: _descController.text.trim(),
        isRecurring: _isRecurring,
        recurringPeriod: _isRecurring ? _recurringPeriod : null,
        outcode: _outcode,
      );
      if (resp.statusCode == 200) {
        if (mounted) Toast.success(context, 'Pengeluaran tersimpan');
        _vendorController.clear();
        _amountController.clear();
        _descController.clear();
        setState(() {
          _category = ExpenseCategory.sewa;
          _date = DateTime.now();
          _isRecurring = false;
        });
        await _load();
      } else {
        String msg = 'Gagal menyimpan pengeluaran';
        try {
          msg = jsonDecode(resp.body)['error']?.toString() ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal menyimpan pengeluaran');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus pengeluaran?'),
        content: Text(
            '${ExpenseCategory.label(e.expenseCategory)} - ${TextFormatter.formatRupiah(e.expenseAmount)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Hapus', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok != true) return;
    final resp = await _expenseApi.deleteExpense(e.expenseId);
    if (resp.statusCode == 200) {
      if (mounted) Toast.success(context, 'Pengeluaran dihapus');
      await _load();
    } else {
      if (mounted) Toast.error(context, 'Gagal menghapus pengeluaran');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Pencatatan Pengeluaran'),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _formCard(),
                    const SizedBox(height: 16),
                    _summaryCard(),
                    const SizedBox(height: 16),
                    _historyCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _formCard() {
    return SectionCard(
      title: 'Catat Pengeluaran',
      icon: Icons.add_card_outlined,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: ExpenseCategory.all
                  .map((c) => DropdownMenuItem(
                      value: c, child: Text(ExpenseCategory.label(c))))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vendorController,
              decoration: const InputDecoration(
                  labelText: 'Vendor / Penerima (opsional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Nominal (Rp)', prefixText: 'Rp '),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nominal wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
                child: Text(DateFormat('d MMMM yyyy', 'id_ID').format(_date)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isRecurring,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Pengeluaran berulang?'),
              onChanged: (v) => setState(() => _isRecurring = v ?? false),
            ),
            if (_isRecurring)
              DropdownButtonFormField<String>(
                initialValue: _recurringPeriod,
                decoration: const InputDecoration(labelText: 'Periode'),
                items: RecurringPeriod.all
                    .map((p) => DropdownMenuItem(
                        value: p, child: Text(RecurringPeriod.label(p))))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _recurringPeriod = v ?? _recurringPeriod),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final s = _summary;
    return SectionCard(
      title: 'Ringkasan Bulan Ini',
      icon: Icons.pie_chart_outline_rounded,
      child: s == null || s.count == 0
          ? const Text('Belum ada pengeluaran pada periode ini.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total: ${TextFormatter.formatRupiah(s.totalAmount)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 10),
                for (final c in s.byCategory)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(ExpenseCategory.label(c.category)),
                        Text(TextFormatter.formatRupiah(c.totalAmount),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _historyCard() {
    return SectionCard(
      title: 'Riwayat Pengeluaran',
      icon: Icons.receipt_long_outlined,
      child: _rows.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Belum ada pengeluaran',
              compact: true,
            )
          : Column(
              children: _rows
                  .map((e) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(ExpenseCategory.label(e.expenseCategory)),
                        subtitle: Text(
                          [
                            e.expenseDate,
                            if (e.expenseVendor.isNotEmpty) e.expenseVendor,
                          ].join(' · '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(TextFormatter.formatRupiah(e.expenseAmount),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            if (!_isStaff)
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.error, size: 20),
                                onPressed: () => _confirmDelete(e),
                              ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}
