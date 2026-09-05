import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/app_bar_custom.dart';
import '../services/sales_api.dart';
import '../models/sales_model.dart';
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
              ? Center(child: Text(_error!))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final header = _detail!.header;
    final detail = _detail!.detail;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(header.saleTrancnum,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Chip(
                        label: Text(header.isPaid ? 'LUNAS' : 'BELUM LUNAS'),
                        backgroundColor:
                            header.isPaid ? Colors.green[100] : Colors.orange[100],
                      ),
                    ],
                  ),
                  const Divider(),
                  _row('Tanggal',
                      header.saleTransdate != null
                          ? DateFormat('dd-MM-yyyy').format(header.saleTransdate!)
                          : '-'),
                  _row('Jam', TextFormatter.formatTimeHms(header.saleTranstime)),
                  _row('Kasir', header.saleSalesperson),
                  if (header.saleSalescustomer.isNotEmpty)
                    _row('Customer', header.saleSalescustomer),
                  if (header.hasMeja) _row('No Meja', header.saleMejaNames!),
                  _row('Outlet', header.saleOutcode),
                  const Divider(),
                  if (header.hasTotalDiscount)
                    _row(
                      'Diskon Total (${header.saleTotalDiscountPercent!.toStringAsFixed(0)}%)',
                      '-${TextFormatter.formatRupiah(header.saleTotalDiscountAmount!)}',
                    ),
                  if (header.hasVoucher)
                    _row(
                      'Voucher ${header.saleVoucherCode ?? ''} (${header.saleVoucherPercent?.toStringAsFixed(0) ?? 0}%)',
                      '-${TextFormatter.formatRupiah(header.saleVoucherAmount!)}',
                    ),
                  _row('Total', TextFormatter.formatRupiah(header.saleTranstotal),
                      bold: true),
                  _row('Bayar', TextFormatter.formatRupiah(header.saleTranspayment)),
                  _row('Kembali', TextFormatter.formatRupiah(header.saleTranschange)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Detail Item (${detail.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...detail.map((d) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.saleStockname,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              '${d.saleQty} ${d.salePack} x ${TextFormatter.formatRupiah(d.saleSalesprice)}'),
                          Text(TextFormatter.formatRupiah(d.saleTotalsalesprice),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (d.hasDiscount) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              d.saleDiscountType == 'PERCENT'
                                  ? 'Diskon (${d.saleDiscountValue!.toStringAsFixed(0)}%)'
                                  : 'Diskon',
                              style: const TextStyle(
                                  color: Colors.orange, fontSize: 12),
                            ),
                            Text(
                              '-${TextFormatter.formatRupiah(d.saleDiscountAmount ?? 0)}',
                              style: const TextStyle(
                                  color: Colors.orange, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
