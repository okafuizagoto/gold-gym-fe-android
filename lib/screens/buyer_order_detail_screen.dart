import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/order_model.dart';
import '../services/order_api.dart';
import '../utils/text_formatter.dart';
import '../widgets/private_route.dart';

/// Rincian satu pesanan pembeli: daftar barang + status pesanan
/// (menunggu konfirmasi penjual / sedang diproses / selesai / ditolak).
class BuyerOrderDetailScreen extends StatefulWidget {
  const BuyerOrderDetailScreen({super.key});

  @override
  State<BuyerOrderDetailScreen> createState() => _BuyerOrderDetailScreenState();
}

class _BuyerOrderDetailScreenState extends State<BuyerOrderDetailScreen> {
  final _orderApi = OrderApi();
  BuyerOrderWithDetail? _data;
  bool _loading = true;
  String _orderId = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args != _orderId) {
      _orderId = args;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _orderApi.getOrderDetail(_orderId);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        _data = BuyerOrderWithDetail.fromJson(body['data'] ?? {});
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

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Detail Pesanan')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _data == null
                ? Center(
                    child: Text('Pesanan tidak ditemukan',
                        style: TextStyle(color: Colors.grey[600])))
                : _content(_data!),
      ),
    );
  }

  Widget _content(BuyerOrderWithDetail d) {
    final h = d.header;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // status besar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _statusColor(h.orderStatus).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(
                h.orderStatus == 'FINISH'
                    ? Icons.check_circle
                    : h.orderStatus == 'REJECT'
                        ? Icons.cancel
                        : Icons.hourglass_top,
                color: _statusColor(h.orderStatus),
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                orderStatusLabel(h.orderStatus),
                style: TextStyle(
                    color: _statusColor(h.orderStatus),
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              if (h.orderStatus == 'REJECT' &&
                  (h.orderRejectReason ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Alasan: ${h.orderRejectReason}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Outlet : ${h.orderOutletName}'),
                Text('Pembayaran : ${h.orderPayType}'),
                Text('Status bayar : ${h.isPaid ? "LUNAS" : "BELUM LUNAS"}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Barang dipesan',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        ...d.detail.map((item) => Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                title: Text(item.stockName),
                subtitle: Text(
                    '${item.qty} x ${TextFormatter.formatRupiah(item.price)}'),
                trailing: Text(TextFormatter.formatRupiah(item.total),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            )),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(TextFormatter.formatRupiah(h.orderTotal),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ],
    );
  }
}
