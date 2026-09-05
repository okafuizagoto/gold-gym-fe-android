import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../services/discount_api.dart';
import '../models/discount_model.dart';
import '../utils/responsive.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_card.dart';
import '../utils/toast.dart';
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

  @override
  void dispose() {
    _codeController.dispose();
    _percentController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (isError) {
      Toast.error(context, message);
    } else {
      Toast.success(context, message);
    }
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
    final percent =
        double.tryParse(_percentController.text.replaceAll(',', '.'));
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('HAPUS')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final resp =
          await _discountApi.deleteVoucher(v.voucherId, widget.outcode);
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
    final textTheme = Theme.of(context).textTheme;
    final vouchers = _pagination?.data ?? [];
    return PageBody(
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Buat Voucher',
            description: 'Kode voucher untuk potongan persen di kasir',
            icon: Icons.confirmation_number_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Kode Voucher', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
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
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _generating ? null : _generateCode,
                        child: _generating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Generate'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Persentase Diskon (%)', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _percentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'contoh: 10',
                    suffixText: '%',
                  ),
                ),
                const SizedBox(height: 16),
                Text('Kedaluwarsa (opsional)', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickExpiry,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.event_outlined),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(_expiredAt == null
                        ? 'Tanpa batas waktu'
                        : DateFormat('dd-MM-yyyy').format(_expiredAt!)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _insertVoucher,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Simpan Voucher'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text('Voucher Aktif', style: textTheme.titleLarge),
              ),
              TextButton.icon(
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('Riwayat'),
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (vouchers.isEmpty)
            const EmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'Belum ada voucher aktif',
              description: 'Voucher yang dibuat akan tampil di sini sampai '
                  'terpakai atau kedaluwarsa.',
              compact: true,
            )
          else
            ...vouchers.map((v) => _VoucherTile(
                  voucher: v,
                  onDelete: () => _deleteVoucher(v),
                )),
        ],
      ),
    );
  }
}

class _VoucherTile extends StatelessWidget {
  final VoucherResponse voucher;
  final VoidCallback onDelete;

  const _VoucherTile({required this.voucher, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final expiry = voucher.voucherExpiredAt != null
        ? 'kedaluwarsa ${DateFormat('dd-MM-yyyy').format(voucher.voucherExpiredAt!)}'
        : 'tanpa batas waktu';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.confirmation_number_outlined,
                  color: AppColors.warningDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voucher.voucherCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(letterSpacing: 1),
                  ),
                  Text(
                    '${voucher.voucherPercent.toStringAsFixed(0)}% • $expiry',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error),
              tooltip: 'Hapus',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
