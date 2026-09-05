import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Baris "Label ...... Nilai" (web: InfoRow). Label & nilai sama-sama
/// fleksibel sehingga teks panjang membungkus, bukan meluap.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool highlight;
  final Color? color;
  final Widget? trailing;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.highlight = false,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: highlight ? AppColors.ink : AppColors.muted,
                fontWeight:
                    highlight || bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: textTheme.bodyMedium?.copyWith(
                color: color ??
                    (highlight ? AppColors.successDark : AppColors.ink),
                fontWeight:
                    bold || highlight ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
