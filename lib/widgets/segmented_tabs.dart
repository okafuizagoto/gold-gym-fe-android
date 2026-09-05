import 'package:flutter/material.dart';
import '../config/theme.dart';

class SegmentedTab<T> {
  final T value;
  final String label;
  final IconData? icon;
  final int? badge;

  const SegmentedTab({
    required this.value,
    required this.label,
    this.icon,
    this.badge,
  });
}

/// Tab berbentuk pil (web: SegmentedTabs). Setiap tab berbagi lebar sama
/// rata; label menyusut otomatis di layar sempit supaya tidak terpotong.
class SegmentedTabs<T> extends StatelessWidget {
  final T value;
  final ValueChanged<T> onChanged;
  final List<SegmentedTab<T>> tabs;

  const SegmentedTabs({
    super.key,
    required this.value,
    required this.onChanged,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: _SegmentedTabItem(
                selected: tab.value == value,
                label: tab.label,
                icon: tab.icon,
                badge: tab.badge,
                onTap: () => onChanged(tab.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentedTabItem extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData? icon;
  final int? badge;
  final VoidCallback onTap;

  const _SegmentedTabItem({
    required this.selected,
    required this.label,
    required this.onTap,
    this.icon,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.muted;
    return Material(
      color: selected ? AppColors.blue : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                if (badge != null && badge! > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : AppColors.blue,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.blue : Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
