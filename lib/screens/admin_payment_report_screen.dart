import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../services/payment_api.dart';
import '../utils/responsive.dart';
import '../utils/text_formatter.dart';
import '../utils/toast.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/private_route.dart';
import '../widgets/search_field.dart';

/// Layar ADMIN: laporan transaksi payment QRIS lintas SEMUA outlet (nama
/// outlet & user sudah di-JOIN backend, lihat GetPaymentReport). Cari
/// order_id/nama outlet/nama-email user, filter status.
class AdminPaymentReportScreen extends StatefulWidget {
  const AdminPaymentReportScreen({super.key});

  @override
  State<AdminPaymentReportScreen> createState() =>
      _AdminPaymentReportScreenState();
}

class _AdminPaymentReportScreenState extends State<AdminPaymentReportScreen> {
  final _paymentApi = PaymentApi();
  final _searchController = TextEditingController();
  List<PaymentReportRow> _rows = [];
  bool _loading = true;
  Timer? _debounce;
  String _statusFilter = '';

  static const _statusOptions = [
    '',
    'PENDING',
    'SETTLEMENT',
    'EXPIRE',
    'CANCEL',
    'DENY',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await _paymentApi.getReport(
        search: _searchController.text.trim(),
        status: _statusFilter,
      );
      if (resp.statusCode == 200) {
        setState(() => _rows = PaymentReportRow.listFromResponse(resp));
      } else if (resp.statusCode == 403) {
        if (mounted) Toast.error(context, 'Khusus admin');
      } else {
        if (mounted) Toast.error(context, 'Gagal memuat laporan');
      }
    } catch (_) {
      if (mounted) Toast.error(context, 'Gagal memuat laporan');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'SETTLEMENT':
        return AppColors.successDark;
      case 'EXPIRE':
      case 'CANCEL':
      case 'DENY':
        return AppColors.error;
      default:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return PrivateRoute(
      child: Scaffold(
        appBar: const AppBarCustom(title: 'Laporan Pembayaran QRIS'),
        drawer: const AppDrawer(),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 12, pad, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SearchField(
                      controller: _searchController,
                      hintText:
                          'Cari order ID / nama outlet / nama-email user',
                      onChanged: (v) {
                        _debounce?.cancel();
                        _debounce = Timer(
                            const Duration(milliseconds: 450), () => _load());
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _statusOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final s = _statusOptions[i];
                          final selected = s == _statusFilter;
                          return ChoiceChip(
                            label: Text(s.isEmpty ? 'Semua' : s),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _statusFilter = s);
                              _load();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _rows.isEmpty
                        ? EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Tidak ada transaksi',
                            compact: context.isShort,
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: EdgeInsets.fromLTRB(pad, 4, pad, pad),
                              itemCount: _rows.length,
                              itemBuilder: (context, i) {
                                final r = _rows[i];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                r.outletName.isEmpty
                                                    ? r.orderId
                                                    : r.outletName,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _statusColor(r.status)
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                r.status,
                                                style: TextStyle(
                                                  color: _statusColor(
                                                      r.status),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          r.userName.isEmpty
                                              ? '-'
                                              : '${r.userName} (${r.userEmail})',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              TextFormatter.formatRupiah(
                                                  r.amount),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700),
                                            ),
                                            Text(
                                              DateFormat('dd MMM yyyy HH:mm')
                                                  .format(r.createdAt),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ),
                                        if (r.saleId != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Nota: ${r.saleId}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                    color:
                                                        AppColors.successDark),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
