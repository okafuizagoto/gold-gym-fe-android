import 'package:flutter/material.dart';
import '../config/routes.dart';
import '../services/offline/connectivity_monitor.dart';
import '../services/offline/sales_outbox.dart';

/// Banner global (dipasang di MaterialApp.builder): offline / nota menunggu dikirim / nota gagal.
/// Status offline dari ping /gold-gym/v2/ping (lihat ConnectivityMonitor), bukan status jaringan OS.
class OfflineBanner extends StatelessWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  const OfflineBanner({super.key, required this.child, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([ConnectivityMonitor.instance, SalesOutbox.instance]),
      builder: (context, _) {
        final online = ConnectivityMonitor.instance.isOnline;
        final pending = SalesOutbox.instance.pendingCount;
        final failed = SalesOutbox.instance.failedCount;
        String? text;
        Color color = Colors.orange.shade800;
        if (!online) {
          text = pending > 0
              ? 'Anda sedang offline. $pending transaksi tersimpan di perangkat dan dikirim otomatis saat online.'
              : 'Anda sedang offline. Transaksi tetap bisa disimpan dan dikirim otomatis saat online.';
        } else if (failed > 0) {
          text = '$failed transaksi ditolak server. Ketuk untuk melihat.';
          color = Colors.red.shade700;
        } else if (pending > 0) {
          text = SalesOutbox.instance.syncing
              ? 'Mengirim $pending transaksi…'
              : '$pending transaksi menunggu dikirim. Ketuk untuk melihat.';
          color = Colors.blue.shade700;
        }
        return Column(
          children: [
            if (text != null)
              Material(
                color: color,
                child: InkWell(
                  onTap: () => navigatorKey.currentState?.pushNamed(AppRoutes.antreanTransaksi),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(children: [
                        Icon(online ? Icons.sync : Icons.cloud_off, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(text,
                                style: const TextStyle(color: Colors.white, fontSize: 12))),
                      ]),
                    ),
                  ),
                ),
              ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
