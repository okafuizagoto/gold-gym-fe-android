import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/order_model.dart';
import '../services/order_api.dart';
import '../utils/responsive.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
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

  Future<void> _confirmDialog(BuyerOrder o) async {
    final reasonController = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi Pesanan'),
        content: SingleChildScrollView(
          child: Column(
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
                  isDense: true,
                ),
              ),
            ],
          ),
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
            child:
                const Text('Tolak', style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successDark),
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
                backgroundColor: AppColors.successDark),
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
    final pad = context.pagePadding;
    final sidePad =
        math.max(pad, (context.screenWidth - context.contentMaxWidth) / 2);
    return PrivateRoute(
      child: Scaffold(
        appBar: AppBarCustom(
          title: 'Pesanan Masuk',
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
                ? const PageBody(
                    child: EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Belum ada pesanan masuk',
                    description:
                        'Pesanan dari pembeli untuk outlet ini akan tampil di sini.',
                  ))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(sidePad, pad, sidePad, pad),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _orderCard(_orders[index]),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _orderCard(BuyerOrder o) {
    final busy = _busyId == o.orderId;
    final textTheme = Theme.of(context).textTheme;
    final (bg, fg) = _statusColors(o.orderStatus);

    Widget? action;
    if (busy) {
      action = const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2));
    } else if (o.orderStatus == 'WAITING') {
      action = ElevatedButton.icon(
        icon: const Icon(Icons.fact_check_outlined, size: 18),
        label: const Text('Konfirmasi'),
        onPressed: () => _confirmDialog(o),
      );
    } else if (o.orderStatus == 'PROCESS') {
      action = ElevatedButton.icon(
        icon: const Icon(Icons.done_all_rounded, size: 18),
        label: const Text('Selesai Proses'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.successDark),
        onPressed: () => _finishDialog(o),
      );
    }

    return Card(
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
                    o.orderBuyerName.isEmpty
                        ? 'Pembeli'
                        : o.orderBuyerName.toUpperCase(),
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
                  child: Text(orderStatusLabel(o.orderStatus),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          color: fg,
                          fontWeight: FontWeight.w700)),
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
                    color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      '${o.orderPayType} • ${o.isPaid ? "LUNAS" : "BELUM LUNAS"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall),
                ),
                const SizedBox(width: 8),
                Text(TextFormatter.formatRupiah(o.orderTotal),
                    style: textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: const Text('Detail'),
                  onPressed: () => Navigator.pushNamed(
                      context, '/pesanan-detail',
                      arguments: o.orderId),
                ),
                const Spacer(),
                if (action != null) Flexible(child: action),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
