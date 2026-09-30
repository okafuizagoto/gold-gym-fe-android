import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pos_queue_model.dart';
import '../services/pos_queue_api.dart';
import '../utils/storage.dart';
import '../utils/constants.dart';
import '../utils/toast.dart';
import '../providers/language_provider.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';

/// Papan antrian POS -- penjual/staf lihat & majukan status. Aktif/nonaktifkan dari Daftar Outlet.
class PosQueueScreen extends StatefulWidget {
  const PosQueueScreen({super.key});

  @override
  State<PosQueueScreen> createState() => _PosQueueScreenState();
}

class _PosQueueScreenState extends State<PosQueueScreen> {
  final _api = PosQueueApi();
  List<QueueRow> _rows = [];
  bool _loading = true;
  int? _advancingId;
  String _outcode = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _init();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final outcode = await Storage.get(AppConstants.outcode) ?? '';
    if (!mounted) return;
    setState(() => _outcode = outcode);
    await _load();
  }

  Future<void> _load() async {
    if (_outcode.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final response = await _api.list(_outcode);
      if (response.statusCode == 200 && mounted) {
        final body = jsonDecode(response.body);
        final list = (body['data'] ?? []) as List;
        setState(() =>
            _rows = list.map((e) => QueueRow.fromJson(e)).toList());
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _advance(QueueRow row) async {
    setState(() => _advancingId = row.queueId);
    try {
      final response = await _api.advance(row.queueId);
      if (response.statusCode == 200) {
        await _load();
      } else if (mounted) {
        Toast.error(context, 'Gagal mengubah status');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal. Periksa koneksi internet Anda.');
    } finally {
      if (mounted) setState(() => _advancingId = null);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case QueueStatus.diproses:
        return Colors.blue;
      case QueueStatus.selesai:
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      sellerOnly: true,
      child: Consumer<LanguageProvider>(
        builder: (context, lang, child) {
          String statusLabel(String s) => s == QueueStatus.menunggu
              ? lang.get('WAITING', 'MENUNGGU')
              : s == QueueStatus.diproses
                  ? lang.get('IN PROGRESS', 'DIPROSES')
                  : lang.get('DONE', 'SELESAI');

          return Scaffold(
            appBar: AppBarCustom(title: lang.get('POS Queue', 'Antrian POS')),
            body: _outcode.isEmpty
                ? EmptyState(
                    title: lang.get('No outlet selected', 'Belum ada outlet dipilih'),
                    description: lang.get('Choose an outlet first.', 'Pilih outlet terlebih dahulu.'))
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _rows.isEmpty
                        ? EmptyState(
                            title: lang.get('No queue yet', 'Belum ada antrian'),
                            description: lang.get(
                                'Make sure the queue is active for this outlet, then save a POS transaction.',
                                'Pastikan antrian sudah diaktifkan untuk outlet ini, lalu simpan transaksi di POS.'))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                              itemCount: _rows.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final row = _rows[i];
                                final done = row.queueStatus == QueueStatus.selesai;
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          _statusColor(row.queueStatus).withValues(alpha: 0.15),
                                      child: Text('${row.queueNumber}',
                                          style: TextStyle(
                                              color: _statusColor(row.queueStatus),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                    ),
                                    title: Text('${row.queueNumber}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 18)),
                                    subtitle: Text(
                                        '${row.queueCreatedAt.toLocal().toString().substring(11, 16)} · ${statusLabel(row.queueStatus)}'),
                                    trailing: done
                                        ? null
                                        : FilledButton(
                                            onPressed: _advancingId == row.queueId
                                                ? null
                                                : () => _advance(row),
                                            child: Text(row.queueStatus == QueueStatus.menunggu
                                                ? lang.get('Process', 'Proses')
                                                : lang.get('Finish', 'Selesai')),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ),
          );
        },
      ),
    );
  }
}
