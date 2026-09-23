import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/order_model.dart';
import '../services/order_api.dart';
import '../utils/responsive.dart';
import '../utils/text_formatter.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
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

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    // tengahkan daftar di tablet (padanan Container maxWidth di web)
    final sidePad =
        math.max(pad, (context.screenWidth - context.contentMaxWidth) / 2);
    return PrivateRoute(
      child: Scaffold(
        appBar: AppBarCustom(
          title: 'Pesanan Saya',
          actions: [
            IconButton(
                tooltip: 'Muat ulang',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _load),
          ],
        ),
        drawer: const AppDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _orders.isEmpty
                ? PageBody(
                    child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Belum ada pesanan',
                    description:
                        'Pesanan yang Anda buat dari menu Pesan Barang akan tampil di sini.',
                    action: OutlinedButton.icon(
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: const Text('Pesan Barang'),
                      onPressed: () => Navigator.pushNamed(context, '/belanja'),
                    ),
                  ))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(sidePad, pad, sidePad, pad),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final o = _orders[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _OrderCard(
                            order: o,
                            onDetail: () => Navigator.pushNamed(
                                context, '/pesanan-detail',
                                arguments: o.orderId),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final BuyerOrder order;
  final VoidCallback onDetail;

  const _OrderCard({required this.order, required this.onDetail});

  (Color, Color) _statusColors(String status) {
    switch (status) {
      case 'WAITING':
        return (AppColors.warningLight, AppColors.warningDark);
      case 'PROCESS':
        return (AppColors.infoLight, AppColors.infoDark);
      case 'FINISH':
        return (AppColors.successLight, AppColors.successDark);
      case 'REJECT':
        return (AppColors.errorLight, AppColors.errorDark);
      default:
        return (AppColors.chipBg, AppColors.muted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    final textTheme = Theme.of(context).textTheme;
    final (bg, fg) = _statusColors(o.orderStatus);
    return Card(
      child: InkWell(
        onTap: onDetail,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      o.orderOutletName.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      orderStatusLabel(o.orderStatus),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, color: fg, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    o.orderPayType == 'TRANSFER'
                        ? Icons.account_balance_outlined
                        : Icons.payments_outlined,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${o.orderPayType} • ${o.isPaid ? "LUNAS" : "BELUM LUNAS"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    TextFormatter.formatRupiah(o.orderTotal),
                    style: textTheme.titleSmall,
                  ),
                ],
              ),
              if (o.orderStatus == 'REJECT' &&
                  (o.orderRejectReason ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Alasan: ${o.orderRejectReason}',
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.errorDark)),
              ],
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: const Text('Detail'),
                  onPressed: onDetail,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
