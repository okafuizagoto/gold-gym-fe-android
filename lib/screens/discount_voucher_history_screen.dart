import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/app_bar_custom.dart';
import '../services/discount_api.dart';
import '../models/discount_model.dart';

class DiscountVoucherHistoryScreen extends StatefulWidget {
  final String outcode;
  const DiscountVoucherHistoryScreen({super.key, required this.outcode});

  @override
  State<DiscountVoucherHistoryScreen> createState() =>
      _DiscountVoucherHistoryScreenState();
}

class _DiscountVoucherHistoryScreenState
    extends State<DiscountVoucherHistoryScreen> {
  final _discountApi = DiscountApi();
  List<VoucherHistoryResponse> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await _discountApi.getVoucherHistory(widget.outcode, 1, 50);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final pagination = VoucherHistoryPagination.fromJson(data);
        if (!mounted) return;
        setState(() => _history = pagination.data);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'USED':
        return Colors.blue;
      case 'EXPIRED':
        return Colors.orange;
      case 'DELETED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(title: 'Riwayat Voucher'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('Belum ada riwayat voucher'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final h = _history[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Chip(
                          label: Text(h.historyStatus,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)),
                          backgroundColor: _statusColor(h.historyStatus),
                        ),
                        title: Text(
                            '${h.historyVoucherCode} • ${h.historyPercent.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, letterSpacing: 1)),
                        subtitle: Text(
                          '${h.historyActorName} (${h.historyActorRole})\n'
                          '${DateFormat('dd-MM-yyyy HH:mm:ss').format(h.historyChangedAt)}'
                          '${h.historySaleId != null ? '\nNota: ${h.historySaleId}' : ''}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}
