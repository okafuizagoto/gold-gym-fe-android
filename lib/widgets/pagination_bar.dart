import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/responsive.dart';

/// Footer tabel: "Menampilkan a-b dari N", pilihan jumlah per halaman, dan
/// tombol halaman (web: PaginationBar). Di HP disusun 2 baris supaya tidak
/// terpotong.
class PaginationBar extends StatelessWidget {
  final int page;
  final int totalPage;
  final int limit;
  final int totalData;
  final int shownCount;
  final List<int> limitOptions;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onLimitChanged;

  const PaginationBar({
    super.key,
    required this.page,
    required this.totalPage,
    required this.limit,
    required this.totalData,
    required this.shownCount,
    required this.onPageChanged,
    required this.onLimitChanged,
    this.limitOptions = const [5, 10, 20, 50],
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final start = totalData == 0 ? 0 : ((page - 1) * limit) + 1;
    final end = totalData == 0 ? 0 : start + shownCount - 1;
    final safeTotalPage = totalPage < 1 ? 1 : totalPage;

    final info = Text(
      'Menampilkan $start-$end dari $totalData',
      style: textTheme.bodySmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final limitPicker = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Per halaman', style: textTheme.bodySmall),
        const SizedBox(width: 8),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: limitOptions.contains(limit) ? limit : limitOptions.first,
              isDense: true,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
              items: limitOptions
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (v) {
                if (v != null) onLimitChanged(v);
              },
            ),
          ),
        ),
      ],
    );

    final pager = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Sebelumnya',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.chipBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            '$page / $safeTotalPage',
            style: textTheme.labelMedium,
          ),
        ),
        IconButton(
          tooltip: 'Berikutnya',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed:
              page < safeTotalPage ? () => onPageChanged(page + 1) : null,
        ),
      ],
    );

    if (context.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 8),
              limitPicker,
            ],
          ),
          const SizedBox(height: 6),
          Center(child: pager),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: info),
        const SizedBox(width: 12),
        limitPicker,
        const SizedBox(width: 12),
        pager,
      ],
    );
  }
}
