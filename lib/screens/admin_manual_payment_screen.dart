import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/manual_pay_model.dart';
import '../services/manual_pay_api.dart';
import '../utils/subscription_state.dart' show formatRupiah;
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

/// ADMIN: konfirmasi pembayaran langganan lewat transfer bank (2026-11-18). Setujui HANYA setelah uang terlihat di
/// mutasi rekening dengan kode OKJ-xxxxxx yang sama. Padanan web: pages/admin-konfirmasi-pembayaran.
class AdminManualPaymentScreen extends StatefulWidget {
  const AdminManualPaymentScreen({super.key});

  @override
  State<AdminManualPaymentScreen> createState() => _AdminManualPaymentScreenState();
}

class _AdminManualPaymentScreenState extends State<AdminManualPaymentScreen> {
  final _api = ManualPayApi();
  String _status = 'PENDING';
  bool _loading = true;
  List<PayRequest> _rows = [];

  static const _labels = {
    'PENDING': ('Menunggu', Colors.orange),
    'APPROVED': ('Disetujui', Colors.green),
    'REJECTED': ('Ditolak', Colors.red),
    'CANCELLED': ('Dibatalkan', Colors.grey),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.adminList(_status == 'ALL' ? '' : _status);
      if (!mounted) return;
      if (r.statusCode == 200) {
        final list = ((jsonDecode(r.body) as Map)['data'] as List?) ?? [];
        setState(() => _rows = list.map((e) => PayRequest.fromJson((e as Map).cast<String, dynamic>())).toList());
      } else {
        Toast.error(context, _err(r.body, 'Gagal memuat permintaan pembayaran'));
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memuat permintaan pembayaran. Periksa koneksi internet Anda.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _err(String body, String fallback) {
    try {
      final e = (jsonDecode(body) as Map)['error'];
      if (e is String && e.isNotEmpty) return e;
    } catch (_) {}
    return fallback;
  }

  String _fmt(DateTime? t) {
    if (t == null) return '-';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}.${two(t.minute)}';
  }

  Future<void> _act(PayRequest r, bool approve) async {
    final refC = TextEditingController();
    final noteC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(approve ? 'Setujui ${r.reference}' : 'Tolak ${r.reference}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (approve) ...[
                Text('Pastikan transfer ${formatRupiah(r.amount.round())} dengan berita ${r.reference} sudah terlihat di '
                    'mutasi rekening. Paket langsung aktif (${r.yearly ? 365 : 30} hari).'),
                const SizedBox(height: 12),
                TextField(
                  controller: refC,
                  maxLength: 100,
                  onChanged: (_) => setD(() {}),
                  decoration: const InputDecoration(labelText: 'Bukti / keterangan mutasi (wajib)'),
                ),
                TextField(
                  controller: noteC,
                  maxLength: 255,
                  decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
                ),
              ] else
                TextField(
                  controller: noteC,
                  maxLength: 255,
                  onChanged: (_) => setD(() {}),
                  decoration: const InputDecoration(labelText: 'Alasan penolakan (dilihat pemilik)'),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              onPressed: (approve ? refC.text.trim().isEmpty : noteC.text.trim().isEmpty)
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: Text(approve ? 'Setujui' : 'Tolak'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final res = approve
          ? await _api.approve(r.id, refC.text.trim(), noteC.text.trim())
          : await _api.reject(r.id, noteC.text.trim());
      if (!mounted) return;
      if (res.statusCode == 200) {
        Toast.success(context, approve ? 'Disetujui, langganan aktif' : 'Permintaan ditolak');
        await _load();
      } else {
        Toast.error(context, _err(res.body, 'Gagal menyimpan'));
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal menyimpan. Periksa koneksi internet Anda.');
    }
  }

  Widget _card(PayRequest r) {
    final (label, color) = _labels[r.status] ?? ('-', Colors.grey);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(r.reference, style: const TextStyle(fontWeight: FontWeight.w800))),
            Chip(
              label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
              backgroundColor: color.withValues(alpha: 0.12),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            ),
          ]),
          Text('${r.ownerName.isEmpty ? '-' : r.ownerName} · ${r.ownerEmail.isEmpty ? '-' : r.ownerEmail}'
              '${r.ownerShop.isNotEmpty ? ' · ${r.ownerShop}' : ''}'),
          Text('Paket ${r.plan} ${r.yearly ? 'tahunan' : 'bulanan'} · ${formatRupiah(r.amount.round())}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            'Dibuat ${_fmt(r.createdAt)}'
            '${r.decidedAt != null ? ' · diputuskan ${_fmt(r.decidedAt)} oleh ${r.decidedBy}' : ''}'
            '${r.periodEnd != null ? ' · aktif sampai ${_fmt(r.periodEnd)}' : ''}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          if (r.bankRef.isNotEmpty || r.adminNote.isNotEmpty)
            Text(
              '${r.bankRef.isNotEmpty ? 'Bukti: ${r.bankRef}. ' : ''}${r.adminNote.isNotEmpty ? 'Catatan: ${r.adminNote}' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          if (r.status == 'PENDING') ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              ElevatedButton(onPressed: () => _act(r, true), child: const Text('Uang sudah masuk, setujui')),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => _act(r, false),
                child: const Text('Tolak'),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Konfirmasi Pembayaran'),
        drawer: const AppDrawer(),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Langganan yang dibayar lewat transfer bank'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final (v, l) in const [('PENDING', 'Menunggu'), ('APPROVED', 'Disetujui'), ('REJECTED', 'Ditolak'), ('ALL', 'Semua')])
                  ChoiceChip(
                    label: Text(l),
                    selected: _status == v,
                    onSelected: (_) {
                      setState(() => _status = v);
                      _load();
                    },
                  ),
              ]),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
              else if (_rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Tidak ada permintaan', textAlign: TextAlign.center)),
                )
              else
                ..._rows.map(_card),
            ],
          ),
        ),
      ),
    );
  }
}
