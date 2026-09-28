import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/stock_transfer_model.dart';
import '../services/stock_transfer_api.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import 'stock_transfer_list_screen.dart' show transferColor;

/// Detail transfer: aksi kirim/terima/batal/setujui + surat jalan PDF.
/// Padanan pages/transfer-stok/[id].tsx.
class StockTransferDetailScreen extends StatefulWidget {
  final int transferId;
  const StockTransferDetailScreen({super.key, required this.transferId});

  @override
  State<StockTransferDetailScreen> createState() =>
      _StockTransferDetailScreenState();
}

class _StockTransferDetailScreenState extends State<StockTransferDetailScreen> {
  final _api = StockTransferApi();
  StockTransfer? _t;
  TransferPermission? _perm;
  bool _isStaff = false;
  bool _loading = true;
  bool _busy = false;
  String _paper = 'a4';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final role = await Storage.get(AppConstants.userRoleKey) ?? '';
      final t = await _api.get(widget.transferId);
      final p = await _api.myPermission();
      if (mounted) {
        setState(() {
          _isStaff = role == AppConstants.roleStaff;
          _t = t;
          _perm = p;
        });
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memuat transfer');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<dynamic> Function() call, String okMsg) async {
    setState(() => _busy = true);
    try {
      final resp = await call();
      if (resp.statusCode == 200) {
        if (mounted) Toast.success(context, okMsg);
      } else if (resp.statusCode == 202) {
        if (mounted) {
          Toast.success(
              context, 'Permintaan dikirim, menunggu persetujuan pemilik');
        }
      } else {
        String msg = 'Aksi gagal';
        try {
          msg = jsonDecode(resp.body)['error']?.toString() ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
        return;
      }
      await _load();
    } catch (_) {
      if (mounted) Toast.error(context, 'Aksi gagal');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askText(String title, String label,
      {bool required = false, String? info}) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (info != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8), child: Text(info)),
              TextField(
                controller: c,
                autofocus: true,
                maxLength: required ? 100 : 255,
                decoration: InputDecoration(labelText: label),
                onChanged: (_) => setD(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            TextButton(
              onPressed: required && c.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Lanjut'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _receive() async {
    final name = await _askText('Terima barang', 'Nama penerima barang',
        required: true);
    if (name == null) return;
    await _run(() => _api.receive(widget.transferId, name),
        'Transfer diterima, stok outlet bertambah');
  }

  Future<void> _cancel() async {
    final reason = await _askText('Batalkan transfer', 'Alasan (opsional)',
        info: _t?.status == TransferStatus.dikirim
            ? 'Stok outlet pengirim akan dikembalikan.'
            : null);
    if (reason == null) return;
    await _run(
        () => _api.cancel(widget.transferId, reason), 'Transfer dibatalkan');
  }

  Future<void> _pdf(bool share) async {
    setState(() => _busy = true);
    try {
      final bytes = await _api.getPdf(widget.transferId, _paper);
      if (bytes == null) {
        if (mounted) Toast.error(context, 'Gagal membuat surat jalan');
        return;
      }
      if (share) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/surat-jalan-${_t?.number ?? widget.transferId}.pdf');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Surat jalan');
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memproses surat jalan');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 110,
              child: Text(k, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(v)),
        ]),
      );

  String _dt(DateTime? d) => d == null ? '-' : TextFormatter.formatDate(d);

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: AppBarCustom(title: t?.number ?? 'Detail Transfer'),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : t == null
                ? const EmptyState(title: 'Transfer tidak ditemukan')
                : _body(t),
      ),
    );
  }

  Widget _body(StockTransfer t) {
    final send = _isStaff ? (_perm?.sendLevel ?? TransferLevel.none) : TransferLevel.penuh;
    final recv = _isStaff ? (_perm?.receiveLevel ?? TransferLevel.none) : TransferLevel.penuh;
    final waiting = t.pendingAction != null;
    final canSend =
        t.status == TransferStatus.dibuat && send != TransferLevel.none && !waiting;
    final canReceive =
        t.status == TransferStatus.dikirim && recv != TransferLevel.none && !waiting;
    final canCancel = !waiting &&
        ((t.status == TransferStatus.dibuat && send != TransferLevel.none) ||
            (t.status == TransferStatus.dikirim && send == TransferLevel.penuh));
    final total = t.items.fold<int>(0, (a, i) => a + i.qty);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text('${t.fromName} → ${t.toName}',
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                Text(t.status,
                    style: TextStyle(
                        color: transferColor(t.status),
                        fontWeight: FontWeight.w700)),
              ]),
              const Divider(),
              _line('Dibuat', '${_dt(t.createdAt)} oleh ${t.createdByName}'),
              if (t.sentAt != null)
                _line('Dikirim', '${_dt(t.sentAt)} oleh ${t.sentByName ?? '-'}'),
              if (t.receivedAt != null)
                _line('Diterima',
                    '${_dt(t.receivedAt)} (dicatat ${t.receivedByName ?? '-'})'),
              if (t.receiverName != null) _line('Nama penerima', t.receiverName!),
              if (t.cancelledAt != null)
                _line('Dibatalkan',
                    '${_dt(t.cancelledAt)}${t.cancelReason != null && t.cancelReason!.isNotEmpty ? ': ${t.cancelReason}' : ''}'),
              if (t.note.isNotEmpty) _line('Catatan', t.note),
            ]),
          ),
        ),
        if (waiting)
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    '${t.pendingByName ?? 'Staf'} meminta ${t.pendingAction == 'KIRIM' ? 'mengirim' : 'menerima'} transfer ini${_isStaff ? '. Menunggu persetujuan pemilik.' : '.'}'),
                if (!_isStaff)
                  Row(children: [
                    FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() => _api.approve(t.id), 'Disetujui'),
                        child: const Text('Setujui')),
                    const SizedBox(width: 8),
                    OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() => _api.reject(t.id), 'Ditolak'),
                        child: const Text('Tolak')),
                  ]),
              ]),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Barang ($total)',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final i in t.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text(i.name)),
                    Text('${i.qty} ${i.pack}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (canSend)
            FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => _api.send(t.id),
                        'Transfer dikirim, stok pengirim dikurangi'),
                child: Text(send == TransferLevel.persetujuan ? 'Ajukan Kirim' : 'Kirim')),
          if (canReceive)
            FilledButton(
                onPressed: _busy ? null : _receive,
                child: Text(recv == TransferLevel.persetujuan ? 'Ajukan Terima' : 'Terima')),
          if (canCancel)
            OutlinedButton(
                onPressed: _busy ? null : _cancel, child: const Text('Batalkan')),
        ]),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Surat Jalan',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _paper,
                decoration: const InputDecoration(labelText: 'Ukuran kertas'),
                items: [
                  for (final p in TransferPaper.all)
                    DropdownMenuItem(value: p, child: Text(TransferPaper.label(p))),
                ],
                onChanged: (v) => setState(() => _paper = v ?? 'a4'),
              ),
              const SizedBox(height: 8),
              Row(children: [
                OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pdf(false),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Cetak')),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pdf(true),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Bagikan PDF')),
              ]),
            ]),
          ),
        ),
      ],
    );
  }
}
