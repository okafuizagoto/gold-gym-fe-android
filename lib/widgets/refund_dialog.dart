import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/refund_model.dart';
import '../models/stock_model.dart';
import '../providers/language_provider.dart';
import '../services/refund_api.dart';
import '../services/stock_api.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../services/thermal_printer.dart';
import '../utils/refund_escpos.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';

/// Refund (Tahap 1: kembalikan barang + uang; Tahap 2: TUKAR BARANG), padanan components/RefundDialog.tsx di web:
/// pilih barang dan jumlah yang dikembalikan, lalu uang dikembalikan ATAU barang pengganti dari produk terdaftar di
/// outlet (selisih harga dibayar pelanggan atau dikembalikan), metode, dan alasan. Nilai per barang sudah memperhitungkan diskon/voucher
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
  // Tukar barang
  bool _exchange = false;
  final Map<String, StockResponse> _replStock = {};
  final Map<String, int> _replQty = {};
  final _search = TextEditingController();
  List<StockResponse> _results = [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
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

  double get _replTotal => _replQty.entries
      .fold<double>(0, (s, e) => s + e.value * (_replStock[e.key]?.stock_price ?? 0));

  /// + pelanggan bayar tambahan, - dikembalikan ke pelanggan.
  double get _net => _replTotal - _total;

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(q.trim()));
  }

  Future<void> _runSearch(String q) async {
    if (!mounted) return;
    setState(() => _searching = true);
    try {
      final oc = await Storage.get(AppConstants.outcode) ?? '';
      final resp = await StockApi().getAllStock(q, oc, 1, 12);
      if (resp.statusCode == 200 && mounted) {
        final list = (jsonDecode(resp.body)['data'] ?? []) as List;
        setState(() => _results = list
            .map((e) => StockResponse.fromJson(Map<String, dynamic>.from(e)))
            .toList());
      }
    } catch (_) {
      /* hasil terakhir dipertahankan */
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _addRepl(StockResponse s) {
    final cur = _replQty[s.stock_id] ?? 0;
    final max = s.isTherapy ? 999 : s.stock_qty;
    if (cur >= max) {
      Toast.error(context, 'Stok tidak cukup');
      return;
    }
    setState(() {
      _replStock[s.stock_id] = s;
      _replQty[s.stock_id] = cur + 1;
    });
  }

  void _stepRepl(String id, int delta) {
    final cur = _replQty[id] ?? 0;
    final q = cur + delta;
    final s = _replStock[id];
    if (s == null) return;
    if (q <= 0) {
      setState(() {
        _replQty.remove(id);
        _replStock.remove(id);
      });
      return;
    }
    if (q > (s.isTherapy ? 999 : s.stock_qty)) return;
    setState(() => _replQty[id] = q);
  }

  bool get _anySelected =>
      _data != null && _data!.lines.any((l) => (_qty[l.tdId] ?? 0) > 0);

  Future<void> _submit() async {
    final lang = context.read<LanguageProvider>();
    if (_data == null || !_anySelected) return;
    if (_reason.text.trim().isEmpty) {
      Toast.error(context, lang.get('Reason is required', 'Alasan wajib diisi'));
      return;
    }
    if (_exchange && _replQty.isEmpty) {
      Toast.error(context, lang.get('Pick at least one replacement item', 'Pilih minimal satu barang pengganti'));
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
        method: _exchange && _net.round() == 0 ? '' : _method,
        reason: _reason.text.trim(),
        mode: _exchange ? 'EXCHANGE' : 'MONEY_BACK',
        exchangeItems: _exchange
            ? _replQty.entries.map((e) => {'stock_id': e.key, 'qty': e.value}).toList()
            : null,
      );
      if (!mounted) return;
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        setState(() =>
            _done = RefundDetail.fromJson(jsonDecode(resp.body)['data']));
        Toast.success(context, _exchange ? lang.get('Exchange recorded', 'Tukar barang tercatat') : lang.get('Refund recorded', 'Refund tercatat'));
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
          ? (done.header.isExchange
              ? lang.get('Exchange recorded', 'Tukar barang tercatat')
              : lang.get('Refund recorded', 'Refund tercatat'))
          : (_exchange ? lang.get('Exchange items', 'Tukar barang') : 'Refund')),
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
                    : Text(_exchange
                        ? lang.get('Process exchange', 'Proses tukar barang')
                        : lang.get('Process refund', 'Proses refund')),
              ),
            ],
    );
  }

  Widget _doneBody(LanguageProvider lang, RefundDetail done) {
    Widget row(String left, double amount) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(left)),
              Text(TextFormatter.formatRupiah(amount)),
            ],
          ),
        );
    final h = done.header;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              h.isExchange
                  ? '${lang.get('Exchange', 'Tukar barang')} ${h.refundNumber}'
                  : '${h.refundNumber} – ${TextFormatter.formatRupiah(h.total)} (${refundMethodLabel(h.method)})',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (h.isExchange)
            Text(lang.get('Returned', 'Dikembalikan'),
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          for (final l in done.lines) row('${l.qty} × ${l.stockName}', l.amount),
          if (h.isExchange) ...[
            const SizedBox(height: 6),
            Text(lang.get('Replacement', 'Pengganti'),
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            for (final l in done.newLines) row('${l.qty} × ${l.stockName}', l.amount),
            const SizedBox(height: 8),
            Text(
                h.net > 0
                    ? '${lang.get('Customer pays', 'Pelanggan membayar')} ${TextFormatter.formatRupiah(h.net)} (${refundMethodLabel(h.netMethod)})'
                    : h.net < 0
                        ? '${lang.get('Give back to the customer', 'Kembalikan ke pelanggan')} ${TextFormatter.formatRupiah(-h.net)} (${refundMethodLabel(h.netMethod)})'
                        : lang.get('Even exchange: no money changes hands.', 'Tukar sama nilai: tidak ada uang yang berpindah.'),
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ] else ...[
            const SizedBox(height: 10),
            Text(
                lang.get('Give the customer the money back and hand over the refund receipt.',
                    'Kembalikan uang ke pelanggan dan berikan struk refund.'),
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ],
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
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text(lang.get('Return money', 'Kembalikan uang'))),
              ButtonSegment(value: true, label: Text(lang.get('Exchange items', 'Tukar barang'))),
            ],
            selected: {_exchange},
            onSelectionChanged: (v) => setState(() => _exchange = v.first),
          ),
          const SizedBox(height: 10),
          for (final l in d.lines) _lineRow(lang, l),
          if (_exchange) _exchangePanel(lang),
          const SizedBox(height: 10),
          if (!_exchange || _net.round() != 0)
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: InputDecoration(
                  labelText: _exchange
                      ? (_net > 0
                          ? lang.get('Customer pays the difference via', 'Selisih dibayar pelanggan lewat')
                          : lang.get('Difference returned via', 'Selisih dikembalikan lewat'))
                      : lang.get('Money returned via', 'Uang dikembalikan lewat'),
                  helperMaxLines: 2,
                  helperText: _method == 'TUNAI'
                      ? (_exchange && _net > 0
                          ? lang.get('Cash: goes into the cash drawer and is recorded in Cash History.',
                              'Tunai: masuk ke laci kas dan tercatat di Kas History.')
                          : lang.get('Cash: taken from the cash drawer and recorded in Cash History.',
                              'Tunai: diambil dari laci kas dan tercatat di Kas History.'))
                      : lang.get('Not cash: the drawer cash is not changed; settle by transfer.',
                          'Non-tunai: kas laci tidak berubah; selesaikan lewat transfer.')),
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
                labelText: _exchange
                    ? lang.get('Reason for the exchange (required)', 'Alasan tukar barang (wajib)')
                    : lang.get('Reason (required)', 'Alasan refund (wajib)')),
          ),
          const SizedBox(height: 4),
          if (_exchange) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(lang.get('Returned value', 'Nilai dikembalikan')),
                Text(TextFormatter.formatRupiah(_total)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(lang.get('Replacement value', 'Nilai pengganti')),
                Text(TextFormatter.formatRupiah(_replTotal)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    _net.round() > 0
                        ? lang.get('Customer pays', 'Pelanggan membayar')
                        : _net.round() < 0
                            ? lang.get('Give back to customer', 'Kembalikan ke pelanggan')
                            : lang.get('Even exchange', 'Tukar sama nilai'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(TextFormatter.formatRupiah(_net.abs()),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: _net > 0
                            ? Colors.green.shade700
                            : _net < 0
                                ? Colors.red.shade700
                                : null)),
              ],
            ),
          ] else
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

  Widget _exchangePanel(LanguageProvider lang) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.warningDark),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.get('Replacement items', 'Barang pengganti'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: _search,
            onChanged: _onSearch,
            decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: lang.get('Search a registered product', 'Cari produk terdaftar')),
          ),
          if (_searching)
            const Padding(
                padding: EdgeInsets.all(6),
                child: SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final s in _results)
                  Opacity(
                    opacity: (!s.isTherapy && s.stock_qty <= 0) ? 0.5 : 1,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.stock_name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${TextFormatter.formatRupiah(s.stock_price.toDouble())} · ${s.isTherapy ? lang.get('service', 'jasa') : '${lang.get('stock', 'stok')} ${s.stock_qty}'}'),
                      trailing: TextButton(
                          onPressed: (!s.isTherapy && s.stock_qty <= 0) ? null : () => _addRepl(s),
                          child: Text(lang.get('Add', 'Tambah'))),
                    ),
                  ),
              ],
            ),
          ),
          for (final e in _replQty.entries)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_replStock[e.key]?.stock_name ?? e.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                          '${TextFormatter.formatRupiah((_replStock[e.key]?.stock_price ?? 0).toDouble())} × ${e.value} = ${TextFormatter.formatRupiah((_replStock[e.key]?.stock_price ?? 0) * e.value.toDouble())}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(e.value == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded),
                    onPressed: () => _stepRepl(e.key, -1)),
                Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => _stepRepl(e.key, 1)),
              ],
            ),
          Text(
              lang.get(
                  "Replacement items are priced at today's selling price (no discount) and their stock is reduced.",
                  'Barang pengganti memakai harga jual hari ini (tanpa diskon) dan stoknya dikurangi.'),
              style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
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
