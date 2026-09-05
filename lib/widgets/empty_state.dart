import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Tampilan "belum ada data" yang ramah (web: EmptyState).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;
  final bool compact;

  const EmptyState({
    super.key,
    required this.title,
    this.icon = Icons.inbox_rounded,
    this.description,
    this.action,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final circle = compact ? 48.0 : 72.0;
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 24 : 48,
        horizontal: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: circle,
            height: circle,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.chipBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: compact ? 24 : 34,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                description!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
