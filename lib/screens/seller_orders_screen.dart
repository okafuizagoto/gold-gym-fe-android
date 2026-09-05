import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/order_model.dart';
import '../services/order_api.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

/// Menu penjual: menampung pesanan masuk dari pembeli.
/// - Pesanan WAITING: tombol "Konfirmasi" → modal terima / tolak (tolak wajib
///   beri alasan). Setelah dikonfirmasi, tombol berubah jadi "Selesai Proses".
/// - Pesanan PROCESS: tombol "Selesai Proses" → modal konfirmasi → status FINISH
///   (nota dibuat & masuk Sales History). Outlet THERAPY tidak memakai menu ini.
class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  final _orderApi = OrderApi();
  List<BuyerOrder> _orders = [];
  bool _loading = true;
  String _busyId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _orderApi.getSellerOrders('');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        _orders = ((body['data'] ?? []) as List)
            .map((e) => BuyerOrder.fromJson(e))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'WAITING':
        return Colors.orange;
      case 'PROCESS':
        return Colors.blue;
      case 'FINISH':
        return Colors.green;
      case 'REJECT':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _confirmDialog(BuyerOrder o) async {
    final reasonController = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi Pesanan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Terima pesanan dari ${o.orderBuyerName}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Alasan penolakan (isi jika menolak)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                Toast.error(dialogContext, 'Isi alasan penolakan dulu');
                return;
              }
              Navigator.pop(dialogContext);
              await _reject(o, reason);
            },
            child: const Text('Tolak', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _confirm(o);
            },
            child: const Text('Terima'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(BuyerOrder o) async {
    setState(() => _busyId = o.orderId);
    try {
      final r = await _orderApi.confirmOrder(o.orderId);
      _handleResult(r, 'Pesanan dikonfirmasi');
    } catch (e) {
      Toast.error(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _busyId = '');
    }
  }

  Future<void> _reject(BuyerOrder o, String reason) async {
    setState(() => _busyId = o.orderId);
    try {
      final r = await _orderApi.rejectOrder(o.orderId, reason);
      _handleResult(r, 'Pesanan ditolak');
    } catch (e) {
      Toast.error(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _busyId = '');
    }
  }

  Future<void> _finishDialog(BuyerOrder o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Selesaikan Pesanan'),
        content: const Text(
            'Yakin pesanan sudah selesai diproses? Nota akan dibuat dan '
            'pesanan masuk Sales History.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ya, Selesai'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busyId = o.orderId);
    try {
      final r = await _orderApi.finishOrder(o.orderId);
      _handleResult(r, 'Pesanan selesai, nota dibuat');
    } catch (e) {
      Toast.error(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _busyId = '');
    }
  }

  void _handleResult(response, String successMsg) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      Toast.success(context, successMsg);
      _load();
      return;
    }
    String msg = 'Gagal memproses pesanan';
    try {
      msg = jsonDecode(response.body)['error'] ?? msg;
    } catch (_) {}
    Toast.error(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Pesanan Masuk'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _orders.isEmpty
                ? Center(
                    child: Text('Belum ada pesanan masuk',
                        style: TextStyle(color: Colors.grey[600])))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: _orders.length,
                      itemBuilder: (context, index) =>
                          _orderCard(_orders[index]),
                    ),
                  ),
      ),
    );
  }

  Widget _orderCard(BuyerOrder o) {
    final busy = _busyId == o.orderId;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    o.orderBuyerName.isEmpty
                        ? 'Pembeli'
                        : o.orderBuyerName.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(o.orderStatus).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(orderStatusLabel(o.orderStatus),
                      style: TextStyle(
                          fontSize: 11,
                          color: _statusColor(o.orderStatus),
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                    o.orderPayType == 'TRANSFER'
                        ? Icons.account_balance
                        : Icons.payments,
                    size: 16,
                    color: Colors.grey[700]),
                const SizedBox(width: 6),
                Text('${o.orderPayType} • ${o.isPaid ? "LUNAS" : "BELUM LUNAS"}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                const Spacer(),
                Text(TextFormatter.formatRupiah(o.orderTotal),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text('Detail'),
                  onPressed: () => Navigator.pushNamed(
                      context, '/pesanan-detail',
                      arguments: o.orderId),
                ),
                const Spacer(),
                if (busy)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else if (o.orderStatus == 'WAITING')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.fact_check, size: 18),
                    label: const Text('Konfirmasi'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white),
                    onPressed: () => _confirmDialog(o),
                  )
                else if (o.orderStatus == 'PROCESS')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Selesai Proses'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                    onPressed: () => _finishDialog(o),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
