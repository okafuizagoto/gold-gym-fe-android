import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../utils/responsive.dart';
import '../widgets/app_bar_custom.dart';
import '../widgets/empty_state.dart';
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

  ({Color bg, Color fg}) _actionColors(String action) {
    switch (action) {
      case 'INSERT':
        return (bg: AppColors.successLight, fg: AppColors.successDark);
      case 'UPDATE':
        return (bg: AppColors.blueLight, fg: AppColors.blueDark);
      case 'DELETE':
        return (bg: AppColors.errorLight, fg: AppColors.errorDark);
      default:
        return (bg: AppColors.chipBg, fg: AppColors.muted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const AppBarCustom(title: 'Riwayat Diskon'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.history_rounded,
                    title: 'Belum ada riwayat',
                    description:
                        'Perubahan diskon (tambah/ubah/hapus) akan tercatat di sini.',
                  ),
                )
              : ListView.builder(
                  padding: context.pageInsets,
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final h = _history[index];
                    final valueLabel = h.historyDiscountType == 'PERCENT'
                        ? '${h.historyDiscountValue.toStringAsFixed(0)}%'
                        : 'Rp${NumberFormat('#,###', 'id_ID').format(h.historyDiscountValue)}';
                    final colors = _actionColors(h.historyAction);
                    return ContentWidth(
                      maxWidth: 900,
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.bg,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  h.historyAction,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: colors.fg,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${h.historyItemName} • $valueLabel',
                                      style: textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${h.historyActorName} (${h.historyActorRole})',
                                      style: textTheme.bodySmall,
                                    ),
                                    Text(
                                      DateFormat('dd-MM-yyyy HH:mm:ss')
                                          .format(h.historyChangedAt),
                                      style: textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
