import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/order_model.dart';
import '../services/order_api.dart';
import '../utils/text_formatter.dart';
import '../widgets/app_drawer.dart';
import '../widgets/private_route.dart';

/// Dashboard pembeli: daftar pesanan yang sudah dibuat, lengkap dengan
/// metode pembayaran dan status. Tombol "Detail" membuka rincian barang.
class BuyerOrdersScreen extends StatefulWidget {
  const BuyerOrdersScreen({super.key});

  @override
  State<BuyerOrdersScreen> createState() => _BuyerOrdersScreenState();
}

class _BuyerOrdersScreenState extends State<BuyerOrdersScreen> {
  final _orderApi = OrderApi();
  List<BuyerOrder> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _orderApi.getBuyerOrders();
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

  @override
  Widget build(BuildContext context) {
    return PrivateRoute(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Pesanan Saya'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _orders.isEmpty
                ? Center(
                    child: Text('Belum ada pesanan',
                        style: TextStyle(color: Colors.grey[600])))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final o = _orders[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(o.orderOutletName.toUpperCase(),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _statusColor(o.orderStatus)
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        orderStatusLabel(o.orderStatus),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: _statusColor(o.orderStatus),
                                            fontWeight: FontWeight.bold),
                                      ),
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
                                      color: Colors.grey[700],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${o.orderPayType} • ${o.isPaid ? "LUNAS" : "BELUM LUNAS"}',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey[700]),
                                    ),
                                    const Spacer(),
                                    Text(
                                      TextFormatter.formatRupiah(o.orderTotal),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                if (o.orderStatus == 'REJECT' &&
                                    (o.orderRejectReason ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('Alasan: ${o.orderRejectReason}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.red)),
                                ],
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.list_alt, size: 18),
                                    label: const Text('Detail'),
                                    onPressed: () => Navigator.pushNamed(
                                        context, '/pesanan-detail',
                                        arguments: o.orderId),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
