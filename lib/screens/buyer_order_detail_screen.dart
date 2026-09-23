import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/order_model.dart';
import '../services/order_api.dart';
import '../utils/responsive.dart';
import '../utils/text_formatter.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/empty_state.dart';
import '../widgets/info_row.dart';
import '../widgets/private_route.dart';
import '../widgets/section_card.dart';

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

  // (latar, teks) per status pesanan -- warna sama dengan chip web
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
    return PrivateRoute(
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Detail Pesanan'),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _data == null
                ? const PageBody(
                    child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Pesanan tidak ditemukan',
                    description:
                        'Pesanan mungkin sudah dihapus atau koneksi bermasalah.',
                  ))
                : PageBody(maxWidth: 720, child: _content(_data!)),
      ),
    );
  }

  Widget _content(BuyerOrderWithDetail d) {
    final h = d.header;
    final textTheme = Theme.of(context).textTheme;
    final (bg, fg) = _statusColors(h.orderStatus);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // status besar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            children: [
              Icon(
                h.orderStatus == 'FINISH'
                    ? Icons.check_circle_rounded
                    : h.orderStatus == 'REJECT'
                        ? Icons.cancel_rounded
                        : Icons.hourglass_top_rounded,
                color: fg,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                orderStatusLabel(h.orderStatus),
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(color: fg),
              ),
              if (h.orderStatus == 'REJECT' &&
                  (h.orderRejectReason ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Alasan: ${h.orderRejectReason}',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: AppColors.errorDark)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Info pesanan',
          icon: Icons.info_outline_rounded,
          dense: true,
          child: Column(
            children: [
              InfoRow(label: 'Outlet', value: h.orderOutletName),
              InfoRow(label: 'Pembayaran', value: h.orderPayType),
              InfoRow(
                label: 'Status bayar',
                value: h.isPaid ? 'LUNAS' : 'BELUM LUNAS',
                color: h.isPaid ? AppColors.successDark : AppColors.warningDark,
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Barang dipesan',
          description: '${d.detail.length} jenis barang',
          icon: Icons.shopping_basket_outlined,
          dense: true,
          child: Column(
            children: [
              for (final item in d.detail)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.stockName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${item.qty} x ${TextFormatter.formatRupiah(item.price)}',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        TextFormatter.formatRupiah(item.total),
                        style: textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 20),
              InfoRow(
                label: 'Total',
                value: TextFormatter.formatRupiah(h.orderTotal),
                highlight: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
