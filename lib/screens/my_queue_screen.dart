import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pos_queue_model.dart';
import '../services/pos_queue_api.dart';
import '../providers/language_provider.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';

/// Antrian milik pembeli sendiri (transaksi POS yang ditautkan ke akun ini) -- lihat nomor & status.
class MyQueueScreen extends StatefulWidget {
  const MyQueueScreen({super.key});

  @override
  State<MyQueueScreen> createState() => _MyQueueScreenState();
}

class _MyQueueScreenState extends State<MyQueueScreen> {
  final _api = PosQueueApi();
  List<QueueRow> _rows = [];
  bool _loading = true;
  bool _forbidden = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final response = await _api.mine();
      if (response.statusCode == 200 && mounted) {
        final body = jsonDecode(response.body);
        final list = (body['data'] ?? []) as List;
        setState(() => _rows = list.map((e) => QueueRow.fromJson(e)).toList());
      } else if (response.statusCode == 403 && mounted) {
        setState(() => _forbidden = true);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
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
      child: Consumer<LanguageProvider>(
        builder: (context, lang, child) {
          String statusLabel(String s) => s == QueueStatus.menunggu
              ? lang.get('WAITING', 'MENUNGGU')
              : s == QueueStatus.diproses
                  ? lang.get('IN PROGRESS', 'DIPROSES')
                  : lang.get('DONE', 'SELESAI');

          return Scaffold(
            appBar: AppBarCustom(title: lang.get('My Queue', 'Antrian Saya')),
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : _forbidden
                    ? EmptyState(title: lang.get('Buyer accounts only', 'Hanya untuk akun pembeli'), description: '')
                    : _rows.isEmpty
                        ? EmptyState(
                            title: lang.get('No queue entries', 'Belum ada antrian'),
                            description: lang.get(
                                'Appears here when a cashier links your account to a transaction at an outlet with queue enabled.',
                                'Muncul di sini kalau kasir menautkan akun Anda ke transaksi di outlet yang mengaktifkan antrian.'))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                              itemCount: _rows.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final row = _rows[i];
                                return Card(
                                  child: ListTile(
                                    title: Text('${row.queueNumber}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26)),
                                    subtitle: Text(
                                        '${row.queueOutcode} · ${row.queueCreatedAt.toLocal()}'),
                                    trailing: Chip(
                                      label: Text(statusLabel(row.queueStatus)),
                                      backgroundColor:
                                          _statusColor(row.queueStatus).withValues(alpha: 0.15),
                                      labelStyle: TextStyle(color: _statusColor(row.queueStatus)),
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
