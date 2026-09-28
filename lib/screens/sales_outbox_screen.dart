import 'package:flutter/material.dart';
import '../services/offline/connectivity_monitor.dart';
import '../services/offline/sales_outbox.dart';
import '../utils/text_formatter.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';

/// Antrean transaksi offline: nota yang belum terkonfirmasi tersimpan di server. Padanan pages/antrean-transaksi.
class SalesOutboxScreen extends StatelessWidget {
  const SalesOutboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final outbox = SalesOutbox.instance;
    return PrivateRoute(
      sellerOnly: true,
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Antrean Transaksi'),
        body: AnimatedBuilder(
          animation: Listenable.merge([outbox, ConnectivityMonitor.instance]),
          builder: (context, _) {
            final items = outbox.items.reversed.toList();
            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                      child: Text(ConnectivityMonitor.instance.isOnline
                          ? 'Online'
                          : 'Offline -- dikirim otomatis saat online')),
                  FilledButton.icon(
                    onPressed: outbox.syncing
                        ? null
                        : () async {
                            await ConnectivityMonitor.instance.checkNow();
                            await outbox.syncAll();
                          },
                    icon: const Icon(Icons.sync),
                    label: const Text('Kirim sekarang'),
                  ),
                ]),
              ),
              Expanded(
                child: items.isEmpty
                    ? const EmptyState(
                        title: 'Tidak ada transaksi menunggu',
                        description: 'Semua transaksi sudah tersimpan di server.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final e = items[i];
                          final failed = e.status == OutboxStatus.failed;
                          return Card(
                            child: ListTile(
                              title: Text(
                                  '${TextFormatter.formatRupiah(e.total.toDouble())} · ${e.itemCount} item'),
                              subtitle: Text(
                                  '${TextFormatter.formatDate(e.createdAt)} · ${e.outcode}\n${failed ? 'Ditolak: ${e.error ?? '-'}' : 'Menunggu dikirim (percobaan ${e.attempts})'}'),
                              isThreeLine: true,
                              leading: Icon(failed ? Icons.error_outline : Icons.schedule,
                                  color: failed ? Colors.red : Colors.orange),
                              trailing: failed
                                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                                      IconButton(
                                          tooltip: 'Coba lagi',
                                          onPressed: () => outbox.retry(e.saleId),
                                          icon: const Icon(Icons.refresh)),
                                      IconButton(
                                          tooltip: 'Buang',
                                          onPressed: () => _confirmDiscard(context, outbox, e),
                                          icon: const Icon(Icons.delete_outline)),
                                    ])
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context, SalesOutbox outbox, OutboxSale e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buang transaksi ini?'),
        content: const Text('Transaksi ini TIDAK akan pernah tersimpan di server. Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buang')),
        ],
      ),
    );
    if (ok == true) await outbox.discard(e.saleId);
  }
}
