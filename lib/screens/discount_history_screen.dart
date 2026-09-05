import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/app_bar_custom.dart';
import '../services/discount_api.dart';
import '../models/discount_model.dart';

class DiscountHistoryScreen extends StatefulWidget {
  final int discountId;
  const DiscountHistoryScreen({super.key, required this.discountId});

  @override
  State<DiscountHistoryScreen> createState() => _DiscountHistoryScreenState();
}

class _DiscountHistoryScreenState extends State<DiscountHistoryScreen> {
  final _discountApi = DiscountApi();
  List<DiscountHistoryResponse> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await _discountApi.getHistory(widget.discountId, 1, 50);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final pagination = DiscountHistoryPagination.fromJson(data);
        if (!mounted) return;
        setState(() => _history = pagination.data);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'INSERT':
        return Colors.green;
      case 'UPDATE':
        return Colors.blue;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(title: 'Riwayat Diskon'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('Belum ada riwayat'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final h = _history[index];
                    final valueLabel = h.historyDiscountType == 'PERCENT'
                        ? '${h.historyDiscountValue.toStringAsFixed(0)}%'
                        : 'Rp${NumberFormat('#,###', 'id_ID').format(h.historyDiscountValue)}';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Chip(
                          label: Text(h.historyAction,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)),
                          backgroundColor: _actionColor(h.historyAction),
                        ),
                        title: Text('${h.historyItemName} • $valueLabel'),
                        subtitle: Text(
                          '${h.historyActorName} (${h.historyActorRole})\n'
                          '${DateFormat('dd-MM-yyyy HH:mm:ss').format(h.historyChangedAt)}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}
