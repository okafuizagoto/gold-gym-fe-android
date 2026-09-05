import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/discount_api.dart';
import '../models/discount_model.dart';
import 'discount_voucher_history_screen.dart';

/// Tab "Voucher" di layar Diskon: buat kode voucher (ketik manual atau
/// generate huruf besar+angka), persen diskon, kedaluwarsa opsional, dan
/// daftar voucher aktif (belum terpakai) untuk outlet ini.
class VoucherTab extends StatefulWidget {
  final String outcode;
  const VoucherTab({super.key, required this.outcode});

  @override
  State<VoucherTab> createState() => _VoucherTabState();
}

class _VoucherTabState extends State<VoucherTab> {
  final _discountApi = DiscountApi();
  final _codeController = TextEditingController();
  final _percentController = TextEditingController();
  DateTime? _expiredAt;
  bool _generating = false;

  VoucherPagination? _pagination;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  Future<void> _loadVouchers() async {
    setState(() => _loading = true);
    try {
      final resp = await _discountApi.getVouchers(widget.outcode, 1, 20);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (!mounted) return;
        setState(() => _pagination = VoucherPagination.fromJson(data));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateCode() async {
    setState(() => _generating = true);
    try {
      final resp = await _discountApi.generateVoucherCode(widget.outcode);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        _codeController.text = data['data']['voucher_code'] ?? '';
      } else {
        _showMessage('Gagal membuat kode voucher', isError: true);
      }
    } catch (_) {
      _showMessage('Gagal membuat kode voucher', isError: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expiredAt = picked);
  }

  Future<void> _insertVoucher() async {
    final percent = double.tryParse(_percentController.text.replaceAll(',', '.'));
    if (percent == null || percent <= 0 || percent > 100) {
      _showMessage('Persentase voucher harus 1-100', isError: true);
      return;
    }
    final body = {
      "data": {
        "voucher_outcode": widget.outcode,
        // kosong = backend auto-generate; kalau diisi manual, backend akan
        // memaksa huruf besar semua
        "voucher_code": _codeController.text.trim(),
        "voucher_percent": percent,
        if (_expiredAt != null)
          "voucher_expired_at": _expiredAt!.toIso8601String(),
      }
    };
    try {
      final resp = await _discountApi.insertVoucher(body);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final code = data['data']?['voucher_code'] ?? _codeController.text;
        _showMessage('Voucher $code berhasil dibuat');
        _codeController.clear();
        _percentController.clear();
        setState(() => _expiredAt = null);
        await _loadVouchers();
      } else {
        final data = jsonDecode(resp.body);
        _showMessage(data['error']?.toString() ?? 'Gagal membuat voucher',
            isError: true);
      }
    } catch (_) {
      _showMessage('Gagal membuat voucher', isError: true);
    }
  }

  Future<void> _deleteVoucher(VoucherResponse v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Voucher'),
        content: Text('Hapus voucher "${v.voucherCode}"?'),
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
      final resp = await _discountApi.deleteVoucher(v.voucherId, widget.outcode);
      if (resp.statusCode == 200) {
        _showMessage('Voucher berhasil dihapus');
        await _loadVouchers();
      } else {
        _showMessage('Gagal menghapus voucher', isError: true);
      }
    } catch (_) {
      _showMessage('Gagal menghapus voucher', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kode Voucher',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Ketik sendiri atau Generate',
                        ),
                        onChanged: (v) {
                          final upper = v.toUpperCase();
                          if (v != upper) {
                            _codeController.value = _codeController.value
                                .copyWith(
                                    text: upper,
                                    selection: TextSelection.collapsed(
                                        offset: upper.length));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _generating ? null : _generateCode,
                      child: _generating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Generate'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Persentase Diskon (%)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _percentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixText: '%',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Kedaluwarsa (opsional)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickExpiry,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(_expiredAt == null
                        ? 'Tanpa batas waktu'
                        : DateFormat('dd-MM-yyyy').format(_expiredAt!)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _insertVoucher,
                    child: const Text('Simpan Voucher'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Voucher Aktif',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Riwayat voucher',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DiscountVoucherHistoryScreen(outcode: widget.outcode),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if ((_pagination?.data ?? []).isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Belum ada voucher aktif'),
          )
        else
          ...(_pagination!.data.map((v) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.confirmation_number, color: Colors.white),
                  ),
                  title: Text(v.voucherCode,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, letterSpacing: 1)),
                  subtitle: Text(
                    '${v.voucherPercent.toStringAsFixed(0)}%'
                    '${v.voucherExpiredAt != null ? ' • kedaluwarsa ${DateFormat('dd-MM-yyyy').format(v.voucherExpiredAt!)}' : ' • tanpa batas waktu'}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteVoucher(v),
                  ),
                ),
              ))),
      ],
    );
  }
}
