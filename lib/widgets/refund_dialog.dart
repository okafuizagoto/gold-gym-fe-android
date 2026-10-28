import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/refund_model.dart';
import '../providers/language_provider.dart';
import '../services/refund_api.dart';
import '../services/thermal_printer.dart';
import '../utils/refund_escpos.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';

/// Refund Tahap 1 (kembalikan barang + uang), padanan components/RefundDialog.tsx di web: pilih barang dan jumlah
/// yang dikembalikan, metode pengembalian uang, dan alasan. Nilai per barang sudah memperhitungkan diskon/voucher
/// nota (dihitung backend). Setelah berhasil, langsung bisa mencetak STRUK REFUND (PDF atau thermal).
Future<void> showRefundDialog(BuildContext context, String saleId,
    {VoidCallback? onDone}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RefundDialog(saleId: saleId, onDone: onDone),
  );
}

class _RefundDialog extends StatefulWidget {
  final String saleId;
  final VoidCallback? onDone;
  const _RefundDialog({required this.saleId, this.onDone});

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  final _api = RefundApi();
  final _reason = TextEditingController();
  Refundable? _data;
  bool _loading = true;
  bool _saving = false;
  bool _printing = false;
  RefundDetail? _done;
  String _method = 'TUNAI';
  final Map<int, int> _qty = {};
  final Map<int, bool> _restock = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final resp = await _api.refundable(widget.saleId);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final r = Refundable.fromJson(jsonDecode(resp.body)['data']);
        setState(() {
          _data = r;
          _method = defaultRefundMethod(r.payType);
          _loading = false;
        });
      } else {
        _fail('Gagal memuat nota');
      }
    } catch (_) {
      if (mounted) _fail('Gagal memuat nota');
    }
  }

  void _fail(String msg) {
    Toast.error(context, msg);
    Navigator.pop(context);
  }

  double get _total => _data == null
      ? 0
      : _data!.lines.fold<double>(
          0, (s, l) => s + (_qty[l.tdId] ?? 0) * l.unitRefund);

  bool get _anySelected =>
      _data != null && _data!.lines.any((l) => (_qty[l.tdId] ?? 0) > 0);

  Future<void> _submit() async {
    final lang = context.read<LanguageProvider>();
    if (_data == null || !_anySelected) return;
    if (_reason.text.trim().isEmpty) {
      Toast.error(context, lang.get('Reason is required', 'Alasan refund wajib diisi'));
      return;
    }
    setState(() => _saving = true);
    try {
      final resp = await _api.create(
        saleId: _data!.saleId,
        items: _data!.lines
            .where((l) => (_qty[l.tdId] ?? 0) > 0)
            .map((l) => {
                  'td_id': l.tdId,
                  'qty': _qty[l.tdId],
                  'restock': _restock[l.tdId] ?? true,
                })
            .toList(),
        method: _method,
        reason: _reason.text.trim(),
      );
      if (!mounted) return;
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        setState(() =>
            _done = RefundDetail.fromJson(jsonDecode(resp.body)['data']));
        Toast.success(context, lang.get('Refund recorded', 'Refund tercatat'));
        widget.onDone?.call();
      } else {
        String msg = lang.get('Refund failed', 'Refund gagal');
        try {
          final b = jsonDecode(resp.body);
          if (b['error'] is String) msg = b['error'];
          if (b['message'] is String) msg = b['message'];
        } catch (_) {}
        Toast.error(context, msg);
      }
    } catch (e) {
      if (mounted) Toast.error(context, 'Refund gagal: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _printPdf() async {
    if (_done == null) return;
    setState(() => _printing = true);
    try {
      final pdf = await _api.getReceiptPdf(_done!.header.refundId);
      if (pdf == null) {
        if (mounted) Toast.error(context, 'Struk tidak ditemukan');
        return;
      }
      await Printing.layoutPdf(onLayout: (format) async => pdf);
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal cetak struk');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _printThermal() async {
    if (_done == null) return;
    setState(() => _printing = true);
    try {
      final paper = await ThermalPrinter.paperWidthMm;
      final bytes = await RefundEscPos.build(_done!, paperWidthMm: paper);
      final err = await ThermalPrinter.printBytes(bytes);
      if (!mounted) return;
      err != null
          ? Toast.error(context, err)
          : Toast.success(context, 'Struk terkirim ke printer');
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal cetak struk thermal');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final d = _data;
    final done = _done;
    return AlertDialog(
      title: Text(done != null
          ? lang.get('Refund recorded', 'Refund tercatat')
          : 'Refund'),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading || d == null
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()))
            : done != null
                ? _doneBody(lang, done)
                : d.lines.every((l) => l.remaining == 0)
                    ? Text(lang.get(
                        'All items of this sale have already been refunded.',
                        'Semua barang di nota ini sudah di-refund.'))
                    : _formBody(lang, d),
      ),
      actions: done != null
          ? [
              if (_printing)
                const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))
              else
                PopupMenuButton<String>(
                  tooltip: lang.get('Print receipt', 'Cetak struk'),
                  onSelected: (v) => v == 'pdf' ? _printPdf() : _printThermal(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.print_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text(lang.get('Print receipt', 'Cetak struk')),
                    ]),
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'pdf', child: Text(lang.get('Print PDF', 'Cetak PDF'))),
                    PopupMenuItem(
                        value: 'thermal',
                        child: Text(lang.get('Print thermal (Bluetooth)', 'Cetak Thermal (Bluetooth)'))),
                  ],
                ),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(lang.get('Done', 'Selesai'))),
            ]
          : [
              TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text(lang.get('Cancel', 'Batal'))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.warningDark),
                onPressed: (_saving || !_anySelected || d == null) ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(lang.get('Process refund', 'Proses refund')),
              ),
            ],
    );
  }

  Widget _doneBody(LanguageProvider lang, RefundDetail done) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${done.header.refundNumber} – ${TextFormatter.formatRupiah(done.header.total)} (${refundMethodLabel(done.header.method)})',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final l in done.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('${l.qty} × ${l.stockName}')),
                  Text(TextFormatter.formatRupiah(l.amount)),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Text(
              lang.get('Give the customer the money back and hand over the refund receipt.',
                  'Kembalikan uang ke pelanggan dan berikan struk refund.'),
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _formBody(LanguageProvider lang, Refundable d) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              '${lang.get('Sale', 'Nota')} ${d.saleNumber} · Total ${TextFormatter.formatRupiah(d.saleTotal)}'
              '${d.refundedTotal > 0 ? ' · ${lang.get('Already refunded', 'Sudah di-refund')} ${TextFormatter.formatRupiah(d.refundedTotal)}' : ''}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const SizedBox(height: 10),
          for (final l in d.lines) _lineRow(lang, l),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: InputDecoration(
                labelText: lang.get('Money returned via', 'Uang dikembalikan lewat'),
                helperMaxLines: 2,
                helperText: _method == 'TUNAI'
                    ? lang.get('Cash: taken from the cash drawer and recorded in Cash History.',
                        'Tunai: diambil dari laci kas dan tercatat di Kas History.')
                    : lang.get('Not cash: the drawer cash is not reduced; transfer the money to the customer.',
                        'Non-tunai: kas laci tidak berkurang; kirim uangnya ke pelanggan lewat transfer.')),
            items: refundMethods
                .map((m) => DropdownMenuItem(value: m, child: Text(refundMethodLabel(m))))
                .toList(),
            onChanged: (v) => setState(() => _method = v ?? 'TUNAI'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLength: 255,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
                labelText: lang.get('Reason (required)', 'Alasan refund (wajib)')),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total refund',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(TextFormatter.formatRupiah(_total),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lineRow(LanguageProvider lang, RefundableLine l) {
    final q = _qty[l.tdId] ?? 0;
    return Opacity(
      opacity: l.remaining == 0 ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.stockName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                          '${TextFormatter.formatRupiah(l.unitRefund)} / ${lang.get('unit', 'satuan')} · ${lang.get('bought', 'dibeli')} ${l.qty}'
                          '${l.refundedQty > 0 ? ', ${lang.get('refunded', 'sudah refund')} ${l.refundedQty}' : ''}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_rounded),
                  onPressed: l.remaining == 0 || q <= 0
                      ? null
                      : () => setState(() => _qty[l.tdId] = q - 1),
                ),
                Text('$q', style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_rounded),
                  onPressed: l.remaining == 0 || q >= l.remaining
                      ? null
                      : () => setState(() => _qty[l.tdId] = q + 1),
                ),
              ],
            ),
            if (q > 0)
              InkWell(
                onTap: () => setState(
                    () => _restock[l.tdId] = !(_restock[l.tdId] ?? true)),
                child: Row(
                  children: [
                    Checkbox(
                      value: _restock[l.tdId] ?? true,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) =>
                          setState(() => _restock[l.tdId] = v ?? true),
                    ),
                    Text(lang.get('Return to stock', 'Kembalikan ke stok'),
                        style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
