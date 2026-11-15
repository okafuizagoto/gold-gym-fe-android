import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/language_provider.dart';
import '../services/data_export_api.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

/// Ekspor Data (2026-11-16) -- padanan pages/ekspor-data/index.tsx. Unduh CSV mentah milik usaha: barang, stok,
/// transaksi. Setiap ekspor tercatat (siapa, kapan, jenis, jumlah baris); layar menampilkan kapan terakhir
/// diekspor dan data terbaru sekarang. Penjual selalu boleh (bila paket berhak); staf bila diizinkan penjual.
class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  final _api = DataExportApi();
  bool _loading = true;
  bool _isSeller = true;
  bool _allowed = false;
  String _error = '';
  String _denied = '';
  int _maxRange = 366;
  String? _busy;
  List<Map<String, dynamic>> _kinds = [];
  List<Map<String, dynamic>> _logs = [];
  DateTime _to = DateTime.now();
  late DateTime _from = DateTime.now().subtract(const Duration(days: 89));

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    Storage.get(AppConstants.userRoleKey).then((r) {
      if (mounted) {
        setState(() => _isSeller = (r ?? AppConstants.roleSeller) == AppConstants.roleSeller);
      }
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final outcode = await Storage.get(AppConstants.outcode) ?? '';
      final r = await _api.overview(outcode);
      if (!mounted) return;
      if (r.statusCode != 200) {
        String msg = 'Gagal memuat';
        try {
          msg = jsonDecode(r.body)['error'] ?? msg;
        } catch (_) {}
        setState(() {
          _error = msg;
          _allowed = false;
        });
        return;
      }
      final d = jsonDecode(r.body)['data'] as Map<String, dynamic>;
      _allowed = d['allowed'] == true;
      _denied = (d['denied_reason'] ?? '').toString();
      _maxRange = (d['max_range_days'] as num?)?.toInt() ?? 366;
      _kinds = ((d['kinds'] ?? []) as List).cast<Map<String, dynamic>>();
      _error = '';
      if (_isSeller && _allowed) {
        final h = await _api.history();
        if (h.statusCode == 200) {
          _logs = ((jsonDecode(h.body)['data'] ?? []) as List).cast<Map<String, dynamic>>();
        }
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(dynamic iso) {
    if (iso is! String || iso.isEmpty || iso.startsWith('0001')) return '-';
    final d = DateTime.tryParse(iso)?.toLocal();
    return d == null ? '-' : DateFormat('d MMM yyyy HH:mm', 'id_ID').format(d);
  }

  String _label(String kind) =>
      kind == 'ITEMS' ? 'Barang' : (kind == 'STOCK' ? 'Stok' : 'Transaksi');

  Future<void> _pickDate(bool from) async {
    final p = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (p != null) setState(() => from ? _from = p : _to = p);
  }

  Future<void> _run(String kind) async {
    setState(() => _busy = kind);
    try {
      final outcode = await Storage.get(AppConstants.outcode) ?? '';
      final path = kind == 'ITEMS' ? 'items' : (kind == 'STOCK' ? 'stock' : 'transactions');
      final r = await _api.download(path, outcode: outcode, from: _ymd(_from), to: _ymd(_to));
      if (r.statusCode != 200) {
        String msg = 'Ekspor gagal';
        try {
          msg = jsonDecode(utf8.decode(r.bodyBytes))['error'] ?? msg;
        } catch (_) {}
        if (mounted) Toast.error(context, msg);
        return;
      }
      final dir = await getTemporaryDirectory();
      final name = RegExp(r'filename="([^"]+)"').firstMatch(r.headers['content-disposition'] ?? '')?.group(1) ??
          'okejual-$path.csv';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(r.bodyBytes);
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], text: 'Ekspor data Okejual: ${_label(kind)}');
      if (mounted) Toast.success(context, '${r.headers['x-export-rows'] ?? '0'} baris diekspor');
      await _load();
    } catch (_) {
      if (mounted) Toast.error(context, 'Ekspor gagal');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Widget _card(Map<String, dynamic> k, LanguageProvider lang) {
    final kind = k['kind'] as String;
    final isNew = k['new_since_last_export'] == true;
    final last = k['last_export_at'];
    final hasLast = last is String && last.isNotEmpty && !last.startsWith('0001');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(_label(kind), style: Theme.of(context).textTheme.titleMedium)),
                Chip(
                  label: Text(isNew ? (hasLast ? 'Ada data baru' : 'Belum pernah diekspor') : 'Sudah terekspor',
                      style: const TextStyle(fontSize: 12)),
                  backgroundColor: isNew ? Colors.orange.shade100 : Colors.green.shade100,
                ),
              ],
            ),
            Text('Jumlah data sekarang: ${k['rows_now']} · Data terbaru: ${_fmt(k['data_latest_at'])}',
                style: const TextStyle(fontSize: 13)),
            Text(
                'Terakhir diekspor: ${_fmt(last)}${hasLast ? ' oleh ${k['last_export_by'] ?? '-'} (${k['last_export_role'] == 'STAFF' ? 'staf' : 'pemilik'}, ${k['last_export_rows']} baris)' : ''}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _busy != null ? null : () => _run(kind),
              icon: _busy == kind
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded),
              label: const Text('Unduh CSV'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final pad = context.pagePadding;
    return PrivateRoute(
      staffMenuKey: '/ekspor-data',
      child: Scaffold(
        appBar: AppBarCustom(title: lang.get('Export Data', 'Ekspor Data')),
        drawer: const AppDrawer(),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.all(pad),
            children: [
              if (_loading)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else if (_error.isNotEmpty)
                Text(_error, style: const TextStyle(color: Colors.red))
              else if (!_allowed)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(_denied.isEmpty ? 'Ekspor tidak tersedia untuk akun ini.' : _denied),
                  ),
                )
              else ...[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                        'Setiap ekspor dicatat: siapa, kapan, data apa, dan berapa baris (isi file tidak disimpan). Stok dan transaksi mengikuti outlet yang aktif.',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(onPressed: () => _pickDate(true), child: Text('Transaksi dari: ${_ymd(_from)}')),
                    OutlinedButton(onPressed: () => _pickDate(false), child: Text('sampai: ${_ymd(_to)}')),
                    Text('Maks $_maxRange hari per ekspor', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final k in _kinds) _card(k, lang),
                if (_isSeller) ...[
                  const SizedBox(height: 12),
                  Text('Riwayat ekspor', style: Theme.of(context).textTheme.titleMedium),
                  if (_logs.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Belum ada ekspor.')),
                  for (final l in _logs)
                    ListTile(
                      dense: true,
                      title: Text(
                          '${_label(l['kind'] as String)} · ${l['row_count']} baris${l['status'] == 'DENIED' ? ' · DITOLAK' : ''}'),
                      subtitle: Text(
                          '${_fmt(l['created_at'])} · ${(l['actor_name'] ?? '').toString().isEmpty ? '#${l['actor_id']}' : l['actor_name']} (${l['actor_role'] == 'STAFF' ? 'staf' : 'pemilik'})'),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
