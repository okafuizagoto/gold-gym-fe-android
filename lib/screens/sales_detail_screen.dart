import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/empty_state.dart';
import '../widgets/info_row.dart';
import '../widgets/section_card.dart';
import '../services/sales_api.dart';
import '../models/sales_model.dart';
import '../utils/responsive.dart';
import '../utils/text_formatter.dart';

class SalesDetailScreen extends StatefulWidget {
  final String saleId;
  const SalesDetailScreen({super.key, required this.saleId});

  @override
  State<SalesDetailScreen> createState() => _SalesDetailScreenState();
}

class _SalesDetailScreenState extends State<SalesDetailScreen> {
  final _salesApi = SalesApi();
  SaleDetailResponse? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _salesApi.getSaleDetail(widget.saleId);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (!mounted) return;
        setState(() => _detail = SaleDetailResponse.fromJson(data));
      } else {
        setState(() => _error = 'Gagal memuat detail transaksi');
      }
    } catch (e) {
      setState(() => _error = 'Gagal memuat detail transaksi');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(title: 'Detail Transaksi'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ListView(
                  children: [
                    EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: _error!,
                      action: OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Coba lagi'),
                      ),
                    ),
                  ],
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final header = _detail!.header;
    final detail = _detail!.detail;
    final textTheme = Theme.of(context).textTheme;
    final paid = header.isPaid;
    final pad = context.pagePadding;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(pad),
        child: ContentWidth(
          maxWidth: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                icon: Icons.receipt_long_outlined,
                title: header.saleTrancnum,
                description: header.saleTransdate != null
                    ? '${DateFormat('dd-MM-yyyy').format(header.saleTransdate!)} '
                        '${TextFormatter.formatTimeHms(header.saleTranstime)}'
                    : null,
                action: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        paid ? AppColors.successLight : AppColors.warningLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    paid ? 'LUNAS' : 'BELUM LUNAS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          paid ? AppColors.successDark : AppColors.warningDark,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InfoRow(label: 'Kasir', value: header.saleSalesperson),
                    if (header.saleSalescustomer.isNotEmpty)
                      InfoRow(
                          label: 'Customer', value: header.saleSalescustomer),
                    if (header.hasMeja)
                      InfoRow(label: 'No Meja', value: header.saleMejaNames!),
                    InfoRow(label: 'Outlet', value: header.saleOutcode),
                    const Divider(height: 20),
                    if (header.hasTotalDiscount)
                      InfoRow(
                        label:
                            'Diskon Total (${header.saleTotalDiscountPercent!.toStringAsFixed(0)}%)',
                        value:
                            '-${TextFormatter.formatRupiah(header.saleTotalDiscountAmount!)}',
                        color: AppColors.warningDark,
                      ),
                    if (header.hasVoucher)
                      InfoRow(
                        label:
                            'Voucher ${header.saleVoucherCode ?? ''} (${header.saleVoucherPercent?.toStringAsFixed(0) ?? 0}%)',
                        value:
                            '-${TextFormatter.formatRupiah(header.saleVoucherAmount!)}',
                        color: AppColors.warningDark,
                      ),
                    InfoRow(
                      label: 'Total',
                      value: TextFormatter.formatRupiah(header.saleTranstotal),
                      bold: true,
                    ),
                    InfoRow(
                      label: 'Bayar',
                      value:
                          TextFormatter.formatRupiah(header.saleTranspayment),
                    ),
                    InfoRow(
                      label: 'Kembali',
                      value: TextFormatter.formatRupiah(header.saleTranschange),
                      highlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Detail Item (${detail.length})',
                  style: textTheme.titleMedium),
              const SizedBox(height: 8),
              ...detail.map((d) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.saleStockname,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall),
                          const SizedBox(height: 4),
                          InfoRow(
                            label:
                                '${d.saleQty} ${d.salePack} x ${TextFormatter.formatRupiah(d.saleSalesprice)}',
                            value: TextFormatter.formatRupiah(
                                d.saleTotalsalesprice),
                            bold: true,
                          ),
                          if (d.hasDiscount)
                            InfoRow(
                              label: d.saleDiscountType == 'PERCENT'
                                  ? 'Diskon (${d.saleDiscountValue!.toStringAsFixed(0)}%)'
                                  : 'Diskon',
                              value:
                                  '-${TextFormatter.formatRupiah(d.saleDiscountAmount ?? 0)}',
                              color: AppColors.warningDark,
                            ),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
