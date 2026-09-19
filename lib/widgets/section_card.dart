import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/responsive.dart';

/// Kartu bagian dengan judul + ikon + aksi opsional (web: SectionCard).
class SectionCard extends StatelessWidget {
  final String? title;
  final String? description;
  final IconData? icon;
  final Widget? action;
  final Widget child;
  final bool dense;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.description,
    this.icon,
    this.action,
    this.dense = false,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pad = padding ??
        EdgeInsets.all(dense ? 16 : (context.isCompact ? 16 : 24));
    final hasHeader = title != null || action != null;

    return Card(
      margin: margin ?? EdgeInsets.zero,
      child: Padding(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasHeader) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.blueLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(icon, size: 20, color: AppColors.blue),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (description != null && description!.isNotEmpty)
                          Text(
                            description!,
                            style: textTheme.bodySmall,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(width: 8),
                    action!,
                  ],
                ],
              ),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
